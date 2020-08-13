% clear;clc;

if isfield(testSettings, 'trigPins') && ~isempty(testSettings.trigPins) 
    if length(testSettings.trigPins) == size(testSettings.trigStartTimes, 1) && ...
            length(testSettings.trigPins) == size(testSettings.trigDurations, 1)
        
        trigPins = testSettings.trigPins;
        trigStartTimes = testSettings.trigStartTimes;
        trigDurations = testSettings.trigDurations;
        trigInvert   = testSettings.trigInvert;
        trigTimeTol = 0.5; % Half a second
        for i = 1:length(trigPins)
            pins2(i) = {repmat(trigPins(i), 1, length(trigStartTimes{i}))};
            inverts2(i) = {repmat(trigInvert(i), 1, length(trigStartTimes{i}))};
        end
        pins = horzcat(pins2{:})';
        inverts = horzcat(inverts2{:})';
        startTimes = horzcat(trigStartTimes{:})';
        durations = horzcat(trigDurations{:})';
        endTimes = startTimes + durations;
        
        triggers = sortrows(table(pins, startTimes, durations, endTimes, inverts), 'startTimes', 'ascend');
        
        trigAvail = true;
        trig_Ind = 1;
        trig_On = false(length(pins) , 1);

    else
        err.code = ErrorCode.BAD_SETTING;
        err.msg = "The number of trigger pins and time inputs do not match." + newline + ...
            " Make sure to enter a start time and duration for each trigger pin.";
        send(errorQ, err);
    end
    
else
    trigAvail = false;
end


%% Setup Code
try
    
% Initializations
script_initializeVariables; % Run Script to initialize common variables
script_initializeDevices; % Initialized devices like Eload, PSU etc.

if strcmpi (cellConfig, 'parallel')
    curr = (sum(batteryParam.ratedCapacity(cellIDs))*cRate_dchrg); % X of rated Capacity
else
    curr = batteryParam.ratedCapacity(cellIDs(1))*cRate_dchrg; % X of rated Capacity
end

trackSOCFS = false;

% testTimer = tic; % Start Timer for read period

script_queryData; % Run Script to query data from devices
script_failSafes; %Run FailSafe Checks
if errorCode == 1 || strcmpi(testStatus, "stop")
    script_idle;
    return;
end
script_discharge; % Run Script to begin/update discharging process


% While SOC is greater than 5%
while packVolt > lowVoltLimit    
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
if tElasped > 5 % errorCode == 0 &&
    if numCells > 1
        save(dataLocation + "006_" + cellConfig + "_DischargeToEmpty.mat", 'battTS', 'cellIDs');
    else
        save(dataLocation + "006_" + cellIDs(1) + "_DischargeToEmpty.mat", 'battTS'); 
    end
    batteryParam.soc(cellID) = 0; % 0% DisCharged
    % Save Battery Parameters
    save(dataLocation + "007BatteryParam.mat", 'batteryParam');
%     disp("dischargeToEmpty Completed. And Data Saved.")
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