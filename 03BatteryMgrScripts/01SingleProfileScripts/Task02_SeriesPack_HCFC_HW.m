%% Series-Pack Fast Charging
% By Joseph Ojo
%
% The ECM battery model used in this file was adopted from the work by:
%
%
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
    
    %% Constants
    % global NUMCELLS numStatesPerCell numOutputPerCell
    % global nx ny nu TARGET_SOC MIN_CHRG_CURR MAX_BAL_CURR MAX_CELL_CURR MAX_CELL_VOLT MIN_CELL_VOLT
    global MAX_CELL_VOLT MIN_CELL_VOLT
    
    NUMCELLS = length(cellIDs);
    
    % xIND.SOC    = 1;
    % xIND.V1     = 2;
    % xIND.V2     = 3;
    % xIND.Tc     = 4;
    % xIND.Ts     = 5;
    
    xIND.SOC    = 1;
    xIND.Volt   = 2;
    xIND.Ts     = 3;
    
    
    yIND.volt = 1;
    yIND.timeLeft = 2;
    yIND.Tavg = 3;
    yIND.Lpr = 4;
    yIND.socDev = 5;
    
    numStatesPerCell = length(fields(xIND));
    
    
    nx = numStatesPerCell*NUMCELLS; % Number of states
    ny = nx;
    nu = NUMCELLS + 1; % Number of inputs. In this case, current for each cell + PSU current
    
    
    TEST_MDL = false; % Used to decide if the model should be run to completion without MPC for testing
    % TEST_MDL = true; % Used to decide if the model should be run to completion without MPC for testing
    
    TARGET_SOC = 1;
    
    MIN_CHRG_CURR = 0.01; %  min curr for calculating charge time to avoid INF
    
    pause(1); % Wait for the EEprom Data to be updated
    MAX_BAL_CURR = bal.EEPROM_Data(1, 1).Charge_Currents(logical(bal.cellPresent(1, :))) ...
        / DC2100A.MA_PER_A;
    
    MIN_BAL_CURR = -1 * bal.EEPROM_Data(1, 1).Charge_Currents(logical(bal.cellPresent(1, :))) ...
        / DC2100A.MA_PER_A;
    
    MAX_CELL_CURR = 13;
    
    MAX_CELL_VOLT = 4.2;
    MIN_CELL_VOLT = 2.5;
    
    C_bat = batteryParam.capacity(cellIDs);
    
    sampleTime = 1; % 0.5; % Sample time [s]
    
    %% Initializations for models
    % dataLoc = "BatteryModels/00ECTM/";
    
    % Temperature Model
    cc = 62.7; % 67;
    cs = 4.5;
    rc = 1.94; % 3.8468;
    re = 0.024218;
    ru = 15; % 15.987;
    
    % A,B,C,D Matrices  ***
    A_cont = [-1/(rc*cc), 1/(rc*cc) ; 1/(rc*cs), ((-1/cs)*((1/rc) + (1/ru)))];
    B_cont = [(re)/cc 0; 0, 1/(ru*cs)];
    C = [0 0; 0 1]; %eye(2);
    D = [0, 0;0, 0];
    
    tempMdl = struct;
    tempMdl.A = A_cont;
    tempMdl.B = B_cont;
    tempMdl.C = C;
    tempMdl.D = D;
    
    A_Dis = expm(tempMdl.A*sampleTime);
    tempMdl.A = A_Dis;
    tempMdl.B = tempMdl.A\(A_Dis - eye(size(A_Dis,1))) * tempMdl.B;
    
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
    A_cont = [A1; A2];
    B_cont = [1./C1 ; 1./C2];
    
    A_tempo = repmat(A_cont, NUMCELLS, 1) .* eye(NUMCELLS * 2);
    A = expm(A_tempo * sampleTime);
    B = A_tempo\(A - eye(size(A))) * B_cont(:);
    
    voltMdl.A_cont = A_cont;
    voltMdl.B_cont = B_cont;
    voltMdl.A = A;
    voltMdl.B = B;
    voltMdl.OCV = OCV;
    voltMdl.SOC = SOC;
    
    battMdl.temp = tempMdl;
    battMdl.volt = voltMdl;
    battMdl.Tf = 25;
    battMdl.Cap = C_bat;
    
    % Lithium Plating Lookup table (From "LiPlateRate.mat")
    load(dataLocation + 'LiPlateRate.mat'); % Lithium plating rate
    [X, Y] = meshgrid(LiPlateCurr, LiPlateSOC);
    battMdl.LPR.Curr = X;
    battMdl.LPR.SOC = Y;
    battMdl.LPR.LPR = LiPlateRate;
    
    
    % global L
    % L2 = [zeros(NUMCELLS-1, 1), (-1 * eye(NUMCELLS-1))];
    % L1 = eye(NUMCELLS);
    % L1(end, :) = [];
    % L = L1 + L2;
    battMdl.L = L; % Initialized in "script_initializeVariables.m"
    
    script_queryData;
    
    % #############  Initial States  ##############
    battData = struct;
    battData.time           = 0;
    battData.Ts             = thermoData(2:end); % repmat(25   , 1, NUMCELLS); % Surface Temp
    battData.Tf             = thermoData(1); % repmat(25   , 1, NUMCELLS); % Ambient Temp
    battData.volt           = cells.volt(cellIDs);
    battData.curr           = cells.curr(cellIDs); % zeros(1, NUMCELLS);
    battData.LiPlateRate    = zeros(1, NUMCELLS);
    
    % initialSOCs = [0.2, 0.4, 0.3, 0.2];
    initialSOCs = cells.SOC(cellIDs);
    
    if NUMCELLS > 1
        battData.SOC            = initialSOCs(1:NUMCELLS); % repmat(0    , 1, NUMCELLS); % [0 0 0 0]; % [0.2, 0.2, 0.2, 0.2]; %
        battData.Cap            = C_bat; % repmat(C_bat, 1, NUMCELLS); % [2.3, 2.3, 2.3, 2.3]; % [2.2, 2.3, 2.1, 2.3]; %
    else
        battData.SOC            = 0.5; % repmat(0    , 1, NUMCELLS); % [0 0 0 0]; % [0.2, 0.2, 0.2, 0.2]; %
        battData.Cap            = 2.3;
    end
    
    battData.Cost = 0;
    battData.timeLeft = zeros(1, NUMCELLS);
    battData.ExitFlag = 0;
    battData.balCurr = zeros(1, NUMCELLS);
    battData.optCurr = zeros(1, NUMCELLS);
    battData.optPSUCurr = zeros(1, 1);
    
    ind = 1;
    xk = zeros(nx, 1);
    
    xk(ind:ind+NUMCELLS-1, :)   =  battData.SOC(:)         ; ind = ind + NUMCELLS;
    xk(ind:ind+NUMCELLS-1, :)   =  battData.volt(:)        ; ind = ind + NUMCELLS;
    xk(ind:ind+NUMCELLS-1, :)   =  battData.Ts(:)          ; ind = ind + NUMCELLS;
    
    global Tc
    Tc = battData.Ts(:);
    
    prevTime = 0; prevElapsed = 0;
    
    
    %% MPC - Configure Parameters
    mpcObj = nlmpc(nx,ny,nu);
    
    p1 = sampleTime;        % Data sample time
    p2 = battMdl;           % Battery Model Class Object
    p3 = NUMCELLS;          % Number of cells
    p4 = MIN_CHRG_CURR;      % Minimum current that prevents INF when calculating charge time
    p5 = xIND;              % Indices for the STATES (x) presented as a strut
    
    mpcObj.Model.NumberOfParameters = 5; % dt and capacity
    
    PH = 5;  % Prediction horizon
    CH = 2;  % Control horizon
    mpcObj.Ts = sampleTime;
    mpcObj.PredictionHorizon = PH;
    mpcObj.ControlHorizon = CH;
    
    % Constraints
    % Add Manipulated variable constraints
    % Small Rates affect speed a lot
    for i = 1:NUMCELLS
        mpcObj.MV(i).Max =  MAX_BAL_CURR(i);      mpcObj.MV(i).RateMax =  2; % MAX_CELL_CURR;
        mpcObj.MV(i).Min =  MIN_BAL_CURR(i);       mpcObj.MV(i).RateMin = -2; % -6
    end
    
    mpcObj.MV(NUMCELLS + 1).Max =  MAX_CELL_CURR - max(MAX_BAL_CURR);
    mpcObj.MV(NUMCELLS + 1).Min =  0;
    mpcObj.MV(NUMCELLS + 1).RateMax =  2; % MAX_CELL_CURR;
    mpcObj.MV(NUMCELLS + 1).RateMin = -2; % -6
    
    
    % Add dynamic model for nonlinear MPC
    mpcObj.Model.StateFcn = @(x, u, p1, p2, p3, p4, p5)...
        battStates(x, u, p1, p2, p3, p4, p5);
    % mpcObj.Jacobian.StateFcn = @(x,u,p1, p2, p3, p4, p5) ...
    %     myStateJacobian(x, u, p1, p2, p3, p4, p5);
    
    mpcObj.Model.IsContinuousTime = false;
    
    
    mpcObj.Optimization.CustomCostFcn = @(X,U,e,data, p1, p2, p3, p4, p5)...
        myCostFunction(X, U, e, data, p1, p2, p3, p4, p5);
    % mpcObj.Jacobian.CustomCostFcn = @(x,u,e,data, p1, p2, p3, p4, p5) ...
    %     myCostJacobian(x, u,e,data, p1, p2, p3, p4, p5);
    
    mpcObj.Optimization.ReplaceStandardCost = true;
    
    mpcObj.Optimization.CustomIneqConFcn = @(X,U,e,data, p1, p2, p3, p4, p5)...
        myIneqConFunction(X,U,e,data, p1, p2, p3, p4, p5);
    % mpcObj.Jacobian.CustomIneqConFcn = @(x,u,e,data, p1, p2, p3, p4, p5) ...
    %     myIneqConJacobian(x, u,e,data, p1, p2, p3, p4, p5);
    
    mpcObj.Optimization.SolverOptions.UseParallel = true;
    
    mpcObj.Optimization.UseSuboptimalSolution = true;
    
    mpcObj.Optimization.SolverOptions.MaxIterations = 50; % 20; %
    
    
    % SOC tracking, SocDev, temp rise rate, LPR tracking, extra reference
    % cuz refs have to equal number of outputs
    references = [repmat(TARGET_SOC, 1, NUMCELLS),...
        repmat(3, 1, NUMCELLS), repmat(50, 1, NUMCELLS)]; % , zeros(1, NUMCELLS)
    
    u0 = [battData.curr; battData.optPSUCurr];
    % u0 = [-1 -2 2 4 -8];
    % a = [1 -0.5 -1 -1 0];
    % t = tic;
    % for i = 1:5
    %     f=battStates(xk, u0', p1, p2, p3, p4, p5);
    %     u0 = u0 + a;
    % end
    % toc(t)
    
    
    validateFcns(mpcObj, xk, u0, [], {p1, p2, p3, p4, p5}, references);
catch ME
    script_handleException;
end
%% MPC Simulation Loop

close all

timer = tic;

r = rateControl(1/sampleTime);
u = zeros(NUMCELLS + 1,1);
options = nlmpcmoveopt;
options.Parameters = {p1, p2, p3, p4, p5};
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
        
        curr = -u; % -(u2 * 3); % (u2+ min(u-u2)); % y2k1(4));
        cost = mpcinfo.Cost;
        
        % Balancer and PSU Current
        if NUMCELLS > 1
            %{
%             % Extract the PSU Current by minimizing the difference between
%             % the optimal current and the psu current for each cell
%             optPSUCurr = fminbnd(@(X) getPSUCurr(X, curr),-MAX_CELL_CURR, 0);
%             balCurr = (curr - optPSUCurr);
%             % limit balance current greater than allowed max by active
%             % balancer
%             ind1 = (balCurr > 4); ind2 = (balCurr < -4);
%             balCurr = (ind1 .* MAX_BAL_CURR) + (ind2 .* -MAX_BAL_CURR) + balCurr .* (~ind1) .*(~ind2);
%             battData.balCurr = [battData.balCurr; balCurr'];
%             battData.optCurr = [battData.optCurr; curr'];
%             optPSUCurr = repmat(optPSUCurr, 1, NUMCELLS);
            %}
            balCurr = curr(1:NUMCELLS);
            battData.balCurr = [battData.balCurr; balCurr'];
            optPSUCurr = curr(end);
        else
            battData.balCurr = [battData.balCurr; zeros(1, NUMCELLS)];
            %             battData.optCurr = [battData.optCurr; curr];
            %             optPSUCurr = curr;
            
            optPSUCurr = curr(end);
        end
        battData.optPSUCurr  = [battData.optPSUCurr ; optPSUCurr];
        
        tElapsed_MPC = toc(timer);
        
        dt = tElapsed_MPC - prevElapsed;
        
        temp = thermoData(2:end);
        LPR = lookup2D( battMdl.LPR.Curr, battMdl.LPR.SOC, battMdl.LPR.LPR,...
            reshape(cells.curr(cellIDs), [], 1), reshape(cells.SOC(cellIDs), [], 1) );
        
        battData.time           = [battData.time        ; tElapsed_MPC   ]; ind = 1;
        battData.volt           = [battData.volt        ; reshape(cells.volt(cellIDs), 1, [])]; ind = ind + 1;
        battData.curr           = [battData.curr        ; reshape(cells.curr(cellIDs), 1, [])]; ind = ind + 1;
        battData.SOC            = [battData.SOC         ; reshape(cells.SOC(cellIDs), 1, [])]; ind = ind + 1;
        battData.Ts             = [battData.Ts          ; temp(:)']; ind = ind + 1;
        battData.LiPlateRate    = [battData.LiPlateRate ; LPR(:)']; ind = ind + 1;
        battData.Cost           = [battData.Cost ; cost];
        battData.ExitFlag       = [battData.ExitFlag ; mpcinfo.ExitFlag];
        
        % SOC, Volt, Ts
        xk1 = [battData.SOC(end, :), battData.volt(end, :), battData.Ts(end, :)];
        
        xk = xk1';
        xk = xk(:);
        
        % Remaining Charge time
        minCurr = optPSUCurr + battData.balCurr(end, :);
        if max(u <= 0.01) == 1 % if any member of u is 0. u is current of the cells
            minCurr = 0.01; % Make u a small value if it is zero
        end
        timeLeft = ((TARGET_SOC - states(3, :)) .* battMdl.Cap * 3600)./ abs(minCurr);
        battData.timeLeft = [battData.timeLeft ; timeLeft];
        
        
        Tstr = "";
        Tstr = Tstr + sprintf("TC core = %.2f ºC\t\t" ,states(4,1));
        Tstr = Tstr + sprintf("TC surf = %.2f ºC\t\t" ,states(5,1));
        Tstr = Tstr + sprintf("TC Avg = %.2f ºC" ,states(6,1));
        voltStr = "";
        
        MPCStr = ""; LPRStr = ""; currStr = ""; socStr = ""; psuStr = "";  Balstr = "";
        MPCStr = MPCStr + sprintf("ExitFlag = %d\tCost = %e\n", mpcinfo.ExitFlag, cost);
        
        for i = 1:NUMCELLS-1
            voltStr = voltStr + sprintf("Volt %d = %.4f V\t", i, states(1,i));
            LPRStr = LPRStr + sprintf("LPR %d = %.3f A/m^2\t", i, states(7, i));
            Balstr = Balstr + sprintf("BalCur %d = %.4f A\t", i, battData.balCurr(end,i));
            currStr = currStr + sprintf("Curr %d = %.4f\t", i, curr(i));
            socStr = socStr + sprintf("SOC %d = %.4f\t\t", i, battData.SOC(end, i));
        end
        
        for i = i+1:NUMCELLS
            voltStr = voltStr + sprintf("Volt %d = %.4f V\n", i, states(1,i));
            LPRStr = LPRStr + sprintf("LPR %d = %.3f A/m^2\n", i, states(7, i));
            Balstr = Balstr + sprintf("BalCur %d = %.4f A\n", i, battData.balCurr(end,i));
            currStr = currStr + sprintf("Curr %d = %.4f\n", i, curr(i));
            socStr = socStr + sprintf("SOC %d = %.4f\n", i, battData.SOC(end, i));
        end
        psuStr = psuStr + sprintf("PSUCurr = %.4f A", optPSUCurr(1));
        
        disp(newline)
        disp(num2str(tElapsed_MPC,'%.2f') + " seconds");
        disp("STime: " + (tElapsed_MPC - prevElapsed) + " Seconds."); sTime = [sTime; tElapsed_MPC - prevElapsed];
        fprintf(Tstr + newline);
        fprintf(voltStr + newline);
        fprintf(LPRStr + newline);
        fprintf(Balstr + newline);
        fprintf(psuStr + newline);
        fprintf(MPCStr + newline);
        fprintf(currStr + newline);
        fprintf(socStr);
        
        % curr > 0 = Discharging
        ifcurr = curr(1:NUMCELLS) + curr(end);
        if (max(ifcurr > 0 & xk(1+NUMCELLS*(xIND.SOC-1):NUMCELLS*xIND.SOC, :) <= 0.01))...
                || (max(ifcurr < 0 & xk(1+NUMCELLS*(xIND.SOC-1):NUMCELLS*xIND.SOC, :) >= 0.99))
            disp("Completed After: " + tElapsed_MPC + " seconds.")
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

function J = myCostFunction(X, U, e, data, p1, p2, p3, p4, p5)
% Parameters (p#)
% dt = p1;            % Data sample time
battMdl = p2;       % Battery Model Class Object
% cap = battMdl.Cap'; % Capacity of all cells
NUMCELLS = p3;      % Number of cells
% MIN_CHRG_CURR = p4;  % Minimum current that prevents INF when calculating charge time
xIND = p5;          % Indices for the STATES (x) presented as a strut

L = battMdl.L;

% % Variables not currently useful
% numStatesPerCell = length(fields(xIND));
%
%
% nx = numStatesPerCell*NUMCELLS; % Number of states
%
% nmv = NUMCELLS; % Number of inputs. In this case, current for each cell

% global yIND NUMCELLS MIN_CHRG_CURR xIND
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
socDev = L * chrgSOC';

%     avgSOC = mean(chrgSOC, 2);
%     socDev = chrgSOC - avgSOC;


%     % %%%%%%%%%%%%%%%%%%  Charge time calculation  %%%%%%%%%%%%%%%%%%%%%%%%
%     % Chg Time = (Change in SOC between each timestep x capacity) / current
%     futureSOCs = chrgSOC; % SOCs only in the pred horizon
%     currentSOCs = X(1:p, 1+(xIND.SOC-1)*NUMCELLS : xIND.SOC*NUMCELLS); % SOCs in the current time and pred horizon minus furthest SOC
% %     chrgTime = zeros(size(futureSOCs)); % Initialize chag time to zeros
%     futureCurr = curr;
%     idx = futureCurr <= MIN_CHRG_CURR; % Make members of U a small value if it is zero
%     curr = futureCurr .* (~idx) + MIN_CHRG_CURR .*idx;
%     chrgTime = ( (futureSOCs - currentSOCs) .* cap' * 3600 )./ abs(curr); % Sum each column (i.e. each value in pred horizon)


%     % %%%%%%%%%%%%%%%%%%  Temp Rise Rate calculation  %%%%%%%%%%%%%%%%%%%%%
%     % Using Surf Temp since it is what we can measure
%     futureTs = X(2:p+1, 1+(xIND.Ts-1)*NUMCELLS : xIND.Ts*NUMCELLS); % Ts representing future single timestep SOC
%     currentTs = X(1:p, 1+(xIND.Ts-1)*NUMCELLS : xIND.Ts*NUMCELLS);
% %     tempRate = zeros(size(futureTs)); % Initialize temp. rate to zeros
%     tempRate = futureTs - currentTs; % Sum each column (i.e. each value in pred horizon)

% %%%%%%%%%%%%%%%%%%%%%%%  Li Plate Rate   %%%%%%%%%%%%%%%%%%%%%%%%%%
% LiPlateRate = updateLiPlateRate(battMdl, -abs(curr), X(2:p+1, 1+(xIND.SOC-1)*NUMCELLS:xIND.SOC*NUMCELLS));
LiPlateRate = lookup2D(battMdl.LPR.Curr, battMdl.LPR.SOC, battMdl.LPR.LPR, abs(curr), chrgSOC);
LiPlateRate = reshape(LiPlateRate, size(curr));

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Objective Function Weights (0, 1, 5, 20 etc))
% ---------------------------------------------------------------------
A = 0.05; %0.85; % SOC Tracking and SOC Deviation
A_dev = 10 * max(abs(socDev(1, :))) + 1;
B = 2; % Chg Time
C = 1; % Temp Rise rate
D = 5; % Li Plate Rate
E = max(0, -100*max(abs(socDev(1, :))) + 1); % Need to make balCurr approach zero when there isn't more than 1% socDev

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% References for each objective
% ---------------------------------------------------------------------
ref = data.References;
%     maxSOCDev = max(socDev(1, :)) >= 0.01; % If the max SocDev is greater than 1%
%     if maxSOCDev, currRef = 4; else, currRef = 0; end
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
    ... % sum( ( (C./scale_TR) .* (ref(:, 2*NUMCELLS+1:3*NUMCELLS) - tempRate) ) .^2),  ...
    sum( ( (D/scale_LPR) .* (ref(:, 3*NUMCELLS+1:4*NUMCELLS) - LiPlateRate) ) .^2),  ...
    ... % sum( ( (E/1) .* (0 - U(2:p+1,1:NUMCELLS)) ) .^2),  ...
    e.^2, ...
    ], 'all');


end

function [G, Gmv, Ge] = myCostJacobian(X, U, e, data, p1, p2, p3, p4, p5)
% Parameters (p#)
% dt = p1;            % Data sample time
% battMdl = p2;       % Battery Model Class Object
% cap = battMdl.Cap'; % Capacity of all cells
NUMCELLS = p3;      % Number of cells
% MIN_CHRG_CURR = p4;  % Minimum current that prevents INF when calculating charge time
xIND = p5;          % Indices for the STATES (x) presented as a strut
% tempMdl = p6;          % Indices for the OUTPUTS (y) presented as a strut


% numStatesPerCell = length(fields(xIND));
% nx = numStatesPerCell*NUMCELLS; % Number of states
% nmv = NUMCELLS; % Number of inputs. In this case, current for each cell

% Tf = battMdl.Tf;

soc_ind = 1+(xIND.SOC-1)*NUMCELLS : xIND.SOC*NUMCELLS;
% v1_ind = 1+(xIND.V1-1)*NUMCELLS : xIND.V1*NUMCELLS;
% v2_ind = 1+(xIND.V2-1)*NUMCELLS : xIND.V2*NUMCELLS;
% tc_ind = 1+(xIND.Tc-1)*NUMCELLS : xIND.Tc*NUMCELLS;
% ts_ind = 1+(xIND.Ts-1)*NUMCELLS : xIND.Ts*NUMCELLS;

parameters = {p1, p2, p3, p4, p5};
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


function cineq = myIneqConFunction(X, U, e, data, p1, p2, p3, p4, p5)
% Parameters (p#)
% dt = p1;            % Data sample time
battMdl = p2;       % Battery Model Class Object
% cap = battMdl.Cap'; % Capacity of all cells
NUMCELLS = p3;      % Number of cells
% MIN_CHRG_CURR = p4;  % Minimum current that prevents INF when calculating charge time
xIND = p5;          % Indices for the STATES (x) presented as a strut

battMdl.volt = voltMdl;

% numStatesPerCell = length(fields(xIND));
% nx = numStatesPerCell*NUMCELLS; % Number of states
% nmv = NUMCELLS; % Number of inputs. In this case, current for each cell

p = data.PredictionHorizon;

global MAX_CELL_VOLT

horizonInd = 1:p+1; %+1; % 2:p+1

Vt = X(horizonInd,  1 + (xIND.Volt-1) * NUMCELLS : xIND.Volt * NUMCELLS);
cineq = (Vt - MAX_CELL_VOLT);
cineq = cineq(:);

end

function [Geq, Gmv, Ge] = myIneqConJacobian(X, U, e, data, p1, p2, p3, p4, p5)
% Parameters (p#)
% dt = p1;            % Data sample time
% battMdl = p2;       % Battery Model Class Object
% cap = battMdl.Cap'; % Capacity of all cells
NUMCELLS = p3;      % Number of cells
% MIN_CHRG_CURR = p4;  % Minimum current that prevents INF when calculating charge time
xIND = p5;          % Indices for the STATES (x) presented as a strut
% tempMdl = p6;          % Indices for the OUTPUTS (y) presented as a strut


% numStatesPerCell = length(fields(xIND));
% nx = numStatesPerCell*NUMCELLS; % Number of states
% nmv = NUMCELLS; % Number of inputs. In this case, current for each cell

% Tf = battMdl.Tf;

soc_ind = 1+(xIND.SOC-1)*NUMCELLS : xIND.SOC*NUMCELLS;
v1_ind = 1+(xIND.V1-1)*NUMCELLS : xIND.V1*NUMCELLS;
v2_ind = 1+(xIND.V2-1)*NUMCELLS : xIND.V2*NUMCELLS;
tc_ind = 1+(xIND.Tc-1)*NUMCELLS : xIND.Tc*NUMCELLS;
ts_ind = 1+(xIND.Ts-1)*NUMCELLS : xIND.Ts*NUMCELLS;

parameters = {p1, p2, p3, p4, p5};
p = data.PredictionHorizon;

horizonInd = 1:p+1; %+1; % 2:p+1 % Update regularly from "myIneqConFunction"

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

for ix = horizonInd
    % Avoid using ix=1 ("how does the ineq change wrt to the previous state changing")
    % since it doesn't change the ineqs
    if ix==1, continue; end
    % SOC
    dx = dv*xa(soc_ind);
    x0(ix, soc_ind) = x0(ix, soc_ind) + dx;  % Perturb all states
    f = myIneqConFunction(x0, U, e, data, parameters{:});
    x0(ix, soc_ind) = x0(ix, soc_ind) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, soc_ind, ix-1) = dff;
    
    % V1
    dx = dv*xa(v1_ind);
    x0(ix, v1_ind) = x0(ix, v1_ind) + dx;  % Perturb all states
    f = myIneqConFunction(x0, U, e, data, parameters{:});
    x0(ix, v1_ind) = x0(ix, v1_ind) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, v1_ind, ix-1) = dff;
    
    % V2
    dx = dv*xa(v2_ind);
    x0(ix, v2_ind) = x0(ix, v2_ind) + dx;  % Perturb all states
    f = myIneqConFunction(x0, U, e, data, parameters{:});
    x0(ix, v2_ind) = x0(ix, v2_ind) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, v2_ind, ix-1) = dff;
    
    % Tc
    dx = dv*xa(tc_ind);
    x0(ix, tc_ind) = x0(ix, tc_ind) + dx;  % Perturb all states
    f = myIneqConFunction(x0, U, e, data, parameters{:});
    x0(ix, tc_ind) = x0(ix, tc_ind) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, tc_ind, ix-1) = dff;
    
    % Ts
    dx = dv*xa(ts_ind);
    x0(ix, ts_ind) = x0(ix, ts_ind) + dx;  % Perturb all states
    f = myIneqConFunction(x0, U, e, data, parameters{:});
    x0(ix, ts_ind) = x0(ix, ts_ind) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, ts_ind, ix-1) = dff;
    
end

%% Get Ju
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

%% Outputs
Geq = permute(Jx, [3,2,1]);
Gmv = permute(Jmv, [3,2,1]);
Ge = Je(:);

end


function xk1 = battStates(x, u, p1, p2, p3, p4, p5)
% Parameters (p#)
dt = p1;            % Data sample time
battMdl = p2;       % Battery Model Class Object
cap = battMdl.Cap(:); % Capacity of all cells
NUMCELLS = p3;      % Number of cells
% MIN_CHRG_CURR = p4;  % Minimum current that prevents INF when calculating charge time
xIND = p5;          % Indices for the STATES (x) presented as a strut

global Tc
% numStatesPerCell = length(fields(xIND));

% nx = numStatesPerCell*NUMCELLS; % Number of states
% nmv = NUMCELLS; % Number of inputs. In this case, current for each cell)

% global NUMCELLS xIND
prevStates = x;
curr = u(1:NUMCELLS, 1) + u(end, 1); % Equivalent to balCurr + PsuCurr

Tf = battMdl.Tf;

prevSOC = prevStates(1+(xIND.SOC-1)*NUMCELLS:NUMCELLS*xIND.SOC, 1);

states.soc = calcSOC_2(-u(end, 1), -u(1:NUMCELLS, 1), prevSOC, dt, cap);

states.temp = calcTemp(curr,[Tc,...
    prevStates(1+(xIND.Ts-1) *NUMCELLS:xIND.Ts *NUMCELLS, 1)]', dt, Tf, battMdl.temp);

% [states.V1, states.V2] = getRC_Volt(battMdl, dt, -curr', states.soc, mean(states.temp)', ...
%     prevStates(1+(xIND.V1-1)*NUMCELLS:NUMCELLS*xIND.V1, 1), ...
%     prevStates(1+(xIND.V2-1)*NUMCELLS:NUMCELLS*xIND.V2, 1)); % Current should be a negative row vector for each cell using this voltage model

x = [prevStates(1+(xIND.V1-1)*NUMCELLS:NUMCELLS*xIND.V1, 1); ...
    prevStates(1+(xIND.V2-1)*NUMCELLS:NUMCELLS*xIND.V2, 1)];

x = x(:);
u = -curr(:);
Vrc = battMdl.volt.A*x + battMdl.volt.B.*u;
Vrc = reshape(Vrc, 2, []);
Vrc1 = Vrc(1, :); % Voltage drop across in RC pair 1
Vrc2 = Vrc(2, :); % Voltage drop across in RC pair 2


% Z = lookupRS_OCV(battMdl.Lookup_tbl, soc(:), T_avg(:), curr(:));
OCV = interp1qr(battMdl.volt.SOC, battMdl.volt.OCV, states.soc(:));
OCV = reshape(OCV, size(states.soc));

rs = battMdl.volt.Rs;
Vt = OCV - Vrc1 - Vrc2 -(u .* rs); % "(:)" forces vector to column vector

xk1 = [states.soc; Vt(:)'; states.temp(2, :)'];

end

function [A, Bmv] = myStateJacobian(x, u, p1, p2, p3, p4, p5)

% Parameters (p#)
% dt = p1;            % Data sample time
% battMdl = p2;       % Battery Model Class Object
% cap = battMdl.Cap'; % Capacity of all cells
NUMCELLS = p3;      % Number of cells
% MIN_CHRG_CURR = p4;  % Minimum current that prevents INF when calculating charge time
xIND = p5;          % Indices for the STATES (x) presented as a strut
tempMdl = p6;          % Indices for the OUTPUTS (y) presented as a strut


numStatesPerCell = length(fields(xIND));

nx = numStatesPerCell*NUMCELLS; % Number of states
nmv = length(u); % Number of inputs. In this case, current for each cell

% Tf = battMdl.Tf;

soc_ind = 1+(xIND.SOC-1)*NUMCELLS : xIND.SOC*NUMCELLS;
v1_ind = 1+(xIND.V1-1)*NUMCELLS : xIND.V1*NUMCELLS;
v2_ind = 1+(xIND.V2-1)*NUMCELLS : xIND.V2*NUMCELLS;
tc_ind = 1+(xIND.Tc-1)*NUMCELLS : xIND.Tc*NUMCELLS;
ts_ind = 1+(xIND.Ts-1)*NUMCELLS : xIND.Ts*NUMCELLS;

parameters = {p1, p2, p3, p4, p5};

x0 = x;
u0 = u;
uc = u(1:NUMCELLS) + u(end); % uc combined inputs (balCurr + PsuCurr)

f0 = battStates(x0, u0, parameters{:});

%% Get sizes
Jx = zeros(nx, nx);
Jmv = zeros(nx, nmv);
% Perturb each variable by a fraction (dv) of its current absolute value.
dv = 1e-6;
%% Get Jx - How do the states change when each state is changed?

xa = abs(x0);
xa(xa < 1) = 1;  % Prevents perturbation from approaching eps.
x0_Tavg = mean([x0(tc_ind), x0(ts_ind)], 2)';

% SOC - How does changing the SOC change the states (SOC, V1, and V2. Tc or
% Ts don't change)

% Jx(soc_ind, soc_ind) = eye(NUMCELLS); % Jacobian for the SOCs since they don't change when perturbed
% dx = dv*xa(soc_ind); % V1 and V2 changes wrt change in SOC
% x0(soc_ind) = x0(soc_ind) + dx;  % Perturb only SOC
% [v1, v2] = getRC_Volt(battMdl, dt, -abs(uc), x0(soc_ind)', x0_Tavg, x0(v1_ind)', x0(v2_ind)');
% x0(soc_ind) = x0(soc_ind) - dx; % Undo pertubation
% f = [v1(:); v2(:)];
% df = (f - f0([v1_ind, v2_ind]))./ [dx; dx]; % divide V1 and V2 by dx respectively
% df = reshape(df, 2, []);
% Jx(v1_ind, soc_ind) = diag(df(1, :));
% Jx(v2_ind, soc_ind) = diag(df(2, :));

dx = dv*xa(soc_ind);
x0(soc_ind) = x0(soc_ind) + dx;  % Perturb all states
f = battStates(x0, u0, parameters{:});
x0(soc_ind) = x0(soc_ind) - dx;  % Undo pertubation
df = (f - f0)./ repmat(dx, numStatesPerCell, 1);
Jx(soc_ind, soc_ind) = diag(df(soc_ind, 1));
Jx(v1_ind, soc_ind) = diag(df(v1_ind, 1));
Jx(v2_ind, soc_ind) = diag(df(v2_ind, 1));
Jx(tc_ind, soc_ind) = diag(df(tc_ind, 1));
Jx(ts_ind, soc_ind) = diag(df(ts_ind, 1));



% RC Voltages - V1 and V2.
%   (Because V1 and V2 don't change wrt each other,
%    their jacobians can be computed in one go.)

% dx = dv*xa([v1_ind, v2_ind]);
% x0([v1_ind, v2_ind]) = x0([v1_ind, v2_ind]) + dx; % Perturb only V1 and V2
% [v1, v2] = getRC_Volt(battMdl, dt, -abs(uc), x0(soc_ind)', x0_Tavg, x0(v1_ind)', x0(v2_ind)');
% x0([v1_ind, v2_ind]) = x0([v1_ind, v2_ind]) - dx; % Undo pertubation
%
% f = [v1(:); v2(:)];
% df = (f - f0([v1_ind, v2_ind]))./dx;
% Jx = replaceDiag(Jx, df, [v1_ind, v2_ind], 0);

% V1
dx = dv*xa(v1_ind);
x0(v1_ind) = x0(v1_ind) + dx;  % Perturb all states
f = battStates(x0, u0, parameters{:});
x0(v1_ind) = x0(v1_ind) - dx;  % Undo pertubation
df = (f - f0)./ repmat(dx, numStatesPerCell, 1);
Jx(soc_ind, v1_ind) = diag(df(soc_ind, 1));
Jx(v1_ind, v1_ind) = diag(df(v1_ind, 1));
Jx(v2_ind, v1_ind) = diag(df(v2_ind, 1));
Jx(tc_ind, v1_ind) = diag(df(tc_ind, 1));
Jx(ts_ind, v1_ind) = diag(df(ts_ind, 1));

% V2
dx = dv*xa(v2_ind);
x0(v2_ind) = x0(v2_ind) + dx;  % Perturb all states
f = battStates(x0, u0, parameters{:});
x0(v2_ind) = x0(v2_ind) - dx;  % Undo pertubation
df = (f - f0)./ repmat(dx, numStatesPerCell, 1);
Jx(soc_ind, v2_ind) = diag(df(soc_ind, 1));
Jx(v1_ind, v2_ind) = diag(df(v1_ind, 1));
Jx(v2_ind, v2_ind) = diag(df(v2_ind, 1));
Jx(tc_ind, v2_ind) = diag(df(tc_ind, 1));
Jx(ts_ind, v2_ind) = diag(df(ts_ind, 1));


% Tc and Ts Temperatures.
% How does V1, V2, Tc and Ts change wrt Tc and Ts respectively? soc does
% not change wrt Tc or Ts (at least not in this algorithm)

%{
dx_tc = dv*xa(tc_ind);
x0(tc_ind) = x0(tc_ind) + dx_tc; % Perturb only V1 and V2
f_tc = calcTemp (uc, [x0(tc_ind)'; x0(ts_ind)'], dt, Tf);
x0_Tavg = mean([x0(tc_ind), x0(ts_ind)], 2)';
[v1, v2] = getRC_Volt(battMdl, dt, -abs(uc), x0(soc_ind)', x0_Tavg, x0(v1_ind)', x0(v2_ind)');
f_tc = [v1(:); v2(:); f_tc(1, :)'; f_tc(2, :)'];
x0(tc_ind) = x0(tc_ind) - dx_tc; % Undo pertubation

dx_ts = dv*xa(ts_ind);
x0(ts_ind) = x0(ts_ind) + dx_ts; % Perturb only V1 and V2
f_ts = calcTemp (uc, [x0(tc_ind)'; x0(ts_ind)'], dt, Tf);
x0_Tavg = mean([x0(tc_ind), x0(ts_ind)], 2)';
[v1, v2] = getRC_Volt(battMdl, dt, -abs(uc), x0(soc_ind)', x0_Tavg, x0(v1_ind)', x0(v2_ind)');
f_ts = [v1(:); v2(:); f_ts(1, :)'; f_ts(2, :)'];
x0(ts_ind) = x0(ts_ind) - dx_ts; % Undo pertubation

ix = [v1_ind, v2_ind, tc_ind, ts_ind];

df_tc = (f_tc - f0(ix)) ./ repmat(dx_tc(:), numStatesPerCell-1, 1); % (f-f0)./dx
df_ts = (f_ts - f0(ix)) ./ repmat(dx_ts(:), numStatesPerCell-1, 1); % (f-f0)./dx

soc_change = zeros(size(soc_ind'));
df_tc = [soc_change; df_tc];
df_ts = [soc_change; df_ts];

df_tc = [diag(df_tc(soc_ind)); diag(df_tc(v1_ind)); diag(df_tc(v2_ind));...
            diag(df_tc(tc_ind)); diag(df_tc(ts_ind))];
df_ts = [diag(df_ts(soc_ind)); diag(df_ts(v1_ind)); diag(df_ts(v2_ind));...
            diag(df_ts(tc_ind)); diag(df_ts(ts_ind))];

Jx(: , tc_ind) = df_tc;
Jx(: , ts_ind) = df_ts;
%}
% TC
dx = dv*xa(tc_ind);
x0(tc_ind) = x0(tc_ind) + dx;  % Perturb all states
f = battStates(x0, u0, parameters{:});
x0(tc_ind) = x0(tc_ind) - dx;  % Undo pertubation
df = (f - f0)./ repmat(dx, numStatesPerCell, 1);
Jx(soc_ind, tc_ind) = diag(df(soc_ind, 1));
Jx(v1_ind, tc_ind) = diag(df(v1_ind, 1));
Jx(v2_ind, tc_ind) = diag(df(v2_ind, 1));
Jx(tc_ind, tc_ind) = diag(df(tc_ind, 1));
Jx(ts_ind, tc_ind) = diag(df(ts_ind, 1));

% TS
dx = dv*xa(ts_ind);
x0(ts_ind) = x0(ts_ind) + dx;  % Perturb all states
f = battStates(x0, u0, parameters{:});
x0(ts_ind) = x0(ts_ind) - dx;  % Undo pertubation
df = (f - f0)./ repmat(dx, numStatesPerCell, 1);
Jx(soc_ind, ts_ind) = diag(df(soc_ind, 1));
Jx(v1_ind, ts_ind) = diag(df(v1_ind, 1));
Jx(v2_ind, ts_ind) = diag(df(v2_ind, 1));
Jx(tc_ind, ts_ind) = diag(df(tc_ind, 1));
Jx(ts_ind, ts_ind) = diag(df(ts_ind, 1));


%% Get Jmv - How do the states change when each manipulated variable is changed?
%{
ua = abs(u0); % (1:NUMCELLS)
ua(ua < 1) = 1;
du = dv*ua(1:NUMCELLS);
u0(1:NUMCELLS) = u0(1:NUMCELLS) + du;
f = battStates(x0, u0, parameters{:});
u0(1:NUMCELLS) = u0(1:NUMCELLS) - du;
df = (f - f0) ./ repmat(du, numStatesPerCell, 1);

du = dv*ua(end);
u0(end) = u0(end) + du;
f = battStates(x0, u0, parameters{:});
u0(end) = u0(end) - du;
df2 = (f - f0) ./ du;


Jmv(soc_ind, 1:NUMCELLS) = diag(df(soc_ind));
Jmv(v1_ind, 1:NUMCELLS) = diag(df(v1_ind));
Jmv(v2_ind, 1:NUMCELLS) = diag(df(v2_ind));
Jmv(tc_ind, 1:NUMCELLS) = diag(df(tc_ind));
Jmv(ts_ind, 1:NUMCELLS) = diag(df(ts_ind));

Jmv = [Jmv, df2];
%}

ua = abs(u0);
ua(ua < 1) = 1;
for j = 1:nmv
    k = j; % imv(j);
    du = dv*ua(k);
    u0(k) = u0(k) + du;
    f = battStates(x0, u0, parameters{:});
    u0(k) = u0(k) - du;
    df = (f - f0)/du;
    Jmv(:,j) = df;
end

A = Jx;
Bmv = Jmv;
end

function temp = calcTemp (curr, prevTemp, dt, Tf, tempMdl)
% global tempMdl
% A = expm(tempMdl.A*dt);
% B = tempMdl.A\(A - eye(size(A,1))) * tempMdl.B;
% temp = A*prevTemp + B* [(curr.^2)'; Tf];

temp = tempMdl.A*prevTemp + tempMdl.B* [(curr.^2)'; repmat(Tf, 1, length(curr))];
end


function soc = calcSOC_2(psuCurr, balCurr, prevSOC, dt, cap)
numCells = length(balCurr);
% Change in SOC as a result of balancing %%%%%%%%%%%%%%%%%%%%
Qx = diag(cap .* 3600); % Maximum Capacities
T = repmat(1/numCells, numCells) - eye(numCells); % Component for individual Active Balance Cell SOC [2]
B2 = (Qx\T); % (T*Qu);

soc_bal_chg = (B2 * (balCurr * dt));
% ====================

% Change in SOC as a result of series pack charging/discharging
soc_series_chg = ((psuCurr * dt) .* -1 ./(3600*cap));

% Total SOC for current step
soc = prevSOC + (soc_bal_chg + soc_series_chg);
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
