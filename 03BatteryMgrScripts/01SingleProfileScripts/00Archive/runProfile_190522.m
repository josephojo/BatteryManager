function battTS = runProfile(profileTS, initialSOC, finalSOC, mode)
%RUNPROFILE Summary of this function goes here
%   Detailed explanation goes here

%% Setup Code
% Initializations
try
script_initializeDevices; % Initialized devices like Eload, PSU etc.
catch ME_func
    script_resetDevices;    
    rethrow(ME_func);
end
script_initializeVariables; % Run Script to initialize common variables
writePeriod = 0.4; % Period to resample the input current profile

% Resamples the input profile to the interval given in readPeriod
profileTS = resample(profileTS, profileTS.Time(1):writePeriod:profileTS.Time(length(profileTS.Time)));

% Set default for mode if it isn't specified
if strcmpi(mode, '')
   mode = 'cycle'; 
end
if finalSOC == 0
    finalSOC = 1;
end


%% Script
tic; % Start Timer

% Cycle Mode
if strcmpi(mode, 'cycle')
    counter = 1; %In order for the sampling of data from profile
                    % to be based on the number of samples
    timerPrev(1) = toc;
    
    % While Loop: Runs through the currProfile
    while counter <= length(profileTS.Time)
        %% Commands
        % Evaluates and changes commands based on the timing provided on the
        % profile
        if toc >= profileTS.Time(counter)
            timerPrev(2) = toc;
            % Evaluator
            % If the next current value is positive and the battery is
            % currently charging, discharge the battery or else
            % charge the battery (charging is simulating regen braking
            if (round(profileTS.Data(counter),1) < 0)
                chargeReq = false; % Make next command a discharge command
                curr = profileTS.Data(counter);
%                 disp("curr = " + num2str(curr));
            elseif (round(profileTS.Data(counter),1) > 0)
                chargeReq = true; % Make next command a charge command
                curr = profileTS.Data(counter);
%                 disp("curr = " + num2str(curr));
            else
                chargeReq = 3; % Not charging or discharging
            end
            
            % Charge Command
            if (chargeReq == true)
                script_charge; % Run Script to begin/update charging process
                pause (0.15)
                % Discharge Command
            elseif (chargeReq == false)
                script_discharge; % Run Script to begin/update discharging process
            else
                script_idle; % Run Script
            end
%             disp(battState +" ; " + num2str(toc) + " seconds");
            
            script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
            script_failSafes; %Run FailSafe Checks
            % if limits are reached, break loop
            if errorCode == 1
                break;
            end
            
            if(finalSOC < initialSOC)
                if battSOC <= finalSOC
                    break;
                end
            elseif (finalSOC > initialSOC)
                if battSOC >= finalSOC
                    break;
                end
            else
                warning('Initial and Final SOC values are Equal.');
                break;
            end
            
            counter = counter + 1;
        end % End of IF toc
    end % While Loop
    
% CC Mode
elseif strcmpi(mode, 'cc')
    counter = 1; %In order for the sampling of data from profile
    % to be based on the number of samples
    timerPrev(1) = toc;
    
    % While Loop: Runs through the currProfile based on the sampling
    while counter <= length(profileTS.Time)
        %% Commands
        % Evaluates and changes commands based on the timing provided on the
        % profile
        if toc >= profileTS.Time(counter)
            timerPrev(2) = toc;
            % Evaluator
            % If the next current value is positive and the battery is
            % currently charging, discharge the battery or else
            % charge the battery (charging is simulating regen braking
            if (round(profileTS.Data(counter),1) < 0)
                chargeReq = false; % Make next command a discharge command
                curr = profileTS.Data(counter);
                disp("curr = " + num2str(curr));
            elseif (round(profileTS.Data(counter),1) > 0)
                chargeReq = true; % Make next command a charge command
                curr = profileTS.Data(counter);
                disp("curr = " + num2str(curr));
            else
                chargeReq = 3; % Not charging or discharging
            end
                        
            % Charge Command
            if (chargeReq == true)
                script_charge; % Run Script to begin/update charging process
                % Discharge Command
            elseif (chargeReq == false)
                script_discharge; % Run Script to begin/update discharging process
            else
                script_idle; % Run Script
            end
%             disp(battState);
            
            script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
            script_failSafes; %Run FailSafe Checks
            % if limits are reached, break loop
            if errorCode == 1
                break;
            end
            
            if(finalSOC < initialSOC)
                if battSOC <= finalSOC
                    break;
                end
            elseif (finalSOC > initialSOC)
                if battSOC >= finalSOC
                    break;
                end
            else
                warning('Initial and Final SOC values are Equal.');
                break;
            end
            
            counter = counter + 1;
        end % End of IF toc
    end % While Loop  
end

battTS.Time = battTS.Time - battTS.Time(1);
if plotFigs == true
    f = figure;
    plot(battTS.Time, battTS.Data(:,5),battTS.Time, battTS.Data(:,6));
    hold on;
    plot(profileTS);
    legend('battVolt','battCurr', 'profile');
end


%% Teardown Section

script_resetDevices; % Runs the resetDevices script

end

