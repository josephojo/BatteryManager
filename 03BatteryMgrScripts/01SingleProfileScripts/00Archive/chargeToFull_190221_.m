clear;clc;

%% Setup Code
% IMPORT PREVIOUS SOC
load("prevSOC");

% Initializations
script_initializeDevices; % Initialized devices like Eload, PSU etc.
script_initializeVariables; % Run Script to initialize common variables
curr = 2.5; %2.5A is 1C for the ANR26650
battCurr = 1; %Reinitialize this to 1 to allow for the while loop to begin

tic; % Start Timer
script_charge; % Run Script to begin/update charging process
d = false;
% v = figure(1);
hold off;
plot(0,0);
hold on;

% While the current of the battery while charging is greater than 3% of its
% rated current (CV mode)
while true
    script_charge; % Run Script to begin/update charging process
    
    %% Measurements
%     script_avgLJMeas; %Run Script to average voltage measurements from Labjack
    
    % Querys all measurements every readPeriod second(s)
    if toc - timerPrev(3) >= readPeriod
        timerPrev(3) = toc;
        script_queryData; % Run Script to query data from devices
        if battCurr <= (0.045 * 2.5) % Using 0.03 causes it to be 0.075, but psu only works in 0.1 increments
            break;
        end
        plot(battTS.Time(end), battTS.Data(end,1),'g.', battTS.Time(end), battTS.Data(end,3),'r.', battTS.Time(end), battTS.Data(end,6), 'b.'); 
        %%
        if battVolt >= highVoltLimit
            prevSOC = 0.8;
            highVoltLimitPassed = true;
        end
        
        if highVoltLimitPassed == true 
            %     chargeVolt = round(battVolt,1);
            error = battVolt - highVoltLimit;
            script_calcPID;
            curr = curr - round(pidVal,1);
            disp("curr: "+ num2str(curr)+ "\tpid: "+ num2str(pidVal));
            if curr <= 0.1
                
                curr = 0.1;
            end
            if curr > 2.5
                disp("Curr is way too high: " + num2str(curr))
                curr = 1;
            end
%             if d == false
%                 chargeVolt = highVoltLimit+0.1;
%                 curr = 2.2;
%                 d=true;
%             end
        else
            chargeVolt = round((curr*0.09) + highVoltLimit,1);
        end
        
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
    prevSOC = 1;
    save('prevSOC.mat', 'prevSOC');
end

%% Teardown
script_resetDevices;