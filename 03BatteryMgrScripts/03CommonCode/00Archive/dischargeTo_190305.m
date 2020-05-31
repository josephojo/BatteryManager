function dischargeTo(soc, dischargeCurr)
%dischargeTo Discharges to the specified SOC based on the previous SOC

% clear;clc;
% wait(0.5);

%% Setup Code

% Initializations
try
script_initializeDevices; % Initialized devices like Eload, PSU etc.
catch
    script_resetDevices;    
    error("Initialization Error");
end
script_initializeVariables; % Run Script to initialize common variables
curr = -abs(dischargeCurr); %2.5A is 1C for the ANR26650
tic; % Start Timer
script_discharge; % Run Script to begin/update discharging process

% While SOC is greater than specified
while battSOC > soc   
    %% Measurements
%     script_avgLJMeas; %Run Script to average voltage measurements from Labjack
    
    % Querys all measurements every readPeriod second(s)
    if toc - timerPrev(3) >= readPeriod
        timerPrev(3) = toc;
        script_avgLJMeas
        script_queryData; % Run Script to query data from devices
        
        %% Fail Safes
        script_failSafes; %Run FailSafe Checks
        % if limits are reached, break loop
        if errorCode == 1
            break;
        end
    end
end

if errorCode == 0
    save(dataLocation + "006DischargeTo" +num2str(soc*100,'%.0f')+ "%.mat", 'battTS', '-v7.3');
end

%% Teardown
script_resetDevices;
end