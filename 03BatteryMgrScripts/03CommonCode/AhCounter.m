function battTS = AhCounter(varargin)
%AhCounter Counts the mount of capacity left in a cell or pack
%
%   Inputs: 
%       varargin   
%           cRates          = 1             : CRate of rated capacity to cycle  for. Can be 1 value
%                                               for charge and discharge or a vector of 2 values one 
%                                               for each (Unitless).
%           waitTime        = 0             : Time in seconds to wait between both charge and discharge
%
%			trig1         	= false,  		: Accepts a Command to use the trigger activate something such as a heat pad
%			trig1_pin     	= 4,      		: Specifies what pin on the MCU to use(Initially used on a LABJack U3-HV)
%			trig1_startTime	= [10.0], 		: How long into the parent function to trigger. Can be an array of times (s)
%			trig1_duration	= [2.0],  		: How long should the trigger last
%											
%			cellIDs       	= [],     		: IDs of Cells being tested. If parallel specify all cells in string array
%			caller      	= "cmdWindow", 	: Specifies who the parent caller is. The GUI or MatLab's cmd window. Implementations between both can be different
%			psuArgs       	= [],     		: Connection details of the power supply
%			eloadArgs     	= [],     		: Connection details of the Electronic Load
%			thermoArgs    	= [],     		: Connection details of the Temperature measuring module
%			daqArgs     	= [],     		: Connection details of the Data Acquisition System. (Switches Relays and obtaines measurements)
%			dataQ         	= [],     		: Pollable DataQueue for real-time data transfer between 
%                                               2 parallel-run programs such as the function and GUI
%			errorQ        	= [],     		: Pollable DataQueue for real-time error data (exceptions) 
%                                               transfer between 2 parallel-run programs such as the function and GUI
%			testSettings  	= []);    		: Settings for the test such as cell configuration, sample time, data to capture etc


% clearvars;
clc;

try
    %% Setup Code
    param = struct(...
        'cRates',           1,      ... % Specific to this function
        'waitTime',         0,      ... % -------------------------
                        ...                       
        'trig1',            false,  ... % General to most functions
        'trig1_pin',        4,      ... %           "
        'trig1_startTime',  [10.0], ... %           "
        'trig1_duration',   [2.0],  ... %           "
                        ...             %           "
        'cellIDs',          [],     ... %           "
        'caller',      "cmdWindow", ... %           "
        'psuArgs',          [],     ... %           "
        'eloadArgs',        [],     ... %           "
        'thermoArgs',       [],     ... %           "
        'daqArgs',        [],     ... %           "
        'dataQ',            [],     ... %           "
        'errorQ',           [],     ... %           "
        'testSettings',     []);        % -------------------------
    
    
    % read the acceptable names
    paramNames = fieldnames(param);
    
    % Ensure variable entries are pairs
    nArgs = length(varargin);
    if round(nArgs/2)~=nArgs/2
        error('runProfile needs propertyName/propertyValue pairs')
    end
    
    for pair = reshape(varargin,2,[]) %# pair is {propName;propValue}
        inpName = pair{1}; %# make case insensitive
        
        if any(strcmpi(inpName,paramNames))
            %# overwrite options. If you want you can test for the right class here
            %# Also, if you find out that there is an option you keep getting wrong,
            %# you can use "if strcmp(inpName,'problemOption'),testMore,end"-statements
            param.(inpName) = pair{2};
        else
            error('%s is not a recognized parameter name',inpName)
        end
    end
    
    
    
    % ---------------------------------
    cRates = param.cRates;    
    waitTime = param.waitTime;

    cellIDs = param.cellIDs;
    caller = param.caller;
    psuArgs = param.psuArgs;
    eloadArgs = param.eloadArgs;
    thermoArgs = param.thermoArgs;
    daqArgs = param.daqArgs;
    dataQ = param.dataQ;
    errorQ = param.errorQ;
    testSettings = param.testSettings;
    
    
    % Begin AhCounter
   
    disp("Counting Capacity ...");
    
    if length(cRates) > 1
        cRate = cRates(1); % Use the first cRate for Charging
    else
        cRate = cRates;
    end
    
    if isempty(testSettings)
        testSettings.thermo.numTCs = 0;
        testSettings.cellConfig = 'single';
    end
    
    % Step 1: Charge to Full Capacity
    chargeToFull;
    
    
    % Step 2: Wait
    battTS_Wait = waitTillTime(waitTime, 'cellIDs', cellIDs,...
        'testSettings', testSettings);
    battTS = appendBattTS2TS(battTS, battTS_Wait);
    
    
    % Initializations
    script_initializeDevices; % Initialized devices like Eload, PSU etc.
    
    trackSOCFS = false;
    
    AhCap = 0;
    cells.AhCap(cellIDs) = 0;
    coulombCount = 0;
    
    plotFigs = false;
    
    % Get CRate for discharging
    if length(cRates) > 1
        cRate = cRates(2); % Use the second cRate for Discharging
    else
        cRate = cRates;
    end
    
    % Convert cRate to current
    if strcmpi (cellConfig, 'parallel')
        curr = (sum(batteryParam.ratedCapacity(cellIDs))*cRate); % X of rated Capacity
    else
        curr = batteryParam.ratedCapacity(cellIDs(1))*cRate; % X of rated Capacity
    end    
    
    curr = -abs(curr);
    
    % Step 3: Discharge and count
    coulombTimer = tic;
    script_queryData; % Run Script to query data from devices
    script_discharge; % Run Script to begin/update charging process
    
    % Discharge the battery to 0% to validate it's working capacity
    while battVolt > lowVoltLimit
        coulombTicker = toc(coulombTimer);
        coulombCount = battCurr * coulombTicker; % coulomb Counter

        %% Measurements
        % Querys all measurements every readPeriod second(s)
        if toc(testTimer) - timerPrev(3) >= readPeriod
            timerPrev(3) = toc(testTimer);
            script_queryData; % Run Script to query data from devices
            %             disp("Coulomb Counter: " + num2str(coulombCount) + newline);
            script_failSafes; %Run FailSafe Checks
            % if limits are reached, break loop
            if errorCode == 1
                break;
            end
        end
    end

    % Plot the data if true
    if plotFigs == true
        plotBattData(battTS);
    end
    
    % Save data
    if errorCode == 0 && tElasped > 1
        if numCells > 1
            save(dataLocation + "007_" + cellConfig + "_AhCount.mat", 'battTS', 'cellIDs', 'coulombCount');
        else
            save(dataLocation + "007_" + cellIDs(1) + "_AhCount.mat", 'battTS', 'coulombCount');
        end
        
        batteryParam.soc(cellIDs) = 0; % 0% SOC
        
        if strcmpi(cellConfig, 'parallel')
            batteryParam.capacity(cellIDs) = cells.AhCap(cellIDs);
        else
            batteryParam.capacity(cellIDs) = AhCap;
        end
        
        % Save Battery Parameters
        save(dataLocation + "007BatteryParam.mat", 'batteryParam');
    end
    
catch MEX
    script_resetDevices;
    if caller == "cmdWindow"
        rethrow(MEX);
    else
        send(errorQ, MEX)
    end
end

% Teardown
script_resetDevices;

end