function battTS = chargeTo(soc, chargeCurr, varargin)
%chargeTo Charges to the specified SOC based on the charge current
%specified

%% Setup Code

if nargin > 2
    cellID = varargin{1};
end

if soc == 1
    chargeToFull;
else
    
    % Initializations
    try
        
        
        script_initializeDevices; % Initialized devices like Eload, PSU etc.
        script_initializeVariables; % Run Script to initialize common variables
        curr = chargeCurr; %2.5A is 1C for the ANR26650
        
        tic; % Start Timer
        script_charge; % Run Script to begin/update charging process
        
        % While the current SOC is less than the specified soc
        while battSOC < soc
            
            %% CCCV, Measurements and FailSafes
            if battVolt <= highVoltLimit || battCurr >= cvMinCurr
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
            else
                batteryParam.soc(cellID) = 1; % 100% Charged
                break;
            end
        end
        
        if plotFigs == true
            currVals = ones(1, length(battTS.Time)) * curr;
            plotBattData(battTS, 'noCore');
            %         hold on;
            %         subplot(3, 1, 1);
            %         plot(battTS.Time, currVals);
            %         legend('battVolt','battCurr', 'profile', 'SOC');
        end
        
        % Save data
        if tElasped > 5 % errorCode == 0 && 
            save(dataLocation + "005_" + cellID + "_ChargeTo" +num2str(round(battSOC*100,0))+ "%.mat", 'battTS');
            % Save Battery Parameters
            save(dataLocation + "007BatteryParam.mat", 'batteryParam');
        end
    catch ME_func
        script_resetDevices;
        disp("error")
        rethrow (ME_func)
    end
    %% Teardown
    script_resetDevices;
end
end