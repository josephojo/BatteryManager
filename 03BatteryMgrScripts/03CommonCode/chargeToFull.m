% clearvars;
% clc;

%% Setup Code
try
    
% Initializations
script_initializeVariables; % Run Script to initialize common variables
script_initializeDevices; % Initialized devices like Eload, PSU etc.

curr = batteryParam.ratedCapacity(battID)*cRate; % X of rated Capacity

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
while testData.packVolt(end, :) <= highVoltLimit   
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
while abs(testData.packCurr(end, :)) > abs(cvMinCurr)   
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
    
    batteryParam.soc(battID) = 1; % 100% Charged
    
    % Save Battery Parameters
    save(dataLocation + "007BatteryParam.mat", 'batteryParam');

   % Get Current File name
    [~, filename, ~] = fileparts(mfilename('fullpath'));
    % Save data
    saveBattData(testData, metadata, testSettings, filename);
    
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
