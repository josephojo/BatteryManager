clear;clc;

%% Setup Code

% Initializations
script_initializeDevices; % Initialized devices like Eload, PSU etc.
script_initializeVariables; % Run Script to initialize common variables
curr = -5; %2.5A is 1C for the ANR26650
battVolt = 4;
tic; % Start Timer
script_discharge; % Run Script to begin/update discharging process

% While SOC is greater than 5%
while battVolt > lowVoltLimit    
    %% Measurements
    script_avgLJMeas; %Run Script to average voltage measurements from Labjack
    
    % Querys all measurements every readPeriod second(s)
    if toc - timerPrev(3) >= readPeriod
        timerPrev(3) = toc;
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
    %Once battery Voltage reaches 3.6V. Save soc as 80%
    prevSOC = 0;
    save('prevSOC.mat', 'prevSOC');
end
%% Teardown
script_resetDevices;