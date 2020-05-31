function battTS = dischargeTo(soc, dischargeCurr, varargin)
%dischargeTo Discharges to the specified SOC based on the previous SOC


%% Setup Code
if nargin > 2
    cellID = varargin{1};
end


try
    % Initializations
    script_initializeDevices; % Initialized devices like Eload, PSU etc.
    
    script_initializeVariables; % Run Script to initialize common variables
    curr = -abs(dischargeCurr); %2.5A is 1C for the ANR26650
    tic; % Start Timer
    script_discharge; % Run Script to begin/update discharging process
    
    if soc == 0
        
        script_queryData; % Run Script to query data from devices
        
        % While battVolt is greater than low limit
        while battVolt >= lowVoltLimit
            %% Measurements
            % Querys all measurements every readPeriod second(s)
            if toc - timerPrev(3) >= readPeriod
                timerPrev(3) = toc;
                script_queryData; % Run Script to query data from devices
                script_failSafes; %Run FailSafe Checks
                % if limits are reached, break loop
                if errorCode == 1
                    break;
                end
            end
        end
        batteryParam.soc(cellID) = 0; % 0% DisCharged
    else
        % While SOC is greater than specified
        while battSOC > soc
            %% Measurements and Fail Safes
            % Querys all measurements every readPeriod second(s)
            if toc - timerPrev(3) >= readPeriod
                timerPrev(3) = toc;
                script_queryData; % Run Script to query data from devices
                script_failSafes; %Run FailSafe Checks
                % if limits are reached, break loop
                if errorCode == 1
                    break;
                end
            end
        end
    end
    if plotFigs == true
        currVals = ones(1, length(battTS.Time)) * curr;
        %         plot(battTS.Time, battTS.Data(:,1),battTS.Time, battTS.Data(:,2),...
        %             battTS.Time, battTS.Data(:,3), battTS.Time, battTS.Data(:,4),...
        %             'LineWidth', 3);
        
        plotBattData(battTS, 'noCore');
        hold on;
        subplot(3, 1, 1);
        plot(battTS.Time, currVals);
        legend('battVolt','battCurr', 'profile', 'SOC');
    end
    
    % Save data
    if tElasped > 5 %errorCode == 0 &&
        save(dataLocation + "006_" + cellID + "_DischargeTo" +num2str(round(battSOC*100,0))+ "%.mat", 'battTS', '-v7.3');
        % Save Battery Parameters
        save(dataLocation + "007BatteryParam.mat", 'batteryParam');
    end
    
catch ME_func
    script_resetDevices;
    rethrow (ME_func)
end
%% Teardown
script_resetDevices;

end