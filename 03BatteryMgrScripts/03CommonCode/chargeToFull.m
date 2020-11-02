% clearvars;
% clc;

%% Setup Code
try
    
% Initializations
script_initializeVariables; % Run Script to initialize common variables
script_initializeDevices; % Initialized devices like Eload, PSU etc.

if strcmpi (cellConfig, 'parallel')
    curr = (sum(batteryParam.ratedCapacity(cellIDs))*cRate); % X of rated Capacity
else
    curr = batteryParam.ratedCapacity(cellIDs(1))*cRate; % X of rated Capacity
end
% plotFigs = true;
trackSOCFS = false;

% testTimer = tic; % Start Timer for read period


%% CC Mode
script_queryData; % Run Script to query data from devices
script_failSafes; %Run FailSafe Checks
if errorCode == 1 || strcmpi(testStatus, "stop")
    script_idle;
    return;
end
script_charge; % Run Script to begin/update charging process

% While the battery voltage is less than the limit (our 100% SOC) (CC mode)
while packVolt <= highVoltLimit   
    %% Measurements
    % Querys all measurements every readPeriod second(s)
    if toc(testTimer) - timerPrev(3) >= readPeriod
        timerPrev(3) = toc(testTimer);

        script_queryData; % Run Script to query data from devices
        script_failSafes; %Run FailSafe Checks
        script_checkGUICmd; % Check to see if there are any commands from GUI
        % if limits are reached, break loop
        if errorCode == 1 || strcmpi(testStatus, "stop")
            script_idle;
            break;
        end
    end
    %% Triggers (GPIO from LabJack)
    script_triggerDigitalPins;

end

%% CV Mode
% battState = ""; % This is here to allow the PSU voltage to be updated in [script_charge]
% chargeVolt = highVoltLimit; % + (circuitImp * (curr - 0.023));
% script_charge; % Run Script to begin/update charging process
% script_queryData; % Run Script to query data from devices

% While the battery voltage is less than the limit (our 100% SOC) (CC mode)
while abs(packCurr) > abs(cvMinCurr)   
    %% Measurements
    % Querys all measurements every readPeriod second(s)
    if toc(testTimer) - timerPrev(3) >= readPeriod
        timerPrev(3) = toc(testTimer);

        script_queryData; % Run Script to query data from devices
        script_failSafes; %Run FailSafe Checks
        script_checkGUICmd; % Check to see if there are any commands from GUI
        % if limits are reached, break loop
        if errorCode == 1 || strcmpi(testStatus, "stop")
            script_idle;
            break;
        end
    end
    %% Triggers (GPIO from LabJack)
    script_triggerDigitalPins;

end

% Save data
if errorCode == 0 && tElasped > 1   
    
    batteryParam.soc(cellIDs) = 1; % 100% Charged
    if ~strcmpi(cellConfig, 'single')
        packParam.soc(packID) = 1;
    end
    
    % Save Battery Parameters
    save(dataLocation + "007BatteryParam.mat", 'batteryParam');
    if ~strcmpi(cellConfig, 'single')
        save(dataLocation + "007PackParam.mat", 'packParam');
    end

   % Get Current File name
    [~, filename, ~] = fileparts(mfilename('fullpath'));
    % Save data
    saveBattData(battTS, metadata, testSettings, cells, filename);
    
end
catch MEX
    script_resetDevices;    
    if caller == "cmdWindow"
       rethrow(MEX);
    else
       send(errorQ, MEX)
    end
end

%% Teardown
script_resetDevices;
