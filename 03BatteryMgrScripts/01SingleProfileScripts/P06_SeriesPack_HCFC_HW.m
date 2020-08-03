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


xSOC    = 1;
xV1     = 2;
xV2     = 3;
xTc     = 4;
xTs     = 5;

ySOC    = 1;
yVolt   = 2;
yTs     = 3;

xIND.SOC    = 1+(xSOC-1)*NUMCELLS:xSOC*NUMCELLS;
xIND.V1     = 1+(xV1-1)*NUMCELLS:xV1*NUMCELLS;
xIND.V2     = 1+(xV2-1)*NUMCELLS:xV2*NUMCELLS;
xIND.Tc     = 1+(xTc-1)*NUMCELLS:xTc*NUMCELLS;
xIND.Ts     = 1+(xTs-1)*NUMCELLS:xTs*NUMCELLS;

yIND.SOC    = 1+(ySOC-1)*NUMCELLS:ySOC*NUMCELLS;
yIND.Volt   = 1+(yVolt-1)*NUMCELLS:yVolt*NUMCELLS;
yIND.Ts     = 1+(yTs-1)*NUMCELLS:yTs*NUMCELLS;

indices.x = xIND;
indices.y = yIND;


TARGET_SOC = 0.98;
LPR_Target = 50;

% Balance Efficiencies
chrgEff = 0.774;
dischrgEff = 0.651;

Tf = thermoData(1); % Ambient Temp


numStatesPerCell = length(fields(xIND));
numOutputsPerCell = length(fields(yIND));


nx = numStatesPerCell*NUMCELLS; % Number of states
ny = numOutputsPerCell*NUMCELLS; % Number of outputs
nu = NUMCELLS + 1; % Number of inputs. In this case, current for each cell + PSU current

indices.nx = nx;
indices.ny = ny;
indices.nu = nu;

sampleTime = 4; % 0.5; % Sample time [s]
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
battData.Iters = 0;
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
    
    % Transformation matrix to emulate the actual current going through each
    % battery during balancing (charge and discharge). 
    T_chrg = eye(NUMCELLS) - (repmat(1/NUMCELLS, NUMCELLS) / chrgEff); % Current Transformation to convert primary cell currents to net cell currents to each cell during charging
    T_dchrg =  eye(NUMCELLS) - (repmat(1/NUMCELLS, NUMCELLS) * dischrgEff); % Current Transformation to convert primary cell currents to net cell currents to each cell during discharging
    currMdl.T_chrg = T_chrg;
    currMdl.T_dchrg = T_dchrg;
    
    % Lithium Plating Lookup table (From "LiPlateRate.mat")
    load(dataLocation + 'LiPlateRate.mat'); % Lithium plating rate
    [Xmesh, Ymesh] = meshgrid(LiPlateCurr, LiPlateSOC);
    lprMdl.Curr = Xmesh;
    lprMdl.SOC = Ymesh;
    lprMdl.LPR = LiPlateRate;
    
    predMdl.Volt = voltMdl;
    predMdl.Temp = tempMdl;
    predMdl.SOC = socMdl;
    predMdl.Curr = currMdl;
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
        mpcObj.MV(i).Max =  MAX_BAL_CURR;      mpcObj.MV(i).RateMax =  1.0; % MAX_CELL_CURR;
        mpcObj.MV(i).Min =  -MAX_BAL_CURR;     mpcObj.MV(i).RateMin = -1.0; % -2; % -6
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
    mpcObj.Jacobian.StateFcn = @(x,u,p1, p2, p3, p4) ...
        myStateJacobian(x, u, p1, p2, p3, p4);
    
    mpcObj.Model.OutputFcn = @(x,u, p1, p2, p3, p4) ...
        P06_OutputFcn_HW(x, u, p1, p2, p3, p4); % SOC, Volt, Ts
    mpcObj.Jacobian.OutputFcn = @(x,u,p1, p2, p3, p4) ... 
        myOutputJacobian(x, u, p1, p2, p3, p4);
    
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
    references = [repmat(TARGET_SOC, 1, NUMCELLS), repmat(LPR_Target, 1, NUMCELLS),...
         repmat(3, 1, NUMCELLS)];
    
    u0 = [battData.curr, battData.optPSUCurr];
    
    validateFcns(mpcObj, xk, u0, [], {p1, p2, p3, p4}, references);
catch ME
    script_handleException;
end

%% Extended Kalman Filter Configuration
ekf = extendedKalmanFilter(@P06_BattStateFcn_HW, @P06_OutputFcn_HW, xk);
zCov = repmat([0.02, 0.08, 0.01], NUMCELLS, 1); % Measurement Noise covariance (assuming no cross correlation)
ekf.MeasurementNoise = diag(zCov(:));
ekf.ProcessNoise = 0.05;

%% MPC Simulation Loop

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
    reset(r); 
    while max(xk(1+NUMCELLS*(xIND.SOC-1):NUMCELLS*xIND.SOC, :) <= TARGET_SOC)
        % Get Elapsed Time
        tElapsed_MPC = toc(timer);
        
        idealTimeLeft = abs(((TARGET_SOC - xk(xIND.SOC, 1)) .* CAP(:) * 3600)./ abs(MAX_CELL_CURR));
        SOC_Target = xk(xIND.SOC) + (sampleTime./(idealTimeLeft+sampleTime)).*(TARGET_SOC - xk(xIND.SOC, 1));
        references = [SOC_Target(:)', repmat(LPR_Target, 1, NUMCELLS),...
             repmat(3, 1, NUMCELLS)];

        
        % Run the MPC controller
        [u,~,mpcinfo] = nlmpcmove(mpcObj, xk, u,...
            references,[], options); % (:,idx-1)
        
        optCurr = u; % u<0 == Charging, u>0 == discharging
        cost = mpcinfo.Cost;
        iters = mpcinfo.Iterations;
        
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
                
        
        tempStr = ""; voltStr = ""; currStr = ""; socStr = ""; psuStr = "";  balStr = "";
        MPCStr = ""; LPRStr = "";
        MPCStr = MPCStr + sprintf("ExitFlag = %d\tCost = %e\n", mpcinfo.ExitFlag, cost);
        
        for i = 1:NUMCELLS-1
            tempStr = tempStr + sprintf("Ts%d = %.2f ºC\t\t" , i, states(5,i));
            voltStr = voltStr + sprintf("Volt %d = %.4f V\t", i, states(1,i));
            LPRStr = LPRStr + sprintf("LPR %d = %.3f A/m^2\t", i, states(7, i));
            balStr = balStr + sprintf("Bal %d = %.4f A\t", i, battData.balCurr(end,i));
            currStr = currStr + sprintf("Curr %d = %.4f\t", i, battData.curr(end,i));
            socStr = socStr + sprintf("SOC %d = %.4f\t\t", i, battData.SOC(end, i));
        end
        
        for i = i+1:NUMCELLS
            tempStr = tempStr + sprintf("Ts %d = %.2f ºC\n" , i, states(5,i));
            voltStr = voltStr + sprintf("Volt %d = %.4f V\n", i, states(1,i));
            LPRStr = LPRStr + sprintf("LPR %d = %.3f A/m^2\n", i, states(7, i));
            balStr = balStr + sprintf("Bal %d = %.4f A\n", i, battData.balCurr(end,i));
            currStr = currStr + sprintf("Curr %d = %.4f\n", i, battData.curr(end,i));
            socStr = socStr + sprintf("SOC %d = %.4f\n", i, battData.SOC(end, i));
        end
        psuStr = psuStr + sprintf("PSUCurr = %.4f A", optPSUCurr(1));
        
        disp(newline)
        disp(num2str(tElapsed_MPC,'%.2f') + " seconds");
        sTime = [sTime; tElapsed_MPC - prevElapsed];
        disp("STime: " + sTime(end, 1) + " Seconds."); 
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
            disp("Test Overcharged after: " + tElapsed_MPC + " seconds.")
            break;
        elseif endFlag == true
            disp("An error or Stop test request has occured." + newline...
                + "Test Stopped After: " + tElapsed_MPC + " seconds.")
            break;
        end
        
        prevElapsed = tElapsed_MPC;
        waitfor(r);
    end
    disp("Test Completed After: " + tElapsed_MPC + " seconds.")

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

devMat = predMdl.SOC.devMat;

lprMdl = predMdl.LPR;

p = data.PredictionHorizon;
%     for i=1:p+1
%         Y(i,:) = P06_OutputFcn(X(i,:)',U(i,:)',p1, p2)';
%     end

balCurr = U(2:p+1,1:NUMCELLS);
psuCurr =  U(2:p+1, end);

% curr = psuCurr + balCurr;

% % Compute Actual Current Through cells
logicalInd = balCurr' >= 0;
balActual_dchrg = predMdl.Curr.T_dchrg * (balCurr' .* (logicalInd));
balActual_chrg = predMdl.Curr.T_chrg * (balCurr' .* (~logicalInd));
balActual = balActual_chrg + balActual_dchrg;
curr = psuCurr + balActual'; % Actual Current in each cell


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get the Objective vectors in pred horizon (2:p+1)
% ( SOC, SOCdev, Chg Time, Temp. Rate, Li Plate Rate)
% --------------------------------------------------------------------------------

% %%%%%%%%%%%%%%%%%%%%%%%%%%%  Charge SOC  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
chrgSOC = X(2:p+1, xIND.SOC);


% %%%%%%%%%%%%%%%%%%%%%%%%%%%  SOC Deviation  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
socDev = devMat * chrgSOC';


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

% %%%%%%%%%%%%%%%%%%%%%%%  Li Plate Rate   %%%%%%%%%%%%%%%%%%%%%%%%%%
    LPRind = curr < 0;
    interpCurr = curr .* (LPRind);
    LiPlateRate = qinterp2(-lprMdl.Curr, lprMdl.SOC, lprMdl.LPR,...
                    interpCurr, X(2:p+1, xIND.SOC));
%     LiPlateRate = reshape(LiPlateRate, size(curr));

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Objective Function Weights (0, 1, 5, 20 etc))
% ---------------------------------------------------------------------
A = 5; % 0.05; %0.85; % SOC Tracking and SOC Deviation
A_dev = 10; %100 * max(abs(socDev(1, :))) + 1;
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
% predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x)and OUTPUTS (y) presented as a struts

% NUMCELLS = cellData.NUMCELLS;
xIND = indices.x;

p = data.PredictionHorizon;

MAX_CELL_VOLT = cellData.MAX_CELL_VOLT;

% % Old method
% yIND = indices.y;
% Y = P06_OutputFcn(X(2,:)',U(2,:)',p1, p2, p3, p4)';
% cineq = (Y(yIND.Volt) - MAX_CELL_VOLT)';

horizonInd = 1:p+1; %+1; % 2:p+1

% New method - Calculating voltage directly here
soc = X(horizonInd, xIND.SOC);
V1 = X(horizonInd,  xIND.V1);
V2 = X(horizonInd,  xIND.V2);
Tc = X(horizonInd,  xIND.Tc);
Ts = X(horizonInd,  xIND.Ts);
T_avg = (Tc + Ts)/2;

% Compute Actual Current Through cells
balCurr = U(2:p+1,1:NUMCELLS);
psuCurr =  U(2:p+1, end);
logicalInd = balCurr' >= 0;
balActual_dchrg = predMdl.Curr.T_dchrg * (balCurr' .* (logicalInd));
balActual_chrg = predMdl.Curr.T_chrg * (balCurr' .* (~logicalInd));
balActual = balActual_chrg + balActual_dchrg;
curr = psuCurr + balActual'; % Actual Current in each cell

% curr = psuCurr + balCurr;

Z = lookupRS_OCV(battMdl.Lookup_tbl, soc(:), T_avg(:), curr(:)); 
OCV = reshape(Z.OCV, size(soc));
rs = reshape(Z.Rs, size(soc));
Vt = OCV - V1 - V2 -(curr .* rs); % "(:)" forces vector to column vector
cineq = (Vt - MAX_CELL_VOLT);
cineq = cineq(:);

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

f0 = P06_BattStateFcn(x0, u0, parameters{:});

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

%{
x0_Tavg = mean([x0(xIND.Tc), x0(xIND.Ts)], 2)';
Jx(xIND.SOC, xIND.SOC) = eye(NUMCELLS); % Jacobian for the SOCs since they don't change when perturbed
dx = dv*xa(xIND.SOC); % V1 and V2 changes wrt change in SOC
x0(xIND.SOC) = x0(xIND.SOC) + dx;  % Perturb only SOC
[v1, v2] = getRC_Volt(battMdl, dt, -abs(uc), x0(xIND.SOC)', x0_Tavg, x0(xIND.V1)', x0(xIND.V2)');
x0(xIND.SOC) = x0(xIND.SOC) - dx; % Undo pertubation
f = [v1(:); v2(:)];
df = (f - f0([xIND.V1, xIND.V2]))./ [dx; dx]; % divide V1 and V2 by dx respectively
df = reshape(df, 2, []);
Jx(xIND.V1, xIND.SOC) = diag(df(1, :));
Jx(xIND.V2, xIND.SOC) = diag(df(2, :));
%}

Jx(xIND.SOC, xIND.SOC) = eye(NUMCELLS); % Jacobian for the SOCs since they don't change when perturbed

% dx = dv*xa(xIND.SOC);
% x0(xIND.SOC) = x0(xIND.SOC) + dx;  % Perturb all states
% f = P06_BattStateFcn(x0, u0, parameters{:});
% x0(xIND.SOC) = x0(xIND.SOC) - dx;  % Undo pertubation
% df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
% Jx(xIND.SOC, xIND.SOC) = diag(df(xIND.SOC, 1));
% Jx(xIND.V1, xIND.SOC) = diag(df(xIND.V1, 1));
% Jx(xIND.V2, xIND.SOC) = diag(df(xIND.V2, 1));
% Jx(xIND.Tc, xIND.SOC) = diag(df(xIND.Tc, 1));
% Jx(xIND.Ts, xIND.SOC) = diag(df(xIND.Ts, 1));



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
f = P06_BattStateFcn(x0, u0, parameters{:});
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
f = P06_BattStateFcn(x0, u0, parameters{:});
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
% f = P06_BattStateFcn(x0, u0, parameters{:});
% x0(xIND.Tc) = x0(xIND.Tc) - dx;  % Undo pertubation
% df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
% Jx(xIND.SOC, xIND.Tc) = diag(df(xIND.SOC, 1));
% Jx(xIND.V1, xIND.Tc) = diag(df(xIND.V1, 1));
% Jx(xIND.V2, xIND.Tc) = diag(df(xIND.V2, 1));
% Jx(xIND.Tc, xIND.Tc) = diag(df(xIND.Tc, 1));
% Jx(xIND.Ts, xIND.Tc) = diag(df(xIND.Ts, 1));

Jx(xIND.Tc, xIND.Tc) = 0.973900266935093 * eye(NUMCELLS);
Jx(xIND.Ts, xIND.Tc) = 0.352264366085013 * eye(NUMCELLS);

% % TS
% dx = dv*xa(xIND.Ts);
% x0(xIND.Ts) = x0(xIND.Ts) + dx;  % Perturb all states
% f = P06_BattStateFcn(x0, u0, parameters{:});
% x0(xIND.Ts) = x0(xIND.Ts) - dx;  % Undo pertubation
% df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
% Jx(xIND.SOC, xIND.Ts) = diag(df(xIND.SOC, 1));
% Jx(xIND.V1, xIND.Ts) = diag(df(xIND.V1, 1));
% Jx(xIND.V2, xIND.Ts) = diag(df(xIND.V2, 1));
% Jx(xIND.Tc, xIND.Ts) = diag(df(xIND.Tc, 1));
% Jx(xIND.Ts, xIND.Ts) = diag(df(xIND.Ts, 1));

Jx(xIND.Ts, xIND.Tc) = 0.025282131510418 * eye(NUMCELLS);
Jx(xIND.Ts, xIND.Ts) = 0.601358507776876 * eye(NUMCELLS);


%% Get Jmv - How do the states change when each manipulated variable is changed?
%{
ua = abs(u0); % (1:NUMCELLS)
ua(ua < 1) = 1;
du = dv*ua(1:NUMCELLS);
u0(1:NUMCELLS) = u0(1:NUMCELLS) + du;
f = P06_BattStateFcn(x0, u0, parameters{:});
u0(1:NUMCELLS) = u0(1:NUMCELLS) - du;
df = (f - f0) ./ repmat(du, (nx/NUMCELLS), 1);

du = dv*ua(end);
u0(end) = u0(end) + du;
f = P06_BattStateFcn(x0, u0, parameters{:});
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
    f = P06_BattStateFcn(x0, u0, parameters{:});
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

C(yIND.SOC, xIND.SOC) = eye(NUMCELLS);
C(yIND.Volt, xIND.V1) = -1* eye(NUMCELLS);
C(yIND.Volt, xIND.V2) = -1* eye(NUMCELLS);
C(yIND.Ts, xIND.Ts) = eye(NUMCELLS);



%{
parameters = {p1, p2, p3, p4};

x0 = x;
u0 = u;

f0 = P06_OutputFcn(x0, u0, parameters{:});

% Perturb each variable by a fraction (dv) of its current absolute value.
dv = 1e-6;
%% Get Jx
xa = abs(x0);
xa(xa < 1) = 1;  % Prevents perturbation from approaching eps.
for j = 1:nx
    dx = dv*xa(j);
    x0(j) = x0(j) + dx;
    f = P06_OutputFcn(x0,u0,parameters{:});
    x0(j) = x0(j) - dx;
    C(:,j) = (f - f0)/dx;
end
%}


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