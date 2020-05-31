function chargeTo(soc, chargeCurr)
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
curr = chargeCurr; %2.5A is 1C for the ANR26650

tic; % Start Timer
script_charge; % Run Script to begin/update charging process
d = false;
% chargeCurve = figure(1);
% yyaxis left
% title('V-I Charge Curve')
% xlabel('Time (s)')
% ylabel('Voltage (V)')
% yyaxis right
% ylabel('Current (A)')
% plot(0,0,'g.',0,0,'r.', 0,0, 'b.');
% hold on;
pause(1)
% While the current of the battery while charging is greater than 3% of its
% rated current (CV mode)
while battSOC < soc
%     script_charge; % Run Script to begin/update charging process
    
    %% Measurements
%     script_avgLJMeas; %Run Script to average voltage measurements from Labjack
    
    % Querys all measurements every readPeriod second(s)
    if toc - timerPrev(3) >= readPeriod
        timerPrev(3) = toc;
        script_avgLJMeas;
        script_queryData; % Run Script to query data from devices
        
%         yyaxis left
%         plot(battTS.Time(end), battTS.Data(end,1),'g.', battTS.Time(end), battTS.Data(end,3),'b.');
%         yyaxis right
%         plot(battTS.Time(end), battTS.Data(end,6), 'r.');
        
        %%
%         if battVolt >= highVoltLimit
%             highVoltLimitPassed = true;
%         end
%         
%         if highVoltLimitPassed == true
%             %     chargeVolt = round(battVolt,1);
%             error = battVolt - highVoltLimit;
%             script_calcPID;
%             curr = curr - round(pidVal,1);
%             disp("curr: "+ num2str(curr)+ "\tpid: "+ num2str(pidVal));
%             if curr <= 0.1
%                 
%                 curr = 0.1;
%             end
%             if curr > 2.5
%                 disp("Curr is way too high: " + num2str(curr))
%                 curr = 1;
%             end
%             %             if d == false
%             %                 chargeVolt = highVoltLimit+0.1;
%             %                 curr = 2.2;
%             %                 d=true;
%             %             end
%         else
%             chargeVolt = round((curr*0.09) + highVoltLimit,1);
%         end
        
        %% Fail Safes
        script_failSafes; %Run FailSafe Checks
        % if limits are reached, break loop
        if errorCode == 1
            break;
        end
    end
end
% legend('PSU Voltage', 'Battery Voltage', 'Battery Current');
% yyaxis left
% legend('PSU Voltage', 'Battery Voltage')
% yyaxis right
% legend('Battery Current');

% Save data
save(dataLocation + "005ChargeTo" +num2str(soc*100,'%.0f')+ "%.mat", 'battTS', '-v7.3');

%% Teardown
script_resetDevices;
end