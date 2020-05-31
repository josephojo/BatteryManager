%runProfile
%   Runs a single power profile based on one driving cycle. There is an
%   option to run this profile multiple times
%
%Change Log
%   REVISION    CHANGE                                          DATE-YYMMDD
%   00          Initial Revision from                           190116
%               BattTest_PowerProfile_rev1


clearvars;
clc;
pre = 0;
%% Setup Code
% IMPORT CURRENT PROFILE
matFile = 'X'; %'003EUDC_CurrProfile';
load(matFile); % Driving cycle variable name is "currProfile"

% Initializations
script_initializeDevices; % Initialized devices like Eload, PSU etc.
script_initializeVariables; % Run Script to initialize common variables
numIterations = 1; % Number of times to run the profile
% sampling = 5; % How often to extract data from array. 1 means every single cell, 2 means every other cell
% readPeriod = 0.25;
writePeriod = 0.2;

% Resamples the input profile to the interval given in readPeriod
currProfile = resample(currProfile, currProfile.Time(1):writePeriod:currProfile.Time(length(currProfile.Time)));
% ard = arduino();
% v=0;ain = []; curr = []; currArd = [];

% %Automatic Sampling
% sampling = round(readPeriod /(currProfile.Time(2) - currProfile.Time(1)),0);

%% Script
timi = [];
tic; % Start Timer
% script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable

for i = 1:numIterations
    counter = 1; %In order for the sampling of data from profile 
    % to be based on the number of samples
    
    timerPrev(1) = toc;
    
    % While Loop: Runs through the currProfile based on the sampling
    while counter <= length(currProfile.Time)       
        

        %% Commands
        % Evaluates and changes commands based on the timing provided on the
        % profile
        if toc >= currProfile.Time(counter)
            timerPrev(2) = toc;
            disp ("in Time = " + num2str(toc));
            disp("profile Time = " + num2str(currProfile.Time(counter)));
            % Evaluator
            % If the next current value is positive and the battery is
            % currently charging, discharge the battery
            % or else charge the battery (charging is simulating regen braking
            if (round(currProfile.Data(counter),1) < 0)
                chargeReq = false; % Make next command a discharge command
                curr = currProfile.Data(counter);
            elseif (round(currProfile.Data(counter),1) > 0)
                chargeReq = true; % Make next command a charge command
                curr = currProfile.Data(counter);
            else
                chargeReq = 3; % Not charging or discharging
            end
            disp("curr = " + num2str(curr));
%             disp("counter = " + num2str(counter));
            
            % Charge Command
            if (chargeReq == true)
                script_charge; % Run Script to begin/update charging process
                % Discharge Command
            elseif (chargeReq == false)
                script_discharge; % Run Script to begin/update discharging process
            else
                script_idle; % Run Script
            end
            disp(battState);
             
%             pause(0.15)

            script_avgLJMeas;
            script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
            
            script_failSafes; %Run FailSafe Checks
            % if limits are reached, break loop
            if errorCode == 1
                break;
            end
            disp ("out Time = " + num2str(toc));
            counter = counter + 1; 
        end % End of IF toc 
                
           %% Commands
%         % Evaluates and changes commands based on the timing provided on the
%         % profile
%         if toc >= currProfile.Time(counter)
%             timerPrev(2) = toc;
%             disp ("timi = " + num2str(timerPrev(2)));
%             % Evaluator
%             % If the next current value is positive and the battery is
%             % currently charging, discharge the battery
%             % or else charge the battery (charging is simulating regen braking
%             if (round(currProfile.Data(counter),1) < 0)
%                 chargeReq = false; % Make next command a discharge command
%                 curr = currProfile.Data(counter);
%             elseif (round(currProfile.Data(counter),1) > 0)
%                 chargeReq = true; % Make next command a charge command
%                 curr = currProfile.Data(counter);
%             else
%                 chargeReq = 3; % Not charging or discharging
%             end
%             disp("curr = " + num2str(curr));
%             disp("counter = " + num2str(counter));
%             
%             % Charge Command
%             if (chargeReq == true)
%                 script_charge; % Run Script to begin/update charging process
%                 % Discharge Command
%             elseif (chargeReq == false)
%                 script_discharge; % Run Script to begin/update discharging process
%             else
%                 script_idle; % Run Script
%             end
%             
%             counter = counter + 1;  
%             
%             while adcAvgCounter < adcAvgCount
%                 
%                 % Request a single-ended reading from AIN2 (VBatt+).
%                 ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN', 2, 0, 0, 0);
%                 
%                 % Request a single-ended reading from (VBatt-).
%                 ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN', 3, 0, 0, 0);
%                 %
%                 % Execute the requests.
%                 ljudObj.GoOne(ljhandle);
%                 
%                 [ljerror, ioType, channel, dblValue, dummyInt, dummyDbl] = ljudObj.GetFirstResult(ljhandle, 0, 0, 0, 0, 0);
%                 
%                 finished = false;
%                 while finished == false
%                     switch ioType
%                         case LJ_ioGET_AIN
%                             switch int32(channel)
%                                 case 2
%                                     ain2 = ain2 + dblValue;
%                                 case 3
%                                     ain3 = ain3 + dblValue;
%                             end
%                     end
%                     
%                     try
%                         [ljerror, ioType, channel, dblValue, dummyInt, dummyDbl] = ljudObj.GetNextResult(ljhandle, 0, 0, 0, 0, 0);
%                     catch e
%                         if(isa(e, 'NET.NetException'))
%                             eNet = e.ExceptionObject;
%                             if(isa(eNet, 'LabJack.LabJackUD.LabJackUDException'))
%                                 % If we get an error, report it. If the error is
%                                 % LJE_NO_MORE_DATA_AVAILABLE we are done.
%                                 if(int32(eNet.LJUDError) == LJE_NO_MORE_DATA_AVAILABLE)
%                                     finished = true;
%                                     adcAvgCounter = adcAvgCounter + 1;
%                                 end
%                             end
%                         end
%                         % Report non LJE_NO_MORE_DATA_AVAILABLE error.
%                         if(finished == false)
%                             throw(e)
%                         end
%                     end
%                 end
%             end
%             
% %             script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
% %             
% %             script_failSafes; %Run FailSafe Checks
% %             % if limits are reached, break loop
% %             if errorCode == 1
% %                 break;
% %             end
%              
%         end % End of IF toc 

        %% Measurements and Fail Safes
%         % Querys all measurements every readPeriod second(s)
%         if toc - timerPrev(3) >= readPeriod
%             timerPrev(3) = toc;
%             script_avgLJMeas;
%             script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
%             
%             script_failSafes; %Run FailSafe Checks
%             % if limits are reached, break loop
%             if errorCode == 1
%                 break;
%             end
%         end
        
%         if toc - pre >= 0.1
%             disp("Out of If TOC");
%             pre = toc;
%             disp(pre);
%         end
 
    end % While Loop
    
end % For Loop for numIterations

% battTS = delsample(battTS, 'Index', 1);
% 
battTS.Time = battTS.Time - battTS.Time(1);

plot(battTS.Time, battTS.Data(:,5),battTS.Time, battTS.Data(:,6))
hold on;
plot(currProfile);
legend('battVolt','battCurr', 'profile');
% save(dataLocation + "009RunProfileData_" + matFile(1:4) + ".mat", 'battTS', '-v7.3');


%% Teardown Section

script_resetDevices; % Runs the resetDevices script
