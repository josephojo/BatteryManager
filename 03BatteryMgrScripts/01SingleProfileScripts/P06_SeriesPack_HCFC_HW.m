%% Series-Pack Fast Charging
% By Joseph Ojo
%
% The ECM battery model used in this file was adopted from the work by:
%
% Xinfan Lin, Hector Perez, Jason Siegel, Anna Stefanopoulou
%
%
%% Change Current Directory

% clearvars;
%
% currFilePath = mfilename('fullpath');
% [mainPath, filename, ~] = fileparts(currFilePath);
% cd(mainPath)

%% Initialize Variables and Devices
try
    if ~exist('cellIDs', 'var') || isempty(cellIDs)
        % cellIDs should only be one cell
        cellIDs = ["AB1", "AB4", "AB5", "AB6"]; % ID in Cell Part Number (e.g BAT11-FEP-AA1). Defined again in initializeVariables
        packID = "PK02";
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
        currFilePath = mfilename('fullpath');
        % Seperates the path directory and the filename
        [path, ~, ~] = fileparts(currFilePath);
        
        str = extractBetween(path,"",...
            "03DataGen","Boundaries","inclusive");
        testSettings.saveDir = str + "\01CommonDataForBattery";
        
        testSettings.cellConfig = "series";
        
        testSettings.saveName   = "00SP_HCFC_" + cellIDs;
        testSettings.purpose    = "To use in identifying the RC parameters for an ECM model";
        testSettings.tempChnls  = [9, 10, 11, 12, 13];
        testSettings.trigPins = []; % Fin in every pin that should be triggered
        testSettings.trigInvert = []; % Fill in 1 for every pin that is reverse polarity (needs a zero to turn on)
        testSettings.trigStartTimes = {[100]}; % cell array of vectors. each vector corresponds to each the start times for each pin
        testSettings.trigDurations = {15}; % cell array of vectors. each vector corresponds to each the duration for each pin's trigger
    end
    
    script_initializeVariables; % Run Script to initialize common variables
    script_initializeDevices; % Run Script to initialize control devices
    verbosity = 2; % Data measurements are not displayed since the results from the MPC will be.
    script_queryData; % Get initial states from measurements.
 catch ME
    script_handleException;
end   


%% Constants
pause(1); % Wait for the EEprom Data to be updated
NUMCELLS = length(cellIDs);
% MAX_BAL_CURR = bal.EEPROM_Data(1, 1).Charge_Currents(logical(bal.cellPresent(1, :))) ...
%         / DC2100A.MA_PER_A;
% MIN_BAL_CURR = -1 * bal.EEPROM_Data(1, 1).Charge_Currents(logical(bal.cellPresent(1, :))) ...
%         / DC2100A.MA_PER_A;

% Since the Current gotten from the EEProm (for 6 cells) is different than what
% it actually is for 4 cells, use these measured values first
MAX_BAL_CURR = 5.3;
MIN_BAL_CURR = -1.5;

MAX_CELL_CURR = batteryParam.maxCurr(cellIDs);
MAX_CELL_VOLT = batteryParam.chargedVolt(cellIDs);
MIN_CELL_VOLT = batteryParam.dischargedVolt(cellIDs);
CAP = batteryParam.capacity(cellIDs);  % battery capacity


cellData.NUMCELLS = NUMCELLS;
cellData.MAX_BAL_CURR = MAX_BAL_CURR;
cellData.MIN_BAL_CURR = MIN_BAL_CURR;
cellData.MAX_CELL_CURR = MAX_CELL_CURR;
cellData.MAX_CELL_VOLT = MAX_CELL_VOLT;
cellData.MIN_CELL_VOLT = MIN_CELL_VOLT;
cellData.CAP = CAP;


xIND.SOC    = 1;
xIND.V1     = 2;
xIND.V2     = 3;
xIND.Tc     = 4;
xIND.Ts     = 5;

yIND.SOC    = 1;
yIND.Volt   = 2;
yIND.Ts     = 3;

indices.x = xIND;
indices.y = yIND;


TARGET_SOC = 0.98;
Tf = thermoData(1); % Ambient Temp


numStatesPerCell = length(fields(xIND));
numOutputsPerCell = length(fields(yIND));


nx = numStatesPerCell*NUMCELLS; % Number of states
ny = numOutputsPerCell*NUMCELLS; % Number of outputs
nu = NUMCELLS + 1; % Number of inputs. In this case, current for each cell + PSU current

sampleTime = 1; % 0.5; % Sample time [s]
prevTime = 0; prevElapsed = 0;

balBoard_num = 0; % ID for the main balancer board

%% Initialize Plant variables and States 
% #############  Initial States  ##############
battData = struct;
battData.time           = 0;
battData.Ts             = thermoData(2:end);    % Surface Temp
battData.Tc             = thermoData(2:end);    % Initialize core temperature to surf Temp
battData.Tf             = Tf;                   % Ambient Temp
battData.volt           = cells.volt(cellIDs);
battData.curr           = cells.curr(cellIDs); % zeros(1, NUMCELLS);
battData.LiPlateRate    = zeros(1, NUMCELLS);

initialSOCs = cells.SOC(cellIDs);

battData.SOC            = initialSOCs(1:NUMCELLS);
battData.Cap            = CAP;

battData.Cost = 0;
battData.timeLeft = zeros(1, NUMCELLS);
battData.ExitFlag = 0;
battData.balCurr = zeros(1, NUMCELLS);
battData.optCurr = zeros(1, NUMCELLS);
battData.optPSUCurr = zeros(1, 1);


ind = 1;
xk = zeros(nx, 1);

xk(ind:ind+NUMCELLS-1, :)   =  battData.SOC'         ; ind = ind + NUMCELLS;
xk(ind:ind+NUMCELLS-1, :)   =  zeros(1, NUMCELLS)'   ; ind = ind + NUMCELLS; % V1 - Voltage accross RC1
xk(ind:ind+NUMCELLS-1, :)   =  zeros(1, NUMCELLS)'   ; ind = ind + NUMCELLS; % V2 - Voltage accross RC2
xk(ind:ind+NUMCELLS-1, :)   =  battData.Tc'          ; ind = ind + NUMCELLS;
xk(ind:ind+NUMCELLS-1, :)   =  battData.Ts'          ; ind = ind + NUMCELLS;

%% Predictive Model
try
    % Voltage Model
    load(dataLocation + '008OCV_AB1_Rev2.mat', 'OCV', 'SOC'); % Lithium plating rate
    R1 = 0.0145 * ones(1, NUMCELLS);
    R2 = -0.0037 * ones(1, NUMCELLS);
    C1 = 1.1506e3 * ones(1, NUMCELLS);
    C2 = 1.1398e5 * ones(1, NUMCELLS);
    Rs = 0.0103 * ones(1, NUMCELLS);
    
    A11 = -1./(R1 .* C1);
    A12 = zeros(1, length(A11));
    A1 = [A11; A12];
    A1 = A1(:)';
    A21 = -1./(R2 .* C2);
    A22 = zeros(1, length(A21));
    A2 = [A22; A21];
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
    voltMdl.Rs = Rs;
    voltMdl.OCV = OCV;
    voltMdl.SOC = SOC;
    
    cc = 62.7; % 67;
    cs = 4.5;
    rc = 1.94; % 3.8468;
    re = 0.024218;
    ru = 15; % 15.987;
    
    % A,B,C,D Matrices  ***
    AT_cont = [-1/(rc*cc), 1/(rc*cc) ; 1/(rc*cs), ((-1/cs)*((1/rc) + (1/ru)))];
    BT_cont = [(re)/cc 0; 0, 1/(ru*cs)];
    C = [0 0; 0 1]; %eye(2);
    D = [0, 0;0, 0];
    
    tempMdl = struct;
    tempMdl.A_cont = AT_cont;
    tempMdl.B_cont = BT_cont;
    tempMdl.C = C;
    tempMdl.D = D;
    
    A_Dis = expm(tempMdl.A_cont * sampleTime);
    tempMdl.A = A_Dis;
    tempMdl.B = tempMdl.A\(A_Dis - eye(size(A_Dis,1))) * tempMdl.B_cont;
    tempMdl.Tf = Tf; % Ambient Temp
    
    % SOC Deviation Matrix
    L2 = [zeros(NUMCELLS-1, 1), (-1 * eye(NUMCELLS-1))];
    L1 = eye(NUMCELLS);
    L1(end, :) = [];
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
    
    % Lithium Plating Lookup table (From "LiPlateRate.mat")
    load(dataLocation + 'LiPlateRate.mat'); % Lithium plating rate
    [Xmesh, Ymesh] = meshgrid(LiPlateCurr, LiPlateSOC);
    lprMdl.Curr = Xmesh;
    lprMdl.SOC = Ymesh;
    lprMdl.LPR = LiPlateRate;
    
    predMdl.Volt = voltMdl;
    predMdl.Temp = tempMdl;
    predMdl.SOC = socMdl;
    predMdl.LPR = lprMdl;
    % predMdl.lookupTbl = battMdl.Lookup_tbl; % Using the lookup table from plant model
catch ME
    script_handleException;
end

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
    for i = 1:NUMCELLS
        mpcObj.MV(i).Max =  MAX_BAL_CURR;      mpcObj.MV(i).RateMax =  0.5; % MAX_CELL_CURR;
        mpcObj.MV(i).Min =  -MAX_BAL_CURR;     mpcObj.MV(i).RateMin = -0.5; % -2; % -6
    end
    
    mpcObj.MV(NUMCELLS + 1).Max =  0;
    mpcObj.MV(NUMCELLS + 1).Min =  -(MAX_CELL_CURR - MAX_BAL_CURR);
    mpcObj.MV(NUMCELLS + 1).RateMax =  2; % MAX_CELL_CURR;
    mpcObj.MV(NUMCELLS + 1).RateMin = -2; % -6
    
    % Equality Limits for state/output vars for each cell
    for i=1:NUMCELLS
        % SOC
        mpcObj.States(i + (xIND.SOC-1) * NUMCELLS).Max =  0.99;
        mpcObj.States(i + (xIND.SOC-1) * NUMCELLS).Min =  0;
        
        % Ts
        mpcObj.States(i + (xIND.Ts-1) * NUMCELLS).Max =  44;
        mpcObj.States(i + (xIND.Ts-1) * NUMCELLS).Min =  0;
        mpcObj.States(i + (xIND.Ts-1) * NUMCELLS).ScaleFactor =  44;
        
        % Volt
        mpcObj.OV(i + (yIND.Volt-1) * NUMCELLS).Max =  MAX_CELL_VOLT - 0.01;
        mpcObj.OV(i + (yIND.Volt-1) * NUMCELLS).Min =  MIN_CELL_VOLT;
        mpcObj.OV(i + (yIND.Volt-1) * NUMCELLS).ScaleFactor =  MAX_CELL_VOLT;
    end
    
    
    % Add dynamic model for nonlinear MPC
    mpcObj.Model.StateFcn = @(x, u, p1, p2, p3, p4)...
        P06_BattStateFcn_HW(x, u, p1, p2, p3, p4);
    % mpcObj.Jacobian.StateFcn = @(x,u,p1, p2, p3, p4) ...
    %     myStateJacobian(x, u, p1, p2, p3, p4);
    
    mpcObj.Model.OutputFcn = @(x,u, p1, p2, p3, p4) ...
        P06_OutputFcn_HW(x, u, p1, p2, p3, p4); % SOC, Volt, Ts
    % mpcObj.Jacobian.OutputFcn = @(x,u,p1, p2, p3, p4) ... ;
    
    mpcObj.Optimization.CustomCostFcn = @(X,U,e,data, p1, p2, p3, p4)...
        myCostFunction(X, U, e, data, p1, p2, p3, p4);
    mpcObj.Jacobian.CustomCostFcn = @(x,u,e,data, p1, p2, p3, p4) ...
        myCostJacobian(x, u,e,data, p1, p2, p3, p4);
    
    % mpcObj.Optimization.CustomIneqConFcn = @(X,U,e,data, p1, p2, p3, p4)...
    %     myIneqConFunction(X,U,e,data, p1, p2, p3, p4);
    % mpcObj.Jacobian.CustomIneqConFcn = @(x,u,e,data, p1, p2, p3, p4) ...
    %     myIneqConJacobian(x, u,e,data, p1, p2, p3, p4);
    
    mpcObj.Optimization.ReplaceStandardCost = true;
    
    mpcObj.Model.IsContinuousTime = false;
    
    mpcObj.Optimization.SolverOptions.UseParallel = true;
    
    mpcObj.Optimization.UseSuboptimalSolution = true;
    
    mpcObj.Optimization.SolverOptions.MaxIterations = 150; % 20; %
    
    
    % SOC tracking, LPR tracking, and temp rise rate cuz refs have to equal number of outputs
    references = [repmat(TARGET_SOC, 1, NUMCELLS), repmat(50, 1, NUMCELLS),...
        repmat(3, 1, NUMCELLS)];
    
    u0 = [battData.curr, battData.optPSUCurr];
    
    validateFcns(mpcObj, xk, u0, [], {p1, p2, p3, p4}, references);
catch ME
    script_handleException;
end

%% Extended Kalman Filter Configuration
ekf = extendedKalmanFilter(@P06_BattStateFcn_HW, @P06_OutputFcn_HW, xk);
zCov = repmat([0.02, 0.08, 0.01], NUMCELLS, 1); 
ekf.MeasurementNoise = diag(zCov(:));
ekf.ProcessNoise = 0.05;

%% MPC Simulation Loop

close all

timer = tic;

r = rateControl(1/sampleTime);
u = zeros(NUMCELLS + 1,1);
options = nlmpcmoveopt;
options.Parameters = {p1, p2, p3, p4};
try
    dataQueryTimer = timer;
    
    % Start Measurement Timer
    dataQueryTimer.ExecutionMode = 'fixedSpacing';
    dataQueryTimer.Period = readPeriod;
    dataQueryTimer.StopFcn = @dataQueryTimerStopped;
    dataQueryTimer.TimerFcn = @dataQueryTimerFcn;
    dataQueryTimer.ErrorFcn = {@bal.Handle_Exception, []};
    % Start COMM out timer
    start(dataQueryTimer);
    
    
    sTime = [];
    while max(xk(1+NUMCELLS*(xIND.SOC-1):NUMCELLS*xIND.SOC, :) <= TARGET_SOC)
        % Run the MPC controller
        [u,~,mpcinfo] = nlmpcmove(mpcObj, xk, u,...
            references,[], options); % (:,idx-1)
        
        optCurr = u; % u<0 == Charging, u>0 == discharging
        cost = mpcinfo.Cost;
        
        % Balancer and PSU Current
        balCurr = optCurr(1:NUMCELLS);
        battData.balCurr = [battData.balCurr; balCurr'];
        optPSUCurr = optCurr(end);
        battData.optPSUCurr  = [battData.optPSUCurr ; optPSUCurr];
        
        % Set power supply current
        curr = abs(optPSUCurr); % PSU Current. Using "curr" since script in nect line uses "curr"
        script_charge;
        
        % send balance charges to balancer
        bal.SetBalanceCharges(balBoard_num, balCurr*sampleTime); % Send charges in As
        
        
        % Get Elapsed Time
        tElapsed_MPC = toc(timer);
        
        dt = tElapsed_MPC - prevElapsed;
        
        temp = thermoData(2:end);
        LPR = lookup2D( predMdl.LPR.Curr, predMdl.LPR.SOC, predMdl.LPR.LPR,...
            reshape(cells.curr(cellIDs), [], 1), reshape(cells.SOC(cellIDs), [], 1) );
        
        battData.time           = [battData.time        ; tElapsed_MPC   ]; ind = 1;
        battData.volt           = [battData.volt        ; reshape(cells.volt(cellIDs), 1, [])]; ind = ind + 1;
        battData.curr           = [battData.curr        ; reshape(cells.curr(cellIDs), 1, [])]; ind = ind + 1;
        battData.SOC            = [battData.SOC         ; reshape(cells.SOC(cellIDs), 1, [])]; ind = ind + 1;
        battData.Ts             = [battData.Ts          ; temp(:)']; ind = ind + 1;
        battData.LiPlateRate    = [battData.LiPlateRate ; LPR(:)']; ind = ind + 1;
        battData.Cost           = [battData.Cost ; cost];
        battData.ExitFlag       = [battData.ExitFlag ; mpcinfo.ExitFlag];
        
        % Get Measurements to update states (SOC, Volt, Ts)
        y = [battData.SOC(end, :), battData.volt(end, :), battData.Ts(end, :)];
        
        % Kalman filter plant measurements to get the hidden model states
        % Predict Step
        [PredictedState,PredictedStateCovariance] = predict(ekf, u, options.Parameters{:});
        
        % Correct Step
        [CorrectedState,CorrectedStateCovariance] = correct(ekf, y, u, options.Parameters{:});
        
        xk = CorrectedState';
        xk = xk(:);
        
        % Remaining Charge time
        minCurr = optPSUCurr + battData.balCurr(end, :);
        if max(u <= 0.01) == 1 % if any member of u is 0. u is current of the cells
            minCurr = 0.01; % Make u a small value if it is zero
        end
        timeLeft = ((TARGET_SOC - states(3, :)) .* battMdl.Cap * 3600)./ abs(minCurr);
        battData.timeLeft = [battData.timeLeft ; timeLeft];
        
        
        tempStr = ""; voltStr = ""; currStr = ""; socStr = ""; psuStr = "";  balStr = "";
        MPCStr = ""; LPRStr = "";
        MPCStr = MPCStr + sprintf("ExitFlag = %d\tCost = %e\n", mpcinfo.ExitFlag, cost);
        
        for i = 1:NUMCELLS-1
            tempStr = tempStr + sprintf("Ts%d = %.2f ºC\t\t" , i, states(5,i));
            voltStr = voltStr + sprintf("Volt %d = %.4f V\t", i, states(1,i));
            LPRStr = LPRStr + sprintf("LPR %d = %.3f A/m^2\t", i, states(7, i));
            balStr = balStr + sprintf("Bal %d = %.4f A\t", i, battData.balCurr(end,i));
            currStr = currStr + sprintf("Curr %d = %.4f\t", i, optCurr(i));
            socStr = socStr + sprintf("SOC %d = %.4f\t\t", i, battData.SOC(end, i));
        end
        
        for i = i+1:NUMCELLS
            tempStr = tempStr + sprintf("Ts %d = %.2f ºC\n" , i, states(5,i));
            voltStr = voltStr + sprintf("Volt %d = %.4f V\n", i, states(1,i));
            LPRStr = LPRStr + sprintf("LPR %d = %.3f A/m^2\n", i, states(7, i));
            balStr = balStr + sprintf("Bal %d = %.4f A\n", i, battData.balCurr(end,i));
            currStr = currStr + sprintf("Curr %d = %.4f\n", i, optCurr(i));
            socStr = socStr + sprintf("SOC %d = %.4f\n", i, battData.SOC(end, i));
        end
        psuStr = psuStr + sprintf("PSUCurr = %.4f A", optPSUCurr(1));
        
        disp(newline)
        disp(num2str(tElapsed_MPC,'%.2f') + " seconds");
        disp("STime: " + (tElapsed_MPC - prevElapsed) + " Seconds."); sTime = [sTime; tElapsed_MPC - prevElapsed];
        fprintf(tempStr + newline);
        fprintf(voltStr + newline);
        fprintf(LPRStr + newline);
        fprintf(psuStr + newline);
        fprintf(balStr + newline);
        fprintf(MPCStr + newline);
        fprintf(currStr + newline);
        fprintf(socStr);
        
        % curr > 0 = Discharging
        ifcurr = optCurr(1:NUMCELLS) + optCurr(end);
        if (max(ifcurr > 0 & xk(1+NUMCELLS*(xIND.SOC-1):NUMCELLS*xIND.SOC, :) <= 0.01))...
                || (max(ifcurr < 0 & xk(1+NUMCELLS*(xIND.SOC-1):NUMCELLS*xIND.SOC, :) >= 0.99))
            disp("Test Completed After: " + tElapsed_MPC + " seconds.")
            break;
        elseif endFlag == true
            disp("An error or Stop test request has occured." + newline...
                + "Test Stopped After: " + tElapsed_MPC + " seconds.")
            break;
        end
        
        prevElapsed = tElapsed_MPC;
        waitfor(r);
    end
catch ME
    dataQueryTimerStopped();
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
soc_ind = 1+(xIND.SOC-1)*NUMCELLS:xIND.SOC*NUMCELLS;

devMat = predMdl.SOC.devMat;

lprMdl = predMdl.LPR;

p = data.PredictionHorizon;
%     for i=1:p+1
%         Y(i,:) = myOutputFcn(X(i,:)',U(i,:)',p1, p2)';
%     end

curr = U(2:p+1,1:NUMCELLS) + U(2:p+1, end); % Equivalent to balCurr + PsuCurr


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get the Objective vectors in pred horizon (2:p+1)
% ( SOC, SOCdev, Chg Time, Temp. Rate, Li Plate Rate)
% --------------------------------------------------------------------------------

% %%%%%%%%%%%%%%%%%%%%%%%%%%%  Charge SOC  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
chrgSOC = X(2:p+1, 1+(xIND.SOC-1)*NUMCELLS:xIND.SOC*NUMCELLS);


% %%%%%%%%%%%%%%%%%%%%%%%%%%%  SOC Deviation  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
socDev = devMat * chrgSOC';


% %%%%%%%%%%%%%%%%%%  Charge time calculation  %%%%%%%%%%%%%%%%%%%%%%%%
%{
    % Chg Time = (Change in SOC between each timestep x capacity) / current
    futureSOCs = chrgSOC; % SOCs only in the pred horizon
    currentSOCs = X(1:p, 1+(xIND.SOC-1)*NUMCELLS : xIND.SOC*NUMCELLS); % SOCs in the current time and pred horizon minus furthest SOC
%     chrgTime = zeros(size(futureSOCs)); % Initialize chag time to zeros
    futureCurr = curr;
    idx = futureCurr <= MIN_CHRG_CURR; % Make members of U a small value if it is zero
    curr = futureCurr .* (~idx) + MIN_CHRG_CURR .*idx;
    chrgTime = ( (futureSOCs - currentSOCs) .* cap' * 3600 )./ abs(curr); % Sum each column (i.e. each value in pred horizon)
%}

% %%%%%%%%%%%%%%%%%%  Temp Rise Rate calculation  %%%%%%%%%%%%%%%%%%%%%
%{
    % Using Surf Temp since it is what we can measure
    futureTs = X(2:p+1, 1+(xIND.Ts-1)*NUMCELLS : xIND.Ts*NUMCELLS); % Ts representing future single timestep SOC
    currentTs = X(1:p, 1+(xIND.Ts-1)*NUMCELLS : xIND.Ts*NUMCELLS);
%     tempRate = zeros(size(futureTs)); % Initialize temp. rate to zeros
    tempRate = futureTs - currentTs; % Sum each column (i.e. each value in pred horizon)
%}

% %%%%%%%%%%%%%%%%%%%%%%%  Li Plate Rate   %%%%%%%%%%%%%%%%%%%%%%%%%%
    LPRind = curr < 0;
    interpCurr = curr .* (LPRind);
    LiPlateRate = qinterp2(-lprMdl.Curr, lprMdl.SOC, lprMdl.LPR,...
                    interpCurr, X(2:p+1, soc_ind));
%     LiPlateRate = reshape(LiPlateRate, size(curr));

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Objective Function Weights (0, 1, 5, 20 etc))
% ---------------------------------------------------------------------
A = 0.05; %0.85; % SOC Tracking and SOC Deviation
A_dev = 100 * max(abs(socDev(1, :))) + 1;
B = 2; % Chg Time
C = 1; % Temp Rise rate
D = 5; % Li Plate Rate
E = max(0, -100*max(abs(socDev(1, :))) + 1); % Need to make balCurr approach zero when there isn't more than 1% socDev

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% References for each objective
% ---------------------------------------------------------------------
ref = data.References;


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Scaling Factors for each objective
% ---------------------------------------------------------------------
scale_soc = 1;
scale_chrgTime = 1; % (MAX_CELL_CURR * dt)/(3600*cap(1)) .* (cap(1) * 3600)./ abs(MIN_CHRG_CURR);
scale_TR = 3;
scale_LPR = 300;


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Cost Function
% ---------------------------------------------------------------------
J = sum([...
    sum( ( (A/scale_soc) .* (ref(:, 1:NUMCELLS) - chrgSOC) ) .^2),  ... % avgSOC) ) .^2),  ... %
    sum( ( (A_dev/scale_soc) .* (0 - socDev) ) .^2),  ...
    ... % sum( ( (B/scale_chrgTime) .* (0 - chrgTime) ) .^2),  ...
    sum( ( (D/scale_LPR) .* (ref(:, 1*NUMCELLS+1:2*NUMCELLS) - LiPlateRate) ) .^2),  ...
    ... % sum( ( (C./scale_TR) .* (ref(:, 2*NUMCELLS+1:3*NUMCELLS) - tempRate) ) .^2),  ...
    ... % sum( ( (E/1) .* (0 - U(2:p+1,1:NUMCELLS)) ) .^2),  ...
    e.^2, ...
    ], 'all');


end

function [G, Gmv, Ge] = myCostJacobian(X, U, e, data, p1, p2, p3, p4)
% Parameters (p#)
% dt          = p1;   % Algorithm sample time
% predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x)and OUTPUTS (y) presented as a struts

NUMCELLS = cellData.NUMCELLS;
xIND = indices.x;

% numStatesPerCell = length(fields(xIND));
% nx = numStatesPerCell*NUMCELLS; % Number of states
% nmv = NUMCELLS; % Number of inputs. In this case, current for each cell

% Tf = battMdl.Tf;

soc_ind = 1+(xIND.SOC-1)*NUMCELLS : xIND.SOC*NUMCELLS;
% v1_ind = 1+(xIND.V1-1)*NUMCELLS : xIND.V1*NUMCELLS;
% v2_ind = 1+(xIND.V2-1)*NUMCELLS : xIND.V2*NUMCELLS;
% tc_ind = 1+(xIND.Tc-1)*NUMCELLS : xIND.Tc*NUMCELLS;
% ts_ind = 1+(xIND.Ts-1)*NUMCELLS : xIND.Ts*NUMCELLS;

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
    for j = soc_ind % Only calculating wrt soc here since it is the only one used in the cost func % 1:nx
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
% dt = p1;            % Data sample time
battMdl = p2;       % Battery Model Class Object
% cap = battMdl.Cap'; % Capacity of all cells
NUMCELLS = p3;      % Number of cells
% MIN_CHRG_CURR = p4;  % Minimum current that prevents INF when calculating charge time
xIND = p5;          % Indices for the STATES (x) presented as a strut
% contMdl = p6;          % Indices for the OUTPUTS (y) presented as a strut


% numStatesPerCell = length(fields(xIND));
% nx = numStatesPerCell*NUMCELLS; % Number of states
% nmv = NUMCELLS; % Number of inputs. In this case, current for each cell

p = data.PredictionHorizon;

global MAX_CELL_VOLT

% % Old method
% Y = myOutputFcn(X(2,:)',U(2,:)',p1, p2, p3, p4)';
% cineq = (Y(1+(yIND.volt-1)*NUMCELLS:NUMCELLS*yIND.volt) - MAX_CELL_VOLT)';

horizonInd = 1:p+1; %+1; % 2:p+1

% New method - Calculating voltage directly here
soc = X(horizonInd, 1 + (xIND.SOC-1) * NUMCELLS : xIND.SOC * NUMCELLS);
V1 = X(horizonInd,  1 + (xIND.V1-1) * NUMCELLS : xIND.V1 * NUMCELLS);
V2 = X(horizonInd,  1 + (xIND.V2-1) * NUMCELLS : xIND.V2 * NUMCELLS);
Tc = X(horizonInd,  1 + (xIND.Tc-1) * NUMCELLS : xIND.Tc * NUMCELLS);
Ts = X(horizonInd,  1 + (xIND.Ts-1) * NUMCELLS : xIND.Ts * NUMCELLS);
T_avg = (Tc + Ts)/2;

% Current for the model is negative compared to current used in the MPC
curr = -(U(horizonInd,1:NUMCELLS) + U(horizonInd, end)); % Equivalent to balCurr + PsuCurr
    
% OCV = updateOCV(battMdl, soc(:)); %(:));
% OCV = reshape(OCV, size(soc));
% rs = updateRs(battMdl, curr(:), soc(:), T_avg(:));
% rs = reshape(rs, size(soc));

Z = lookupRS_OCV(battMdl.Lookup_tbl, soc(:), T_avg(:), curr(:)); 
OCV = reshape(Z.OCV, size(soc));
rs = reshape(Z.Rs, size(soc));
Vt = OCV - V1 - V2 -(curr .* rs); % "(:)" forces vector to column vector
cineq = (Vt - MAX_CELL_VOLT);
cineq = cineq(:);

end


function newDiagMat = replaceDiag(oldDiagMat, vector, indRangeV, offset)
%REPLACEDIAG Replaces the elements in the diag of a matrix
%
%oldDiagMat     The old square matrix to be modified
%vector         The vector with values to replace
%indRangeV      A vector containing the indices of the old matrix to
%               replace
%offset         The offset of the old square matrix to replace. A negative
%               value is below the main diagonal, while positive it above

if length(vector) ~= length(indRangeV)
    error("The index range vector must have the same length as the vector" + ...
        " to be inserted. The index range vector must contain the indices for each element of the vector");
end
vector = vector(:);

ind = ismember(1:length(diag(oldDiagMat, offset)), indRangeV);
ind = ind(:);

newDiag = double(ind); x = 1;
for i = indRangeV
    newDiag(i) = vector(x);
    x = x+1;
end

newDiagMat = (oldDiagMat .* ~diag(ind, offset)) + diag(newDiag, offset);

end


function dataQueryTimerFcn()
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
disp("dataQueryTimer has stopped");
disp("dataQueryTimer Instant Period = " + num2str(dataQueryTimer.InstantPeriod) + "s");
disp("dataQueryTimer Average Period = " + num2str(dataQueryTimer.AveragePeriod) + "s");
end