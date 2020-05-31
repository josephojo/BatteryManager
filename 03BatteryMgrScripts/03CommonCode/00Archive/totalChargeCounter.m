% clearvars;
% clc;

try
    %% Setup Code
    tic; % Start Timer
    
    dischargeToEmpty;
    dischargeCurrVals = ones(1, length(battTS.Time)) * -curr;
    disBattTS = battTS; % Temporary
    
    % script_idle;
    % pause(60); % Wait for the battery voltage to stabilize
    
    % Initializations
    script_initializeDevices; % Initialized devices like Eload, PSU etc.
    
    trackSOCFS = false;
    
    AhCap = 0;
    coulombCount = 0;
    
    plotFigs = true;
    
    curr = (batteryParam.ratedCapacity(cellID)*1); % X of rated Capacity
    
    
    %% CC Mode
    script_queryData; % Run Script to query data from devices
    prevCoulombTimer = toc;
    script_charge; % Run Script to begin/update charging process
    
    % While the battery voltage is less than the limit (our 100% SOC) (CC mode)
    while battVolt <= highVoltLimit
        newCoulombTimer = toc;
        coulombCount = coulombCount + battCurr * (newCoulombTimer - prevCoulombTimer);
        prevCoulombTimer = newCoulombTimer;
        %% Measurements
        % Querys all measurements every readPeriod second(s)
        if toc - timerPrev(3) >= readPeriod
            timerPrev(3) = toc;
            script_queryData; % Run Script to query data from devices
            disp("Coulomb Counter: " + num2str(coulombCount) + newline);
            script_failSafes; %Run FailSafe Checks
            % if limits are reached, break loop
            if errorCode == 1
                break;
            end
        end
    end
    
    %% CV Mode
    % battState = ""; % This is here to allow the PSU voltage to be updated in [script_charge]
    % chargeVolt = highVoltLimit; % + (circuitImp * (curr - 0.023));
    % script_charge; % Run Script to begin/update charging process
    % script_queryData; % Run Script to query data from devices
    
    % While the battery voltage is less than the limit (our 100% SOC) (CC mode)
    while battCurr >= cvMinCurr
        %% Measurements
        newCoulombTimer = toc;
        coulombCount = coulombCount + battCurr * (newCoulombTimer - prevCoulombTimer);
        prevCoulombTimer = newCoulombTimer;
        % Querys all measurements every readPeriod second(s)
        if toc - timerPrev(3) >= readPeriod
            timerPrev(3) = toc;
            script_queryData; % Run Script to query data from devices
            disp("Coulomb Counter: " + num2str(coulombCount) + newline);
            script_failSafes; %Run FailSafe Checks
            % if limits are reached, break loop
            if errorCode == 1
                break;
            end
        end
    end
    
%     %% CC Mode
%     script_queryData;
%     prevCoulombTimer = toc;
%     script_charge;
%     
%     % Charge to highVoltLimit.
%     while battVolt <= highVoltLimit
%         %% Measurements and Fail Safes
%         newCoulombTimer = toc;
%         coulombCount = coulombCount + battCurr * (newCoulombTimer - prevCoulombTimer);
%         prevCoulombTimer = newCoulombTimer;
%         
%         % Querys all measurements every readPeriod second(s)
%         if toc - timerPrev(3) >= readPeriod
%             timerPrev(3) = toc;
%             script_queryData; % Run Script to query data from devices
%             disp("Coulomb Counter: " + num2str(coulombCount) + newline);
%             script_failSafes; %Run FailSafe Checks
%             % if limits are reached, break loop
%             if errorCode == 1
%                 break;
%             end
%         end
%     end
    
    
    % Plot the data if true
    if plotFigs == true
        %     plot(battTS.Time, battTS.Data(:,1),battTS.Time, battTS.Data(:,2),...
        %         battTS.Time, battTS.Data(:,3), battTS.Time, battTS.Data(:,4),...
        %         'LineWidth', 3);
%         legend('battVolt','battCurr', 'SOC', 'Ah', 'profile');
        plotBattData(battTS, 'noCore');
    end
    
    % Save data
    if errorCode ~= 0 && tElasped > 1
        save(dataLocation + "007_" + cellID + "_AhCounter.mat", 'battTS');
        
        batteryParam.soc(cellID) = 1; % 100% Charged
        batteryParam.capacity(cellID) = AhCap;
        
        % Save Battery Parameters
        save(dataLocation + "007BatteryParam.mat", 'batteryParam');
    end
    
catch ME
    script_resetDevices;
    rethrow(ME);
end

%% Teardown
script_resetDevices;
