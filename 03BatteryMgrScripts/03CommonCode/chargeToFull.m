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

% Plot the data if true
if plotFigs == true
    currVals = ones(1, length(battTS.Time)) * curr;
    plot(battTS.Time, battTS.Data(:,1),battTS.Time, battTS.Data(:,2),...
        battTS.Time, battTS.Data(:,3), battTS.Time, battTS.Data(:,4),...
        'LineWidth', 3);
    hold on;
    plot(battTS.Time, currVals);
    legend('packVolt','packCurr', 'SOC', 'Ah', 'profile');
end

% Save data
if errorCode == 0 && tElasped > 1   
    
    batteryParam.soc(cellIDs) = 1; % 100% Charged
    % Save Battery Parameters
    save(dataLocation + "007BatteryParam.mat", 'batteryParam');
    
    if numCells > 1
        save(dataLocation + "005_" + cellConfig + "_ChargeToFull.mat", 'battTS', 'cellIDs');
    else
        save(dataLocation + "005_" + cellIDs(1) + "_ChargeToFull.mat", 'battTS');
    end

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
