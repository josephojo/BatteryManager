clear;clc;

%% Setup Code

% Initializations
script_initializeDevices; % Initialized devices like Eload, PSU etc.
script_initializeVariables; % Run Script to initialize common variables
curr = -2.5; %2.5A is 1C for the ANR26650
battVolt = 4;
tic; % Start Timer
script_discharge; % Run Script to begin/update discharging process

% While SOC is greater than 5%
while battVolt > 3.3%battSOC > 0.05   
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

%% Teardown
script_resetDevices;