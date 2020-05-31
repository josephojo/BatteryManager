
% MAKE SURE BATTERY IS FULL BEFORE RUNNING THIS! 
% prevSOC IS ASSUMMED TO BE 100%!!

try
matFile = '003US06_CurrProfile'; %'003UDDS_CurrProfile'; %'003HWFET_CurrProfile';
load(matFile); % Driving cycle variable name is "currProfile"

% Initializations
script_initializeDevices; % Initialized devices like Eload, PSU etc.
script_initializeVariables; % Run Script to initialize common variables
writePeriod = 0.4; % Period to resample the input current profile

plotFigs = false;
prevSOC = 0.998;

numIterations = 6; % Number of times to run the profile

% Resamples the input profile to the interval given in readPeriod
currProfile = resample(currProfile, currProfile.Time(1):writePeriod:currProfile.Time(length(currProfile.Time)));

%% Script
tic;
timerPrev(1) = toc;
for i = 1:numIterations
    disp("Beginning Iteration Number: " + num2str(i) + " ; Estimated Time to commpletion: " +...
        string(datetime('now') + minutes((currProfile.Time(end) * ((numIterations + 1) - i))/60)));
    
    timerPrev(2) = toc;
    counter = 1; %In order for the sampling of data from profile
                    % to be based on the number of samples
    % While Loop: Runs through the currProfile
    while counter <= length(currProfile.Time)
        %% Commands
        % Evaluates and changes commands based on the timing provided on the
        % profile
        if toc - timerPrev(2) >= currProfile.Time(counter)
            % Evaluator
            % If the next current value is positive and the battery is
            % currently charging, discharge the battery or else
            % charge the battery (charging is simulating regen braking
            if (round(currProfile.Data(counter),1) < 0)
                chargeReq = false; % Make next command a discharge command
                curr = currProfile.Data(counter);
%                 disp("curr = " + num2str(curr));
            elseif (round(currProfile.Data(counter),1) > 0)
                chargeReq = true; % Make next command a charge command
                curr = currProfile.Data(counter);
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
            counter = counter + 1;
        end % End of IF toc
    end % While Loop
    % if limits are reached, break loop
    if errorCode == 1
        break;
    end
end % For Iteration Loop

battTS.Time = battTS.Time - battTS.Time(1);

if plotFigs == true
plot(battTS.Time, battTS.Data(:,5),battTS.Time, battTS.Data(:,6))
hold on;
plot(currProfile);
legend('battVolt','battCurr', 'profile');
end

if length(matFile) >= 4
save(dataLocation + "009RunProfileData" + num2str(i)+ "Times_" + matFile(4:8) + ".mat", 'battTS', '-v7.3');
end

%% Teardown Section

script_resetDevices; % Runs the resetDevices script
catch ME
    script_resetDevices;
    rethrow(ME);
end
