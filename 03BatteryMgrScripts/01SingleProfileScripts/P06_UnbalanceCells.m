%% Series-Pack Fast Charging
% By Joseph Ojo
%
%% Change Current Directory

% clearvars;
%
% currFilePath = mfilename('fullpath');
% [mainPath, filename, ~] = fileparts(currFilePath);
% cd(mainPath)

% clearvars -except bal eventLog; clc

%%
warning('on','backtrace')

%% Initialize Variables and Devices
try
    if ~exist('battID', 'var') || isempty(battID)
        battID = ["AD0"]; % ID in Cell Part Number (e.g BAT11-FEP-AA1). Defined again in initializeVariables
    end
    
    if ~exist('caller', 'var')
        caller = "cmdWindow";
    end
    
    if ~exist('psuArgs', 'var')
        psuArgs = [];
        eloadArgs = [];
        tempModArgs = [];
        balArgs = [];
        sysMCUArgs = [];
        stackArgs = [];
    end
    
    if ~exist('testSettings', 'var') || isempty(testSettings)
        codeFilePath = mfilename('fullpath');
        % Seperates the path directory and the filename
        [path, fName, ~] = fileparts(codeFilePath);
        
        str = extractBetween(path,"",...
            "00BattManager","Boundaries","inclusive");
        testSettings.saveDir = str + "\01ProjectData\" + extractBefore(fName, 4) + "\";
        
        testSettings.cellConfig = "SerPar";
        testSettings.currMeasDev = "balancer";
        
        testSettings.saveName   = "00SP_HCFC_" + battID;
        testSettings.purpose    = "Test for the series stack health conscious charging algorithm";
        testSettings.tempChnls  = [9, 10, 11, 12, 13];
        testSettings.trigPins = []; % Find in every pin that should be triggered
        testSettings.trigInvert = []; % Fill in 1 for every pin that is reverse polarity (needs a zero to turn on)
        testSettings.trigStartTimes = {[100]}; % cell array of vectors. each vector corresponds to each the start times for each pin
        testSettings.trigDurations = {15}; % cell array of vectors. each vector corresponds to each the duration for each pin's trigger
    end
    
    script_initializeVariables; % Run Script to initialize common variables

    if ~exist('eventLog', 'var') || isempty(eventLog) || ~isvalid(eventLog)
        eventLog = EventLogger();
    end
    
    script_initializeDevices; % Run Script to initialize control devices
%     verbosity = 1; % Data measurements are fully displayed.
%     verbosity = 2; % Data measurements are not displayed since the results from the MPC will be.
    balBoard_num = 0; % ID for the main balancer board
    
%     wait(2); % Wait for the EEprom Data to be updated
catch ME
    script_handleException;
end   


%% Constants

NUMCELLS = numCells_Ser;

% % Write the number of cells to board to prevent OV/UV on unconnected channels
% bal.Cell_Present_Write(balBoard_num, NUMCELLS); 

sampleTime = 5; testSettings.sampleTime = sampleTime;% 0.5; % Sample time [s]
readPeriod = 0.5; testSettings.readPeriod = readPeriod;% How often to read from plant
prevTime = 0; prevElapsed = 0;

USE_PARALLEL = true;
% USE_PARALLEL = false;
testSettings.USE_PARALLEL = USE_PARALLEL;

try
    MIN_BAL_CURR = -2; %[-0.5, -0.5, -0.5, -0.5]';
    MAX_BAL_CURR = 2; % [0.5, 0.5, 0.5, 0.5]';

catch ME
    script_handleException;
end   

MAX_CELL_CURR = batteryParam.maxCurr(battID); % /numCells_Par; % This should be for each single/parallel cells connected in series
MIN_CELL_CURR = batteryParam.minCurr(battID); % /numCells_Par;
MAX_CHRG_VOLT = batteryParam.chargedVolt(battID)/numCells_Ser;
MIN_DCHRG_VOLT = batteryParam.dischargedVolt(battID)/numCells_Ser;
MAX_CELL_VOLT = batteryParam.maxVolt(battID)/numCells_Ser;
MIN_CELL_VOLT = batteryParam.minVolt(battID)/numCells_Ser;
MAX_BAL_SOC = 0.95; % Maximum SOC that that balancers will be active and the mpc will optimize for balance currents
MIN_BAL_SOC = 0.05; % Minimum SOC that that balancers will be active and the mpc will optimize for balance currents
ALLOWABLE_SOCDEV = 0.01; % The allowable SOC deviation 
MIN_PSUCURR_4_BAL = MIN_CELL_CURR + MAX_BAL_CURR; % The largest amount of current to use while balancing
RATED_CAP = batteryParam.ratedCapacity(battID);

% Set Balancer Voltage Thresholds
bal.Set_OVUV_Threshold(MAX_CELL_VOLT(1, 1), MIN_CELL_VOLT(1, 1));
wait(0.5);

% battery capacity
CAP = batteryParam.cellCap{battID};  % battery capacity

cellData.NUMCELLS = NUMCELLS;
cellData.MAX_BAL_CURR = MAX_BAL_CURR;
cellData.MAX_BAL_CURR = MAX_BAL_CURR;
cellData.MIN_BAL_CURR = MIN_BAL_CURR;
cellData.MAX_CELL_CURR = MAX_CELL_CURR;
cellData.MAX_CHRG_VOLT = MAX_CHRG_VOLT;
cellData.MIN_DCHRG_VOLT = MIN_DCHRG_VOLT;
cellData.MAX_BAL_SOC = MAX_BAL_SOC;
cellData.MIN_BAL_SOC = MIN_BAL_SOC;
cellData.CAP = CAP;
cellData.ALLOWABLE_SOCDEV = ALLOWABLE_SOCDEV;


xSOC    = 1;
xV1     = 2;
xV2     = 3;
xTc     = 4;
xTs     = 5;
xCurr   = 6;

yVolt   = 1;
yTs     = 2;
yANPOT    = 3;

xIND.SOC    = 1+(xSOC-1)*NUMCELLS:xSOC*NUMCELLS;
xIND.V1     = 1+(xV1-1)*NUMCELLS:xV1*NUMCELLS;
xIND.V2     = 1+(xV2-1)*NUMCELLS:xV2*NUMCELLS;
xIND.Tc     = 1+(xTc-1)*NUMCELLS:xTc*NUMCELLS;
xIND.Ts     = 1+(xTs-1)*NUMCELLS:xTs*NUMCELLS;
xIND.Curr   = 1+(xCurr-1)*NUMCELLS:xCurr*NUMCELLS; % Passing the curr back in to the state to prevent using current in output function

yIND.Volt   = 1+(yVolt-1)*NUMCELLS:yVolt*NUMCELLS;
yIND.Ts     = 1+(yTs-1)*NUMCELLS:yTs*NUMCELLS;
yIND.ANPOT    = 1+(yANPOT-1)*NUMCELLS:yANPOT*NUMCELLS;

indices.x = xIND;
indices.y = yIND;


TARGET_SOC = [0.55, 0.50, 0.52, 0.45]; %0.98;
testSettings.TARGET_SOC = TARGET_SOC;
ANPOT_Target = -0.1;  % Anode Potential has to be greater than 0 to guarantee no lithium deposition

% Balance Efficiencies
chrgEff = 0.774; 
dischrgEff = 0.651; 

numStatesPerCell = length(fields(xIND));
numOutputsPerCell = length(fields(yIND));


nx = numStatesPerCell*NUMCELLS; % Number of states
ny = numOutputsPerCell*NUMCELLS; % Number of outputs
nu = NUMCELLS + 1; % Number of inputs. In this case, current for each cell + PSU current

indices.nx = nx;
indices.ny = ny;
indices.nu = nu;


%% Predictive Model
try
    % ######## Voltage Model ########
    load(dataLocation + "008OCV_" + battID + ".mat", 'OCV', 'SOC'); 
    
%     C1 = 47.827;
%     C2 = 8.5956e+05;
%     R1 = 0.0022329;
%     R2 = 0.046958;
%     Rs = 0.05867;
    
%     C1 = 4997.5;
%     C2 = 1e+06;
%     R1 = 0.0047459;
%     R2 = 0.0098593;
%     Rs = 0.050833;
    
    % Estimated from Dschrg and Chrg Data (Cyc_2 AD0)
    C1 = 2472;
    C2 = 5778.8;
    R1 = 0.0010036;
    R2 = 0.005064;
    Rs = 0.049548;
    
    C1 = C1 * ones(1, NUMCELLS);
    C2 = C2 * ones(1, NUMCELLS);
    R1 = R1 * ones(1, NUMCELLS);
    R2 = R2 * ones(1, NUMCELLS);
    Rs = Rs * ones(1, NUMCELLS);
    
    A11 = -1./(R1 .* C1);
    A12 = zeros(1, length(A11));
    A1 = [A11; A12];
    A1 = A1(:)';
    A22 = -1./(R2 .* C2);
    A21 = zeros(1, length(A22));
    A2 = [A21; A22];
    A2 = A2(:)';
    AV_cont = [A1; A2];
    BV_cont = [1./C1 ; 1./C2];
    
    A_tempo = repmat(AV_cont, NUMCELLS, 1) .* eye(NUMCELLS * 2);
    A = expm(A_tempo * sampleTime);
    B = A_tempo\(A - eye(size(A))) * BV_cont(:);
    
    voltMdl.A_cont = AV_cont;
    voltMdl.B_cont = BV_cont;
    voltMdl.A = A;
    voltMdl.B = B;
    voltMdl.R1 = R1;
    voltMdl.R2 = R2;
    voltMdl.C1 = C1;
    voltMdl.C2 = C2;
    voltMdl.Rs = Rs(:);

    resampleSOC = 0:0.0005:1;
    voltMdl.OCV = interp1(SOC, OCV, resampleSOC, 'pchip', 'extrap'); % OCV;
    voltMdl.SOC = resampleSOC; % SOC;
    
    
    % ########  Temp Model ########
    cc = 59.903 * ones(1, NUMCELLS);
    cs = 0.24409 * ones(1, NUMCELLS);
    rc = 0.42963 * ones(1, NUMCELLS);
    re = 0.098836 * ones(1, NUMCELLS);
    ru = 16.419 * ones(1, NUMCELLS);
    
    % A,B,C,D Matrices  ***
    % Multi SS model
    % Creates a row of repeating A Matrices
    A11 = -1./(rc.*cc); % Top left of 2x2 matrix
    A12 = 1./(rc.*cc);  % Top right of 2x2 matrix
    A21 = 1./(rc.*cs); % Bottom left of 2x2 matrix
    A22 = ((-1./cs).*((1./rc) + (1./ru))); % Bottom right of 2x2 matrix
    A1 = [A11; A12]; A1 = A1(:)';
    A2 = [A21; A22]; A2 = A2(:)';
    A_cont = repmat([A1; A2], NUMCELLS, 1);
    
    % Creates a row of repeating B Matrices
    B11 = (re)./cc; % Top left of 2x2 matrix
    B12 = zeros(1, NUMCELLS);  % Top right of 2x2 matrix
    B21 = zeros(1, NUMCELLS); % Bottom left of 2x2 matrix
    B22 = 1./(ru.*cs); % Bottom right of 2x2 matrix
    B1 = [B11; B12]; B1 = B1(:)';
    B2 = [B21; B22]; B2 = B2(:)';
    B_cont = repmat([B1; B2], NUMCELLS, 1);
    
    % Creates a row of repeating C Matrices
    C11 = zeros(1, NUMCELLS); % Top left of 2x2 matrix
    C12 = zeros(1, NUMCELLS);  % Top right of 2x2 matrix
    C21 = zeros(1, NUMCELLS); % Bottom left of 2x2 matrix
    C22 = ones(1, NUMCELLS); % Bottom right of 2x2 matrix
    C1 = [C11; C12]; C1 = C1(:)';
    C2 = [C21; C22]; C2 = C2(:)';
    C = repmat([C1; C2], NUMCELLS, 1);
    
    D = zeros(size(C));
    
    % Single SS model
    %{
    A_cont = [-1/(rc*cc), 1/(rc*cc) ; 1/(rc*cs), ((-1/cs)*((1/rc) + (1/ru)))];
    B_cont = [(re)/cc 0; 0, 1/(ru*cs)];
    C = [0 0; 0 1]; %eye(2);
    D = [0, 0;0, 0];
    %}
    
    % Filter out the unnecesary nondiag matrices
    filter = eye(size(A_cont));
    filter = replaceDiag(filter, ones(NUMCELLS, 1), 1:2:size(A_cont, 1)-1, -1); % replace bottom diag with 1's
    filter = replaceDiag(filter, ones(NUMCELLS, 1), 1:2:size(A_cont, 1)-1, 1); % replace top diag with 1's
    
    tempMdl = struct;
    tempMdl.A_cont = A_cont .* filter;
    tempMdl.B_cont = B_cont .* filter;
    tempMdl.C = C;
    tempMdl.D = D;
    
    sys_temp = ss(tempMdl.A_cont,tempMdl.B_cont,C,D);
    sds_temp = c2d(sys_temp,sampleTime);
    
    tempMdl.A = sds_temp.A;
    tempMdl.B = sds_temp.B;
    
    % Manual Discretization of SS model
    %{
    A_Dis = expm(tempMdl.A_cont * sampleTime);
    tempMdl.A = A_Dis;
    tempMdl.B = tempMdl.A\(A_Dis - eye(size(A_Dis,1))) * tempMdl.B_cont;
    %}
    
    
    % ######## SOC Deviation Matrix ########
    % 3 SOC Differences
%     L2 = [zeros(NUMCELLS-1, 1), (-1 * eye(NUMCELLS-1))];
%     L1 = eye(NUMCELLS);
%     L1(end, :) = [];
%     devMat = L1 + L2;
    
    % 4 SOC Differences
    L2 = [zeros(NUMCELLS, 1), (-1 * eye(NUMCELLS))];
    L2(:, 1) = L2(:, end); L2(:, end) = [];
    L1 = eye(NUMCELLS);
    devMat = L1 + L2;
    
    A_soc = eye(NUMCELLS);
    
    % Main SOC Model
    B1 = -1 ./(CAP(:) * 3600);
    
    % Active Balancing Transformation Matrix
    Qx = diag(CAP(:) * 3600); % Maximum Capacities
    T = repmat(1/NUMCELLS, NUMCELLS) - eye(NUMCELLS); % Component for individual Active Balance Cell SOC [2]
    B2 = (Qx\T);
    
    socMdl.devMat = devMat;
    socMdl.A = A_soc;
    socMdl.B1 = B1;
    socMdl.B2 = B2;
    
    % Transformation matrix to emulate the actual current going through each
    % battery during balancing (charge and discharge). 
    T_chrg = eye(NUMCELLS) - (repmat(1/NUMCELLS, NUMCELLS) / chrgEff); % Current Transformation to convert primary cell currents to net cell currents to each cell during charging
    T_dchrg =  eye(NUMCELLS) - (repmat(1/NUMCELLS, NUMCELLS) * dischrgEff); % Current Transformation to convert primary cell currents to net cell currents to each cell during discharging
    currMdl.T_chrg = T_chrg;
    currMdl.T_dchrg = T_dchrg;
    currMdl.balWeight = 1; % Whether or not to use the balancing currents during optimization
    
    % Anode Potential (indirectly Lithium Plating) Lookup table (From "01_INR18650F1L_AnodeMapData.mat")
    load(dataLocation + '01_INR18650F1L_AnodeMapData.mat'); % Lithium plating rate
    anPotMdl.Curr = cRate_mesh * RATED_CAP;
    anPotMdl.SOC = soc_mesh;
    anPotMdl.ANPOT = mesh_anodeGap;
    
    predMdl.Volt = voltMdl;
    predMdl.Temp = tempMdl;
    predMdl.SOC = socMdl;
    predMdl.Curr = currMdl;
    predMdl.ANPOT = anPotMdl;
    % predMdl.lookupTbl = battMdl.Lookup_tbl; % Using the lookup table from plant model
catch ME
    script_handleException;
end

%% Initialize Plant variables and States 
% #############  Initial States  ##############
try
    verbosity = 1;
    script_queryData; % Get initial states from device measurements.
    verbosity = 0;
catch ME
    script_handleException;
end

Tf = thermoData(1); % Ambient Temp
tempMdl.Tf = Tf; % Ambient Temp
predMdl.Temp = tempMdl;


battData = struct;
battData.time           = 0;
battData.Ts             = thermoData(2:end);    % Surface Temp
battData.Tc             = thermoData(2:end);    % Initialize core temperature to surf Temp
battData.Tf             = Tf;                   % Ambient Temp
battData.volt           = testData.cellVolt(end, :);
battData.curr           = testData.cellCurr(end, :); % zeros(1, NUMCELLS);


% Using OCV vs SOC to initialize the cell SOCs based on their resting voltages
[~, minIndSOC] = min(  abs( OCV - testData.cellVolt(end, :) )  );
%Using SOC gotten from OCV data (assuming battery pack has had a long rest
initialSOCs = SOC(minIndSOC, 1); 
testData.cellSOC(end, :) = initialSOCs;

% Using SOC stored from previous test
% initialSOCs = testData.cellSOC(end, :)';


battData.SOC            = initialSOCs(1:NUMCELLS, 1)';
battData.Cap            = CAP;
battData.AnodePot       = qinterp2(-predMdl.ANPOT.Curr, predMdl.ANPOT.SOC, predMdl.ANPOT.ANPOT,...
                            zeros(NUMCELLS, 1), initialSOCs)';

ANPOT = qinterp2(-predMdl.ANPOT.Curr, predMdl.ANPOT.SOC, predMdl.ANPOT.ANPOT,...
            zeros(NUMCELLS, 1), initialSOCs)';
testData.AnodePot = ANPOT; % Initialize AnodePot Structure field
testData.Ts             = thermoData(2:end);    % Initialize surface temperature to surf Temp
testData.Tc             = testData.Ts;    % Initialize core temperature to surf Temp


ind = 1;
xk = zeros(nx, 1);

xk(ind:ind+NUMCELLS-1, :)   =  testData.cellSOC(end, :)'; ind = ind + NUMCELLS;
xk(ind:ind+NUMCELLS-1, :)   =  zeros(1, NUMCELLS)'   ; ind = ind + NUMCELLS; % V1 - Voltage accross RC1
xk(ind:ind+NUMCELLS-1, :)   =  zeros(1, NUMCELLS)'   ; ind = ind + NUMCELLS; % V2 - Voltage accross RC2
xk(ind:ind+NUMCELLS-1, :)   =  testData.Tc'          ; ind = ind + NUMCELLS;
xk(ind:ind+NUMCELLS-1, :)   =  testData.Ts'          ; ind = ind + NUMCELLS;

testData.Cost = 0;
testData.ExitFlag = 0;
testData.Iters = 0;
testData.balCurr = zeros(1, NUMCELLS);
testData.optPSUCurr = zeros(1, NUMCELLS);
testData.predStates = xk(:)';
testData.predOutput = [testData.cellSOC(end, :), testData.Ts, testData.AnodePot];
testData.sTime = 0;
testData.SOC_Targets = testData.cellSOC(end, :);


%% MPC - Configure Parameters
try
    mpcObj = nlmpc(nx,ny,nu);
    
    p1 = sampleTime;        % Algorithm sample time
    p2 = predMdl;           % Predictive Battery Model Structure
    p3 = cellData;          % Constant Cell Data
    p4 = indices;           % Indices for the STATES (x)and OUTPUTS (y) presented as a struts
    
    mpcObj.Model.NumberOfParameters = 4; % dt and capacity
    
    PH = 5;  % Prediction horizon
    CH = 2;  % Control horizon
    mpcObj.Ts = sampleTime;
    mpcObj.PredictionHorizon = PH;
    mpcObj.ControlHorizon = CH;
    
    % Constraints
    % Add Manipulated variable constraints
    % Small Rates affect speed a lot
    for i = 1:NUMCELLS % 
        mpcObj.MV(i).Max =  MAX_BAL_CURR;     mpcObj.MV(i).RateMax =  1.0; % MAX_CELL_CURR;
        mpcObj.MV(i).Min =  MIN_BAL_CURR;     mpcObj.MV(i).RateMin = -1.0; % -2; % -6
    end % 
    
    mpcObj.MV(NUMCELLS + 1).Max = MAX_CELL_CURR + MIN_BAL_CURR;
    mpcObj.MV(NUMCELLS + 1).Min = MIN_CELL_CURR + MAX_BAL_CURR; % MIN_PSUCURR_4_BAL; % 
    mpcObj.MV(NUMCELLS + 1).RateMax =  2; % MAX_CELL_CURR;
    mpcObj.MV(NUMCELLS + 1).RateMin = -2; % -6
    
    % Equality Limits for state/output vars for each cell
    for i=1:NUMCELLS
        % SOC
        mpcObj.States(i + (xSOC-1) * NUMCELLS).Max =  0.99;
        mpcObj.States(i + (xSOC-1) * NUMCELLS).Min =  0;
        
        % Ts
        mpcObj.States(i + (xTs-1) * NUMCELLS).Max =  44;
        mpcObj.States(i + (xTs-1) * NUMCELLS).Min =  0;
        mpcObj.States(i + (xTs-1) * NUMCELLS).ScaleFactor =  44;
        
        % Optimal Cell Curr
        mpcObj.States(i + (xCurr-1) * NUMCELLS).Max =  RATED_CAP; % 1C
        mpcObj.States(i + (xCurr-1) * NUMCELLS).Min =  -7.0;
        mpcObj.States(i + (xCurr-1) * NUMCELLS).ScaleFactor = RATED_CAP - (-7);

        
        % ANPOT
%         mpcObj.OV(i + (yANPOT-1) * NUMCELLS).Max =  inf;
        mpcObj.OV(i + (yANPOT-1) * NUMCELLS).Min =  ANPOT_Target;
        mpcObj.OV(i + (yANPOT-1) * NUMCELLS).ScaleFactor =  1;
        mpcObj.OV(i + (yANPOT-1) * NUMCELLS).MinECR =  0;
        mpcObj.OV(i + (yANPOT-1) * NUMCELLS).MaxECR =  0;
    
    end
    
    
    % Add dynamic model for nonlinear MPC
    mpcObj.Model.StateFcn = @(x, u, p1, p2, p3, p4)...
        P06_BattStateFcn_HW(x, u, p1, p2, p3, p4);
    mpcObj.Jacobian.StateFcn = @(x,u,p1, p2, p3, p4) ...
        myStateJacobian(x, u, p1, p2, p3, p4);
    
    mpcObj.Model.OutputFcn = @(x,u, p1, p2, p3, p4) ...
        P06_OutputFcn_HW(x, u, p1, p2, p3, p4); % SOC, Volt, Ts
    mpcObj.Jacobian.OutputFcn = @(x,u,p1, p2, p3, p4) ... 
        myOutputJacobian(x, u, p1, p2, p3, p4);
    
    mpcObj.Optimization.CustomCostFcn = @(X,U,e,data, p1, p2, p3, p4)...
        myCostFunction(X, U, e, data, p1, p2, p3, p4);
%     mpcObj.Jacobian.CustomCostFcn = @(x,u,e,data, p1, p2, p3, p4) ...
%         myCostJacobian(x, u,e,data, p1, p2, p3, p4);
    
    mpcObj.Optimization.CustomIneqConFcn = @(X,U,e,data, p1, p2, p3, p4)...
        myIneqConFunction(X,U,e,data, p1, p2, p3, p4);
    mpcObj.Jacobian.CustomIneqConFcn = @(x,u,e,data, p1, p2, p3, p4) ...
        myIneqConJacobian(x, u,e,data, p1, p2, p3, p4);
    
    mpcObj.Optimization.ReplaceStandardCost = true;
    
    mpcObj.Model.IsContinuousTime = false;
    
    mpcObj.Optimization.SolverOptions.UseParallel = true;
    
    mpcObj.Optimization.UseSuboptimalSolution = true;
    
    mpcObj.Optimization.SolverOptions.MaxIterations = 150; % 20; %
    
    mpcinfo = [];
    
    % SOC tracking, ANPOT tracking, and temp rise rate cuz refs have to equal number of outputs
    references = [TARGET_SOC(:)', repmat(ANPOT_Target, 1, NUMCELLS),... % ]; %
         repmat(3, 1, NUMCELLS)];
    
    u0 = [zeros(1, NUMCELLS), 0];

    validateFcns(mpcObj, xk, u0, [], {p1, p2, p3, p4}, references);
catch ME
    script_handleException;
end

%% Parallel Pool
if USE_PARALLEL == true
    pool = gcp('nocreate');
    % Start Parallel Pool if it doesn't exist
    if isempty(pool)
        pool = parpool(1);
    end
end

%% Extended Kalman Filter Configuration
ekf = extendedKalmanFilter(@P06_BattStateFcn_HW, @P06_OutputFcn_HW, xk);
%{
% Get observation noise covariance matrix
dt = readPeriod;
iters = 500;
plantObvs = cell(iters, 1);
u = [0 0 0 0 0]';  u_bal = u(1:NUMCELLS); u_psu = u(end);
t = tic;
for i=1:iters
    script_queryData;
    script_failSafes; %Run FailSafe Checks
    script_checkGUICmd; % Check to see if there are any commands from GUI
    % if limits are reached, break loop
    if errorCode == 1 || strcmpi(testStatus, "stop")
        script_idle;
    end
    
    y_Ts = thermoData(2:end);
    plantObvs{i} = [ testData.cellVolt(end, :) ;  y_Ts(:)' ];
    wait(0.25);
end
toc(t)

plantObvs_V_Ts = cell2mat(cellfun(@(X)[X(1, :), X(2, :)], plantObvs, 'UniformOutput', false));
obsvCov = cov(plantObvs_V_Ts - mean(plantObvs_V_Ts, 1));
zCov = diag(obsvCov);
%}

zCov = [4.24849699398227e-09;3.08216432866192e-09;4.52248496993420e-09;1.86977955912091e-09;...
    0.000118797595190384; 0.00142701402805615; 0; 0.00124933867735475; ...
    0.0001; 0.0001; 0.0001; 0.0001 ]; % 1e-10; 1e-10; 1e-10; 1e-10];
% zCov = repmat([0.08, 0.01], NUMCELLS, 1); % Measurement Noise covariance (assuming no cross correlation) % [0.02, 0.08, 0.01] 
ekf.MeasurementNoise = diag(zCov(:));
pCov = repmat([0.002, 0.005, 0.007, 0.05, 0.05, 0], NUMCELLS, 1);
ekf.ProcessNoise = diag(pCov(:));
% ekf.ProcessNoise = 0.07;

%% MPC Simulation Loop

u = zeros(NUMCELLS + 1,1);
combCurr = zeros(NUMCELLS, 1);

options = nlmpcmoveopt;
options.Parameters = {p1, p2, p3, p4};

mpcTimer = tic;
mpcRunning = false;
poolState = 'finished';

% ONLY_CHRG_FLAG = true;
ONLY_CHRG_FLAG = false;

printNow = false; % Variable to decide when to print test data


try     

    % Setup
    y_Ts = thermoData(2:end);
    y = [ testData.cellVolt(end, :),  y_Ts(:)', ANPOT(:)'];
    
    if ONLY_CHRG_FLAG == false
        if (max(testData.cellSOC(end, :) > MAX_BAL_SOC) ... % If at least one cell is  > MAX_BAL_SOC || < MIN_BAL_SOC
                || max(testData.cellSOC(end, :) < MIN_BAL_SOC)...
                || abs( max(xk(xIND.SOC)) - min(xk(xIND.SOC)) ) < ALLOWABLE_SOCDEV)
            BalanceCellsFlag = false; % Out of range Balancing SOC flag - Flag to set when SOC is greater/less than range for balancing
            predMdl.Curr.balWeight = 0;
            p2 = predMdl;
            options.Parameters = {p1, p2, p3, p4};
        elseif max(testData.cellSOC(end, :) < MAX_BAL_SOC) ... % If all cells are > MIN_BAL_SOC && < MAX_BAL_SOC
                && min(testData.cellSOC(end, :) > MIN_BAL_SOC)
            BalanceCellsFlag = true; % Out of range Balancing SOC flag - Flag to set when SOC is greater/less than range for balancing
            predMdl.Curr.balWeight = 1;
        end
    else
        BalanceCellsFlag = false; % Flag to set when SOC is greater than limit for balancing
        predMdl.Curr.balWeight = 0;
        p2 = predMdl;
        options.Parameters = {p1, p2, p3, p4};
    end
    sTime = [];readTime = [];
    tElapsed_plant = 0; prevStateTime = 0; prevMPCTime = 0;
    
%% loop
    while (max(abs(TARGET_SOC - testData.cellSOC(end, :)) > 0.0005) == 1) && ~strcmpi(testStatus, "stop")     
        if ( toc(testTimer)- prevMPCTime ) >= sampleTime && strcmpi(poolState, "finished")
            tElapsed_MPC = toc(testTimer);
            actual_STime = tElapsed_MPC - prevMPCTime;
            prevMPCTime = tElapsed_MPC;

            idealTimeLeft = abs(((TARGET_SOC(:) - xk(xIND.SOC, 1)) .* CAP(:) * 3600)./ abs(MAX_CELL_CURR));
            socChgAmt = (sampleTime./(idealTimeLeft+sampleTime)).*(TARGET_SOC(:) - xk(xIND.SOC, 1));
            SOC_Target = xk(xIND.SOC) + socChgAmt;
            references = [SOC_Target(:)', repmat(ANPOT_Target, 1, NUMCELLS),TARGET_SOC(:)']; 

            % Using the equivalent current from balance commands and psu.
            % measured current here instead does not work while predicting
            % model states (EKF). 
            ANPOTind = reshape(combCurr(:)', [], 1) < 0;
            interpCurr = reshape(combCurr(:)', [], 1) .* (ANPOTind);
            ANPOT = qinterp2(-predMdl.ANPOT.Curr, predMdl.ANPOT.SOC, predMdl.ANPOT.ANPOT,...
               interpCurr , reshape(testData.cellSOC(end, :), [], 1) );
                
            % Update Observation (Volt, Ts)
            y_Ts = thermoData(2:end);
            % If at least 1 sample time worth of data has been recorded,
            % start to average out the voltage measured during that period
            % to emulate what a constant balancing current would have done
            if length(testData.time) > round(sampleTime / readPeriod)
                y_Volt = mean(...
                    testData.cellVolt(end-round(sampleTime/readPeriod):end, :)...
                    , 1); 
            else % if one sample Time worth of data is not available, just use last recorded voltage
                y_Volt = testData.cellVolt(end, :);
            end
            
            y = [ y_Volt(:)',  y_Ts(:)', ANPOT(:)'];
            
            % Kalman filter plant measurements to get the hidden model states
            % Predict Step
            [PredictedState,PredictedStateCovariance] = predict(ekf, u, options.Parameters{:});

            % Correct Step
            [CorrectedState,CorrectedStateCovariance] = correct(ekf, y(:), u, options.Parameters{:});

            xk = CorrectedState';
            xk = xk(:);
            
            % Disable Balancing if SOC is past range 
            % or if SOC deviation if less than threshold. 
            % MPC won't optimize for Balance currents past this range
            if ONLY_CHRG_FLAG == false
                if (max(testData.cellSOC(end, :) > MAX_BAL_SOC) ...
                        || min(testData.cellSOC(end, :) < MIN_BAL_SOC)) ...
                        || abs( max(xk(xIND.SOC)) - min(xk(xIND.SOC)) ) < ALLOWABLE_SOCDEV
                    
                    BalanceCellsFlag = false;
                    predMdl.Curr.balWeight = 0;
                    p2 = predMdl;
                    options.Parameters = {p1, p2, p3, p4};
                    u = [zeros(NUMCELLS, 1); u(end)];
                    mpcObj.MV(NUMCELLS + 1).Min = min(MIN_CELL_CURR);
                    
                elseif max(testData.cellSOC(end, :) < MAX_BAL_SOC) ...
                        && min(testData.cellSOC(end, :) > MIN_BAL_SOC) ...
                        && (max(abs(predMdl.SOC.devMat * xk(xIND.SOC))) >= ALLOWABLE_SOCDEV)
                    
                    BalanceCellsFlag = true;
                    predMdl.Curr.balWeight = 1;
                    p2 = predMdl;
                    options.Parameters = {p1, p2, p3, p4};
                    mpcObj.MV(NUMCELLS + 1).Min = MIN_PSUCURR_4_BAL + max(testData.cellSOC(end, :));
                end
                
                if BalanceCellsFlag == true
                    mpcObj.MV(NUMCELLS + 1).Min = MIN_PSUCURR_4_BAL + max(testData.cellSOC(end, :));
                end
            end
            
            % Run the MPC controller
            if USE_PARALLEL == true
                mpcFeval = parfeval(pool,@nlmpcmove, 3, mpcObj,  xk, u,...
                    references,[], options);
            else
                [u,~,mpcinfo] = nlmpcmove(mpcObj, xk, u,...
                    references,[], options); % (:,idx-1)
            end

            mpcRunning = true;
        end
        
        if exist('mpcFeval', 'var') || USE_PARALLEL == false
            if USE_PARALLEL == true, poolState = mpcFeval.State; end
            if strcmpi(poolState, "finished") && mpcRunning == true
                if USE_PARALLEL == true
                    [u,~,mpcinfo] = fetchOutputs(mpcFeval,'UniformOutput',false);
                    u = u{:};
                    mpcinfo = mpcinfo{:};
                end
                mpcRunning = false;
                
                mdl_X = P06_BattStateFcn_HW(xk, u, p1, p2, p3, p4);
                mdl_Y = P06_OutputFcn_HW(mdl_X, u, p1, p2, p3, p4)';

                optCurr = u; % u<0 == Charging, u>0 == discharging
                cost = mpcinfo.Cost;
                iters = mpcinfo.Iterations;

                % Balancer and PSU Current
                balCurr = optCurr(1:NUMCELLS);
                optPSUCurr = optCurr(end);
                
                % Set power supply current
                curr = abs(optPSUCurr); % PSU Current. Using "curr" since script in nect line uses "curr"
                
                if optPSUCurr < -0.01
                    script_charge;
                elseif optPSUCurr > 0.01
                    script_discharge;
                else
                    script_idle;
                end
                               
                % Disable Balancing if SOC is past range. MPC won't optimize
                % for Balance currents past this range
                if BalanceCellsFlag == true
%                     bal.Currents(balBoard_num +1, logical(bal.cellPresent(1, :))) = balCurr;
                    
                    % send balance charges to balancer
                    bal.SetBalanceCharges(balBoard_num, balCurr*sampleTime); % Send charges in As
                else
                    bal.Currents(balBoard_num +1, logical(bal.cellPresent(1, :))) = zeros(size(balCurr));
                end
                
                tElapsed_plant = toc(testTimer);
                
                % Combine the PSU and BalCurr based on the balancer transformation
                % matrix
                combCurr = combineCurrents(optPSUCurr, balCurr, predMdl);
                
                wait(0.05);
                
                prevElapsed = tElapsed_plant;
                
            end
        end

               
        % Record Data from devices
        if (( toc(testTimer)- prevStateTime ) >= readPeriod ) && ~isempty(mpcinfo)
            prevStateTime = toc(testTimer); 

            if verbosity == 1
                printNow = true;
            elseif verbosity == 0
                if dotCounter < 59 % dotCounter is from [script_queryData]
                    printNow = false;
                else
                    printNow = true;
                end
            else
                printNow = false;
            end
            
            % Collect Measurements
            script_queryData;
            
            ANPOTind = testData.cellCurr(end, :)' < 0;
                interpCurr = testData.cellCurr(end, :)' .* (ANPOTind);
                ANPOT = qinterp2(-predMdl.ANPOT.Curr, predMdl.ANPOT.SOC, predMdl.ANPOT.ANPOT,...
                   interpCurr , testData.cellSOC(end, :)' );

           testData.AnodePot(end+1, :)      = ANPOT(:)';
           testData.SOC_Targets(end+1, :)   = SOC_Target';
           testData.predOutput(end+1, :)    = mdl_Y;
           testData.predStates(end+1, :)    = xk(:)';
           testData.balCurr(end+1, :)       = balCurr';
           testData.optPSUCurr(end+1, :)    = optPSUCurr;
           testData.Cost(end+1, :)          = cost;
           testData.Iters(end+1, :)         = iters;
           testData.ExitFlag(end+1, :)      = mpcinfo.ExitFlag;
           sTime = [sTime; actual_STime];
           testData.sTime(end+1, :) = actual_STime;
           
           if printNow == true
               MPCStr = ""; ANPOTStr = ""; balStr = "";
               MPCStr = MPCStr + sprintf("ExitFlag = %d\tCost = %e\t\tIters = %d\n", mpcinfo.ExitFlag, cost, iters);
               
               for i = 1:NUMCELLS-1
                   ANPOTStr = ANPOTStr + sprintf("ANPOT %d = %.3f A/m^2\t", i, testData.AnodePot(end,i));
                   balStr = balStr + sprintf("Bal %d = %.4f A\t", i, testData.balCurr(end,i));
               end
               
               for i = i+1:NUMCELLS
                   ANPOTStr = ANPOTStr + sprintf("ANPOT %d = %.3f A/m^2\n", i, testData.AnodePot(end,i));
                   balStr = balStr + sprintf("Bal %d = %.4f A\n", i, testData.balCurr(end,i));
               end
               
               fprintf(ANPOTStr + newline);
               fprintf(balStr + newline);
               fprintf(MPCStr + newline);
               
               timingStr = sprintf("Prev Opt Time: %.3f Secs", testData.sTime(end, 1));
               fprintf(timingStr + newline);
               
               fprintf("Predicted Voltage =\t"); disp(testData.predOutput(end, yIND.Volt))
               fprintf("Predicted SOC =\t"); disp(testData.predStates(end, xIND.SOC))
           end
           
            script_failSafes; %Run FailSafe Checks
            script_checkGUICmd; % Check to see if there are any commands from GUI
            % if limits are reached, break loop
            if strcmpi(testStatus, "stop")
                script_idle;
            end
        end
        
        
        % curr > 0 = Discharging
        if (max(combCurr > 0 & xk(1+NUMCELLS*(xIND.SOC-1):NUMCELLS*xIND.SOC, :) <= 0.01))...
                || (max(combCurr < 0 & xk(1+NUMCELLS*(xIND.SOC-1):NUMCELLS*xIND.SOC, :) >= 0.99))
            disp("Test Overcharged after: " + tElapsed_plant + " seconds.")
            script_resetDevices;
            break;
        elseif errorCode == 1
            disp("An error or Stop test request has occured." + newline...
                + "Test Stopped After: " + tElapsed_plant + " seconds.")
            script_resetDevices;
            break;
        end
                
    end
    
    script_resetDevices;
    disp("Test Completed After: " + tElapsed_plant + " seconds.")
    
    % Save Battery Parameters
    save(dataLocation + "007BatteryParam.mat", 'batteryParam');
        
    if ~strcmpi(testStatus, "stop")
        % Save Test Data
        testSettings.saveDir = testSettings.saveDir + metadata.startDate...
            +"_"+ metadata.startTime + "_"+extractAfter(fName, "_")+"_Successful\";
    elseif strcmpi(testStatus, "stop")
        % Save Test Data
        testSettings.saveDir = testSettings.saveDir + metadata.startDate...
            +"_"+ metadata.startTime + "_"+extractAfter(fName, "_")+"_ErroredOut_" ...
            + strjoin(string(errorCode(errorCode ~= ErrorCode.NO_ERROR)), "_")...
            +"\";
        testData.errCode = errorCode;
    else 
        % Save Test Data
        testSettings.saveDir = testSettings.saveDir + metadata.startDate...
            +"_"+ metadata.startTime + "_"+extractAfter(fName, "_")+"_Failed\";
        testData.errCode = errorCode;
    end
    % Save Data
    [saveStatus, saveMsg] = saveBattData(testData, metadata, testSettings);
    eventLog.saveLogs(char(extractBefore(...
        testSettings.saveDir,...
        strlength(testSettings.saveDir)...
                                            )));
    if saveStatus == false
        warning(saveMsg);
    else
        [status,msg,msgID] = copyfile(codeFilePath + ".m", testSettings.saveDir);
    end
    
catch ME
%     dataQueryTimerStopped();
    script_handleException;
end

%% Supporting Functions
% Custom Cost Function
function J = myCostFunction(X, U, e, data, p1, p2, p3, p4)
% Parameters (p#)
% dt          = p1;   % Algorithm sample time
predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x)and OUTPUTS (y) presented as a struts

NUMCELLS = cellData.NUMCELLS;
% cap = cellData.CAP; % Capacity of all cells

xIND = indices.x;

devMat = predMdl.SOC.devMat;

p = data.PredictionHorizon;
%     for i=1:p+1
%         Y(i,:) = P06_OutputFcn_HW(X(i,:)',U(i,:)',p1, p2)';
%     end

% %%%%%%%%%%% Cell Current Calculation %%%%%%%%%%%
%{
balCurr = U(2:p+1,1:NUMCELLS);
psuCurr =  U(2:p+1, end);

% curr = psuCurr + balCurr;

% % Compute Actual Current Through cells
logicalInd = balCurr' >= 0;
balActual_dchrg = predMdl.Curr.T_dchrg * (balCurr' .* (logicalInd));
balActual_chrg = predMdl.Curr.T_chrg * (balCurr' .* (~logicalInd));
balActual = balActual_chrg + balActual_dchrg;
curr = psuCurr + (predMdl.Curr.balWeight*balActual'); % Actual Current in each cell
%}

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% References for each objective
% ---------------------------------------------------------------------
ref = data.References;


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get the Objective vectors in pred horizon (2:p+1)
% ( SOC, SOCdev, Chg Time, Temp. Rate, Anode Potential)
% --------------------------------------------------------------------------------

% %%%%%%%%%%%%%%%%%%%%%%%%%%%  Charge SOC  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
chrgSOC = X(2:p+1, xIND.SOC);
socTracking = ref(:, 1:NUMCELLS) - chrgSOC;


% %%%%%%%%%%%%%%%%%%%%%%%%%%%  SOC Deviation  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
socDev = mean(chrgSOC, 2) - ref(:, 9:12); % mean(chrgSOC, 2) - chrgSOC;

% %%%%%%%%%%%%%%%%%%  Charge time calculation  %%%%%%%%%%%%%%%%%%%%%%%%
%{
    % Chg Time = (Change in SOC between each timestep x capacity) / current
    futureSOCs = chrgSOC; % SOCs only in the pred horizon
    currentSOCs = X(1:p, xIND.SOC); % SOCs in the current time and pred horizon minus furthest SOC
%     chrgTime = zeros(size(futureSOCs)); % Initialize chag time to zeros
    futureCurr = curr;
    idx = futureCurr <= MIN_CHRG_CURR; % Make members of U a small value if it is zero
    curr = futureCurr .* (~idx) + MIN_CHRG_CURR .*idx;
    chrgTime = ( (futureSOCs - currentSOCs) .* cap' * 3600 )./ abs(curr); % Sum each column (i.e. each value in pred horizon)
%}

% %%%%%%%%%%%%%%%%%%  Temp Rise Rate calculation  %%%%%%%%%%%%%%%%%%%%%
%{
    % Using Surf Temp since it is what we can measure
    futureTs = X(2:p+1, xIND.Ts); % Ts representing future single timestep SOC
    currentTs = X(1:p, xIND.Ts);
%     tempRate = zeros(size(futureTs)); % Initialize temp. rate to zeros
    tempRate = futureTs - currentTs; % Sum each column (i.e. each value in pred horizon)
%}

% %%%%%%%%%%%%%%%%%%%%%%%  Anode Potential   %%%%%%%%%%%%%%%%%%%%%%%%%%
%{
    curr = X(2:p+1, xIND.Curr);
    anPotMdl = predMdl.ANPOT;
    ANPOTind = curr < 0;
    interpCurr = curr .* (ANPOTind);
    AnodePot = qinterp2(-anPotMdl.Curr, anPotMdl.SOC, anPotMdl.ANPOT,...
                    interpCurr, X(2:p+1, xIND.SOC));
    
%     AnodePot = lookup2D(-anPotMdl.Curr, anPotMdl.SOC, anPotMdl.ANPOT,...
%                     interpCurr, X(2:p+1, xIND.SOC));
%     AnodePot = reshape(AnodePot, size(curr));
%}
% AnodePot = X(2:p+1, xIND.ANPOT);


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Objective Function Weights (0, 1, 5, 20 etc))
% ---------------------------------------------------------------------
A = 100; % SOC Tracking
% If SOC is past the set balance SOC range, then don't let the SOC dev
% affect the cost function.
A_dev = 200 * predMdl.Curr.balWeight; 


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Scaling Factors for each objective
% ---------------------------------------------------------------------
scale_soc = 1; % 0.075; % 0.0025;


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Cost Function
% ---------------------------------------------------------------------
fastChargingCost = sum( ( (A/scale_soc) .* (socTracking) ) .^2);
socBalancingCost = sum( ( (A_dev/scale_soc) .* (0 - socDev) ) .^2);
J = sum([...
    fastChargingCost,  ... % avgSOC) ) .^2),  ... %
    socBalancingCost,  ...
    ... % sum( ( (D/scale_ANPOT) .* (ref(:, 1*NUMCELLS+1:2*NUMCELLS) - AnodePot) ) .^2),  ...
    ... % sum( ( (C./scale_TR) .* (ref(:, 2*NUMCELLS+1:3*NUMCELLS) - tempRate) ) .^2),  ...
    ... % sum( ( (E/1) .* (0 - U(2:p+1,1:NUMCELLS)) ) .^2),  ...
    e.^2, ...
    ], 'all');

end

function [G, Gmv, Ge] = myCostJacobian(X, U, e, data, p1, p2, p3, p4)
% Parameters (p#)
% dt          = p1;   % Algorithm sample time
% predMdl     = p2;   % Predictive Battery Model Structure
% cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x)and OUTPUTS (y) presented as a struts

% NUMCELLS = cellData.NUMCELLS;
xIND = indices.x;

parameters = {p1, p2, p3, p4};
p = data.PredictionHorizon;


%% Get sizes
x0 = X;
u0 = U;
e0 = e;
nx = size(x0,2);
imv = data.MVIndex;
nmv = length(imv);
Jx  = zeros(nx, p);
Jmv = zeros(nmv, p);
% Perturb each variable by a fraction (dv) of its current absolute value.
dv = 1e-6;

f0 = myCostFunction(x0, u0, e0, data, parameters{:});

%% Get Jx
xa = abs(x0);
xa(xa < 1) = 1;  % Prevents perturbation from approaching eps.
for i = 1:p
    for j = xIND.SOC % Only calculating wrt soc here since it is the only one used in the cost func % 1:nx
        ix = i + 1; % Starts iterating from the second state
        dx = dv*xa(j);
        x0(ix,j) = x0(ix,j) + dx;
        
        f = myCostFunction(x0, u0, e0, data, parameters{:});
        
        x0(ix,j) = x0(ix,j) - dx;
        df = (f - f0)/dx;
        Jx(j, i) = df;
    end
end

%% Get Ju - How does the cost change wrt to each input
ua = abs(u0);
ua(ua < 1) = 1;
for i = 1:p-1
    for j = 1:nmv
        k = imv(j);
        du = dv*ua(k);
        u0(i,k) = u0(i,k) + du;
        f = myCostFunction(x0, u0, e0, data, parameters{:});
        u0(i,k) = u0(i,k) - du;
        df = (f - f0)/du;
        Jmv(j,i) = df;
    end
end
% special handling of p to account for mv(p+1,:) = mv(p,:)
for j = 1:nmv
    k = imv(j);
    du = dv*ua(k);
    u0(p,k) = u0(p,k) + du;
    u0(p+1,k) = u0(p+1,k) + du;
    f = myCostFunction(x0, u0, e0, data, parameters{:});
    u0(p,k) = u0(p,k) - du;
    u0(p+1,k) = u0(p+1,k) - du;
    df = (f - f0)/du;
    Jmv(j,p) = df;
end

%% Get Je
% Use central difference in this case as large default ECR magnifies
% error in forward difference formula
ea = max(1e-6, abs(e0)); 
de = ea*dv;
f1 = myCostFunction(x0, u0, e0+de, data, parameters{:});
f2 = myCostFunction(x0, u0, e0-de, data, parameters{:});
Je = (f1 - f2)/(2*de);

G = Jx';
Gmv = Jmv';
Ge = Je;

end

function cineq = myIneqConFunction(X, U, e, data, p1, p2, p3, p4)
% Parameters (p#)
% dt          = p1;   % Algorithm sample time
predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x)and OUTPUTS (y) presented as a struts

% NUMCELLS = cellData.NUMCELLS;
% xIND = indices.x;
yIND = indices.y;

p = data.PredictionHorizon;

if predMdl.Curr.balWeight == 1
    MAX_CHRG_VOLT = cellData.MAX_CHRG_VOLT - 0.1;
else
    MAX_CHRG_VOLT = cellData.MAX_CHRG_VOLT - 0.02;
end

horizonInd = 2:p+1;
Y = zeros(p, indices.ny);
for i = 1:p+1
    Y(i,:) = P06_OutputFcn_HW(X(i,:)',U(i,:)',p1, p2, p3, p4)';
end
cineq0 = (Y(horizonInd, yIND.Volt) - MAX_CHRG_VOLT')';
cineq = cineq0(:);

end

function [Geq, Gmv, Ge] = myIneqConJacobian(X, U, e, data, p1, p2, p3, p4)
% Parameters (p#)
% dt          = p1;   % Algorithm sample time
% predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x)and OUTPUTS (y) presented as a struts

NUMCELLS = cellData.NUMCELLS;
xIND = indices.x;

parameters = {p1, p2, p3, p4};
p = data.PredictionHorizon;

horizonInd = 2:p+1; % Update regularly from "myIneqConFunction"

x0 = X;
u0 = U;

%% Get sizes
nx = size(x0,2);
imv = data.MVIndex;
nmv = length(imv);
f0 = myIneqConFunction(x0, u0, e, data, parameters{:});
nf = length(f0);    
Jx = zeros(nf, nx, p);
Jmv = zeros(nf, nmv, p);
Je = zeros(nf, 1);
% Perturb each variable by a fraction (dv) of its current absolute value.
dv = 1e-6;

%% Get Jx
xa = abs(x0);
xa(xa < 1) = 1;  % Prevents perturbation from approaching eps.
C = zeros(nf, nx);
for j = xIND.Curr %1:nx
    dx = dv*xa(horizonInd(1), j);
    x0(horizonInd(1), j) = x0(horizonInd(1), j) + dx;
    f = myIneqConFunction(x0, U, e, data, parameters{:});
    x0(horizonInd(1), j) = x0(horizonInd(1), j) - dx;
    C(:,j) = (f - f0)/dx;
end

for ix = 1:length(horizonInd) 
    % Avoid using ix=1 ("how does the ineq change wrt to the previous state changing")
    % since it doesn't change the ineqs
    if horizonInd(ix)==1, continue; end 
    
    %{
    % SOC
    dx = dv*xa(xIND.SOC);
    x0(ix, xIND.SOC) = x0(ix, xIND.SOC) + dx;  % Perturb all states
    f = myIneqConFunction(x0, U, e, data, parameters{:});
    x0(ix, xIND.SOC) = x0(ix, xIND.SOC) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, xIND.SOC, ix-1) = dff;
    
    % V1
    dx = dv*xa(xIND.V1);
    x0(ix, xIND.V1) = x0(ix, xIND.V1) + dx;  % Perturb all states
    f = myIneqConFunction(x0, U, e, data, parameters{:});
    x0(ix, xIND.V1) = x0(ix, xIND.V1) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, xIND.V1, ix-1) = dff;
    
    % V2
    dx = dv*xa(xIND.V2);
    x0(ix, xIND.V2) = x0(ix, xIND.V2) + dx;  % Perturb all states
    f = myIneqConFunction(x0, U, e, data, parameters{:});
    x0(ix, xIND.V2) = x0(ix, xIND.V2) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, xIND.V2, ix-1) = dff;
    
    % Tc
    dx = dv*xa(xIND.Tc);
    x0(ix, xIND.Tc) = x0(ix, xIND.Tc) + dx;  % Perturb all states
    f = myIneqConFunction(x0, U, e, data, parameters{:});
    x0(ix, xIND.Tc) = x0(ix, xIND.Tc) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, xIND.Tc, ix-1) = dff;
    
    % Ts
    dx = dv*xa(xIND.Ts);
    x0(ix, xIND.Ts) = x0(ix, xIND.Ts) + dx;  % Perturb all states
    f = myIneqConFunction(x0, U, e, data, parameters{:});
    x0(ix, xIND.Ts) = x0(ix, xIND.Ts) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, xIND.Ts, ix-1) = dff;
    %}
    
    Jx(1+(ix-1)*NUMCELLS:ix*NUMCELLS, xIND.V1, ix) = -1.00 * eye(NUMCELLS);
    Jx(1+(ix-1)*NUMCELLS:ix*NUMCELLS, xIND.V2, ix) = -1.00 * eye(NUMCELLS);
    Jx(1+(ix-1)*NUMCELLS:ix*NUMCELLS, xIND.Curr, ix) = C(1:NUMCELLS, xIND.Curr);% -0.01 * eye(NUMCELLS);
end

%% Get Ju
%{
ua = abs(u0);
ua(ua < 1) = 1;
k = 1:NUMCELLS;


for i = horizonInd(horizonInd <= p-1) 
        du = dv*ua(i, k);
        u0(i,k) = u0(i,k) + du;
        f = myIneqConFunction(X, u0, e, data, parameters{:});
        u0(i,k) = u0(i,k) - du;
        duu = repmat(du, length(f0)/NUMCELLS, 1);
        df = (f - f0)./ duu(:);
        dff = zeros(length(f0), NUMCELLS);
        for cellNum = 1:NUMCELLS
            ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
            dff(ind, cellNum) = df(ind);
        end
        Jmv(:, k, i) = dff;
        Jmv(:, nmv, i) = df;
end
if max((horizonInd == p) | (horizonInd == p+1))
        du = dv*ua(k);
        u0(p,k) = u0(p,k) + du;
        u0(p+1,k) = u0(p+1,k) + du;
        f = myIneqConFunction(X, u0, e, data, parameters{:});
        u0(p,k) = u0(p,k) - du;
        u0(p+1,k) = u0(p+1,k) - du;
        duu = repmat(du, length(f0)/NUMCELLS, 1);
        df = (f - f0)./ duu(:);
        dff = zeros(length(f0), NUMCELLS);
        for cellNum = 1:NUMCELLS
            ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
            dff(ind, cellNum) = df(ind);
        end
        Jmv(:, k, p) = dff;
        Jmv(:, nmv, p) = df;
end
%}
ua = abs(u0);
ua(ua < 1) = 1;

i = horizonInd(1);
for j = 1:nmv
    k = imv(j);
    du = dv*ua(k);
    u0(i,k) = u0(i,k) + du;
    f = myIneqConFunction(X, u0, e, data, parameters{:});
    u0(i,k) = u0(i,k) - du;
    df = (f - f0)/du;
    Jmv(:,j,i) = df;
end

%{
% matx = Jmv( 1+(horizonInd(1)-1)*NUMCELLS : horizonInd(1)*NUMCELLS , :, i );
% for x = 2:nmv-1
%     Jmv( 1+(horizonInd(x)-1)*NUMCELLS : horizonInd(x)*NUMCELLS , :, x ) = matx;
% end
% 
% Jmv( 1+(horizonInd(p)-1)*NUMCELLS : horizonInd(p+1)*NUMCELLS , :, p ) = [matx; matx];
%}

matx = Jmv( 1 : NUMCELLS , :, i );
for x = 2:length(horizonInd)-2
%     Jmv( 1+(horizonInd(x)-1)*NUMCELLS : horizonInd(x)*NUMCELLS , :, x ) = matx;
    i = i+1;
    Jmv( 1+(x-1)*NUMCELLS : x*NUMCELLS , :, i ) = matx;
end

Jmv( 1+((length(horizonInd)-1)-1)*NUMCELLS : length(horizonInd)*NUMCELLS , :, p ) = [matx; matx];

%{
% for j = 1:nmv
%     k = imv(j);
%     du = dv*ua(k);
%     u0(p,k) = u0(p,k) + du;
%     u0(p+1,k) = u0(p+1,k) + du;
%     f = myIneqConFunction(X, u0, e, data, parameters{:});
%     u0(p,k) = u0(p,k) - du;
%     u0(p+1,k) = u0(p+1,k) - du;
%     df = (f - f0)/du;
%     Jmv(:,j,p) = df;
% end
%}


% From Matlab's ineq function
%{
for i = 1:p-1
    for j = 1:nmv
        k = imv(j);
        du = dv*ua(k);
        u0(i,k) = u0(i,k) + du;
        f = myIneqConFunction(X, u0, e, data, parameters{:});
        u0(i,k) = u0(i,k) - du;
        df = (f - f0)/du;
%         for ii = 1:nf
%             Jmv(ii,j,i) = df(ii);
%         end
        Jmv(:,j,i) = df;
    end
end
% special handling of p to account for mv(p+1,:) = mv(p,:)
for j = 1:nmv
    k = imv(j);
    du = dv*ua(k);
    u0(p,k) = u0(p,k) + du;
    u0(p+1,k) = u0(p+1,k) + du;
    f = myIneqConFunction(X, u0, e, data, parameters{:});
    u0(p,k) = u0(p,k) - du;
    u0(p+1,k) = u0(p+1,k) - du;
    df = (f - f0)/du;
%     for ii = 1:nf
%         Jmv(ii,j,p) = df(ii);
%     end
    Jmv(:,j,p) = df;
end
%}

%% Outputs
Geq = permute(Jx, [3,2,1]);
Gmv = permute(Jmv, [3,2,1]);
Ge = Je(:);

end

function [A, Bmv] = myStateJacobian(x, u, p1, p2, p3, p4)

% Parameters (p#)
% dt          = p1;   % Algorithm sample time
% predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x) and OUTPUTS (y) presented as a struts

NUMCELLS = cellData.NUMCELLS;

xIND = indices.x;

nx = indices.nx; % Number of states
nmv = indices.nu; % Number of inputs. In this case, current for each cell + PSU current

parameters = {p1, p2, p3, p4};

x0 = x;
u0 = u;

f0 = P06_BattStateFcn_HW(x0, u0, parameters{:});

%% Get sizes
Jx = zeros(nx, nx);
Jmv = zeros(nx, nmv);
% Perturb each variable by a fraction (dv) of its current absolute value.
dv = 1e-6;

%% Get Jx - How do the states change when each state is changed?

xa = abs(x0);
xa(xa < 1) = 1;  % Prevents perturbation from approaching eps.

% SOC - How does changing the SOC change the states (SOC, V1, and V2. Tc or
% Ts don't change)


Jx(xIND.SOC, xIND.SOC) = eye(NUMCELLS); % Jacobian for the SOCs since they don't change when perturbed

%{
dx = dv*xa(xIND.SOC);
x0(xIND.SOC) = x0(xIND.SOC) + dx;  % Perturb all states
f = P06_BattStateFcn_HW(x0, u0, parameters{:});
x0(xIND.SOC) = x0(xIND.SOC) - dx;  % Undo pertubation
df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
Jx(xIND.SOC, xIND.SOC) = diag(df(xIND.SOC, 1));
% Jx(xIND.V1, xIND.SOC) = diag(df(xIND.V1, 1));
% Jx(xIND.V2, xIND.SOC) = diag(df(xIND.V2, 1));
% Jx(xIND.Tc, xIND.SOC) = diag(df(xIND.Tc, 1));
% Jx(xIND.Ts, xIND.SOC) = diag(df(xIND.Ts, 1));
%}


% RC Voltages - V1 and V2. 
%   (Because V1 and V2 don't change wrt each other,
%    their jacobians can be computed in one go.)

%{
dx = dv*xa([xIND.V1, xIND.V2]);
x0([xIND.V1, xIND.V2]) = x0([xIND.V1, xIND.V2]) + dx; % Perturb only V1 and V2
[v1, v2] = getRC_Volt(battMdl, dt, -abs(uc), x0(xIND.SOC)', x0_Tavg, x0(xIND.V1)', x0(xIND.V2)');
x0([xIND.V1, xIND.V2]) = x0([xIND.V1, xIND.V2]) - dx; % Undo pertubation

f = [v1(:); v2(:)];
df = (f - f0([xIND.V1, xIND.V2]))./dx;
Jx = replaceDiag(Jx, df, [xIND.V1, xIND.V2], 0);
%}

% V1
dx = dv*xa(xIND.V1);
x0(xIND.V1) = x0(xIND.V1) + dx;  % Perturb all states
f = P06_BattStateFcn_HW(x0, u0, parameters{:});
x0(xIND.V1) = x0(xIND.V1) - dx;  % Undo pertubation
df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
Jx(xIND.SOC, xIND.V1) = diag(df(xIND.SOC, 1));
Jx(xIND.V1, xIND.V1) = diag(df(xIND.V1, 1));
Jx(xIND.V2, xIND.V1) = diag(df(xIND.V2, 1));
Jx(xIND.Tc, xIND.V1) = diag(df(xIND.Tc, 1));
Jx(xIND.Ts, xIND.V1) = diag(df(xIND.Ts, 1));

% V2
dx = dv*xa(xIND.V2);
x0(xIND.V2) = x0(xIND.V2) + dx;  % Perturb all states
f = P06_BattStateFcn_HW(x0, u0, parameters{:});
x0(xIND.V2) = x0(xIND.V2) - dx;  % Undo pertubation
df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
Jx(xIND.SOC, xIND.V2) = diag(df(xIND.SOC, 1));
Jx(xIND.V1, xIND.V2) = diag(df(xIND.V1, 1));
Jx(xIND.V2, xIND.V2) = diag(df(xIND.V2, 1));
Jx(xIND.Tc, xIND.V2) = diag(df(xIND.Tc, 1));
Jx(xIND.Ts, xIND.V2) = diag(df(xIND.Ts, 1));


% Tc and Ts Temperatures.
% How does V1, V2, Tc and Ts change wrt Tc and Ts respectively? soc does
% not change wrt Tc or Ts (at least not in this algorithm)

%{
dx_tc = dv*xa(xIND.Tc);
x0(xIND.Tc) = x0(xIND.Tc) + dx_tc; % Perturb only V1 and V2
f_tc = calcTemp (uc, [x0(xIND.Tc)'; x0(xIND.Ts)'], dt, Tf);
x0_Tavg = mean([x0(xIND.Tc), x0(xIND.Ts)], 2)';
[v1, v2] = getRC_Volt(battMdl, dt, -abs(uc), x0(xIND.SOC)', x0_Tavg, x0(xIND.V1)', x0(xIND.V2)');
f_tc = [v1(:); v2(:); f_tc(1, :)'; f_tc(2, :)'];
x0(xIND.Tc) = x0(xIND.Tc) - dx_tc; % Undo pertubation

dx_ts = dv*xa(xIND.Ts);
x0(xIND.Ts) = x0(xIND.Ts) + dx_ts; % Perturb only V1 and V2
f_ts = calcTemp (uc, [x0(xIND.Tc)'; x0(xIND.Ts)'], dt, Tf);
x0_Tavg = mean([x0(xIND.Tc), x0(xIND.Ts)], 2)';
[v1, v2] = getRC_Volt(battMdl, dt, -abs(uc), x0(xIND.SOC)', x0_Tavg, x0(xIND.V1)', x0(xIND.V2)');
f_ts = [v1(:); v2(:); f_ts(1, :)'; f_ts(2, :)'];
x0(xIND.Ts) = x0(xIND.Ts) - dx_ts; % Undo pertubation

ix = [xIND.V1, xIND.V2, xIND.Tc, xIND.Ts];

df_tc = (f_tc - f0(ix)) ./ repmat(dx_tc(:), (nx/NUMCELLS)-1, 1); % (f-f0)./dx
df_ts = (f_ts - f0(ix)) ./ repmat(dx_ts(:), (nx/NUMCELLS)-1, 1); % (f-f0)./dx

soc_change = zeros(size(xIND.SOC'));
df_tc = [soc_change; df_tc];
df_ts = [soc_change; df_ts];

df_tc = [diag(df_tc(xIND.SOC)); diag(df_tc(xIND.V1)); diag(df_tc(xIND.V2));...
            diag(df_tc(xIND.Tc)); diag(df_tc(xIND.Ts))];
df_ts = [diag(df_ts(xIND.SOC)); diag(df_ts(xIND.V1)); diag(df_ts(xIND.V2));...
            diag(df_ts(xIND.Tc)); diag(df_ts(xIND.Ts))];

Jx(: , xIND.Tc) = df_tc;
Jx(: , xIND.Ts) = df_ts;
%}
% % TC
% dx = dv*xa(xIND.Tc);
% x0(xIND.Tc) = x0(xIND.Tc) + dx;  % Perturb all states
% f = P06_BattStateFcn_HW(x0, u0, parameters{:});
% x0(xIND.Tc) = x0(xIND.Tc) - dx;  % Undo pertubation
% df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
% Jx(xIND.SOC, xIND.Tc) = diag(df(xIND.SOC, 1));
% Jx(xIND.V1, xIND.Tc) = diag(df(xIND.V1, 1));
% Jx(xIND.V2, xIND.Tc) = diag(df(xIND.V2, 1));
% Jx(xIND.Tc, xIND.Tc) = diag(df(xIND.Tc, 1));
% Jx(xIND.Ts, xIND.Tc) = diag(df(xIND.Ts, 1));

Jx(xIND.Tc, xIND.Tc) = 0.991240769925956 * eye(NUMCELLS);
Jx(xIND.Ts, xIND.Tc) = 0.966062163308749 * eye(NUMCELLS);

% % TS
% dx = dv*xa(xIND.Ts);
% x0(xIND.Ts) = x0(xIND.Ts) + dx;  % Perturb all states
% f = P06_BattStateFcn_HW(x0, u0, parameters{:});
% x0(xIND.Ts) = x0(xIND.Ts) - dx;  % Undo pertubation
% df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
% Jx(xIND.SOC, xIND.Ts) = diag(df(xIND.SOC, 1));
% Jx(xIND.V1, xIND.Ts) = diag(df(xIND.V1, 1));
% Jx(xIND.V2, xIND.Ts) = diag(df(xIND.V2, 1));
% Jx(xIND.Tc, xIND.Ts) = diag(df(xIND.Tc, 1));
% Jx(xIND.Ts, xIND.Ts) = diag(df(xIND.Ts, 1));

% Jx(xIND.Tc, xIND.Ts) = 0.967016120252270 * eye(NUMCELLS);
% Jx(xIND.Ts, xIND.Ts) = 0.003840263642064 * eye(NUMCELLS);

Jx(xIND.Tc, xIND.Ts) = 0.003936465759280 * eye(NUMCELLS);
Jx(xIND.Ts, xIND.Ts) = 0.003836475313207 * eye(NUMCELLS);


%% Get Jmv - How do the states change when each manipulated variable is changed?
%{
ua = abs(u0); % (1:NUMCELLS)
ua(ua < 1) = 1;
du = dv*ua(1:NUMCELLS);
u0(1:NUMCELLS) = u0(1:NUMCELLS) + du;
f = P06_BattStateFcn_HW(x0, u0, parameters{:});
u0(1:NUMCELLS) = u0(1:NUMCELLS) - du;
df = (f - f0) ./ repmat(du, (nx/NUMCELLS), 1);

du = dv*ua(end);
u0(end) = u0(end) + du;
f = P06_BattStateFcn_HW(x0, u0, parameters{:});
u0(end) = u0(end) - du;
df2 = (f - f0) ./ du;


Jmv(xIND.SOC, 1:NUMCELLS) = diag(df(xIND.SOC));
Jmv(xIND.V1, 1:NUMCELLS) = diag(df(xIND.V1));
Jmv(xIND.V2, 1:NUMCELLS) = diag(df(xIND.V2));
Jmv(xIND.Tc, 1:NUMCELLS) = diag(df(xIND.Tc));
Jmv(xIND.Ts, 1:NUMCELLS) = diag(df(xIND.Ts));

Jmv = [Jmv, df2];
%}

ua = abs(u0);
ua(ua < 1) = 1;
for j = 1:nmv
    k = j; % imv(j);
    du = dv*ua(k);
    u0(k) = u0(k) + du;
    f = P06_BattStateFcn_HW(x0, u0, parameters{:});
    u0(k) = u0(k) - du;
    df = (f - f0)/du;
    Jmv(:,j) = df;
end

A = Jx;
Bmv = Jmv;

end

function C = myOutputJacobian(x, u, p1, p2, p3, p4)
% Parameters (p#)
% dt          = p1;   % Algorithm sample time
% predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x) and OUTPUTS (y) presented as a struts

NUMCELLS = cellData.NUMCELLS;

xIND = indices.x;
yIND = indices.y;

nx = indices.nx; % Number of states
ny = indices.ny; % Number of states
C = zeros(ny, nx);

C(yIND.Volt, xIND.V1)   = -1.00 * eye(NUMCELLS);
C(yIND.Volt, xIND.V2)   = -1.00 * eye(NUMCELLS);
C(yIND.Ts, xIND.Ts)     =  1.00 * eye(NUMCELLS);

parameters = {p1, p2, p3, p4};

x0 = x;
u0 = u;

f0 = P06_OutputFcn_HW(x0, u0, parameters{:});
vec = [xIND.SOC, xIND.Curr];

% Perturb each variable by a fraction (dv) of its current absolute value.
dv = 1e-6;
%% Get Jx
xa = abs(x0);
xa(xa < 1) = 1;  % Prevents perturbation from approaching eps.
for j = vec %1:nx
    dx = dv*xa(j);
    x0(j) = x0(j) + dx;
    f = P06_OutputFcn_HW(x0,u0,parameters{:});
    x0(j) = x0(j) - dx;
    C(:,j) = (f - f0)/dx;
end

end



function dataQueryTimerFcn(varargin)
% Get latest states (Measurement)
script_queryData;
script_failSafes; %Run FailSafe Checks
script_checkGUICmd; % Check to see if there are any commands from GUI
% if limits are reached, break loop
if errorCode == 1 || strcmpi(testStatus, "stop")
    script_idle;
    dataQueryTimerStopped();
end
end

function dataQueryTimerStopped(varargin)
% script_resetDevices;
dataQueryTimer = varargin{1};
% v2 = varargin{2}
disp("dataQueryTimer Instant Period = " + num2str(dataQueryTimer.InstantPeriod) + "s");
disp("dataQueryTimer Average Period = " + num2str(dataQueryTimer.AveragePeriod) + "s");
    
disp("dataQueryTimer has stopped");

end
