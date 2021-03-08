function battTS = chargeTo(targVolt, chargeCurr, varargin)
%chargeTo Charges to the specified SOC based on the charge current
%specified

%% Setup Code

param = struct('cellIDs',        [],...
    'trig1',            false,...
    'trig1_pin',        4,...
    'trig1_startTime',  [10.0],...
    'trig1_duration',   [2.0]);


% read the acceptable names
paramNames = fieldnames(param);

% Ensure variable entries are pairs
nArgs = length(varargin);
if round(nArgs/2)~=nArgs/2
    error('runProfile needs propertyName/propertyValue pairs')
end

for pair = reshape(varargin,2,[]) %# pair is {propName;propValue}
    inpName = pair{1}; %# make case insensitive
    
    if any(strcmpi(inpName,paramNames))
        %# overwrite options. If you want you can test for the right class here
        %# Also, if you find out that there is an option you keep getting wrong,
        %# you can use "if strcmp(inpName,'problemOption'),testMore,end"-statements
        param.(inpName) = pair{2};
    else
        error('%s is not a recognized parameter name',inpName)
    end
end

% ---------------------------------
cellIDs = param.cellIDs;

trig1_On = false;
trig1_Ind = 1;

if param.trig1 == true
    trig1StartTime = param.trig1_startTime;
    trig1EndTime = param.trig1_startTime + param.trig1_duration;
    trig1TimeTol = 0.5; % Half a second
end


% Initializations
try
    script_initializeDevices; % Initialized devices like Eload, PSU etc.
    script_initializeVariables; % Run Script to initialize common variables
    curr = chargeCurr; %2.5A is 1C for the ANR26650
    
    tic; % Start Timer
    script_charge; % Run Script to begin/update charging process
    
    %if volt >= maxBattVoltLimit
        script_queryData; % Run Script to query data from devices
        % While the battery voltage is less than the limit (our 100% SOC) (CC mode)
        while battVolt <= targVolt
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
        %{
        %% CV Mode
        % While the battery voltage is less than the limit (our 100% SOC) (CC mode)
        while battCurr >= cvMinCurr
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
        batteryParam.soc(cellIDs) = 1; % 100% Charged
    else
        % While the current volt is less than the specified volt
        while battVolt < volt
            %% CCCV, Measurements and FailSafes
            if battVolt <= highVoltLimit || battCurr >= cvMinCurr
                %% Measurements
                % Querys all measurements every readPeriod second(s)
                if toc - timerPrev(3) >= readPeriod
                    timerPrev(3) = toc;
                    script_queryData; % Run Script to query data from devices
                    
                    % Trigger1 (GPIO from LabJack)
                    if param.trig1==true
                        % The trigger is activated on trig1StartTime
                        % and switches OFF trig1EndTime
                        if tElasped >= trig1StartTime(trig1_Ind) && ...
                                tElasped < trig1StartTime(trig1_Ind) + trig1TimeTol && ...
                                trig1_On == false
                            disp("Trigger ON - " + num2str(timerPrev(3))+ newline)
                            pinVal = false;
                            % Make sure the heating pad is ON
                            ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', param.trig1_pin, pinVal, 0, 0);
                            ljudObj.GoOne(ljhandle);
                            trig1_On = true;
                        elseif tElasped >= trig1EndTime(trig1_Ind) && ...
                                tElasped < trig1EndTime(trig1_Ind) + trig1TimeTol && ...
                                trig1_On == true
                            disp("Trigger OFF - " + num2str(timerPrev(3))+ newline)
                            % Make sure the heating pad is ON
                            ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', param.trig1_pin, ~pinVal, 0, 0);
                            ljudObj.GoOne(ljhandle);
                            trig1_On = false;
                            if length(trig1StartTime) > 1 && trig1_Ind ~= length(trig1StartTime)
                                trig1_Ind = trig1_Ind + 1;
                            end
                        end
                    end
                    
                    script_failSafes; %Run FailSafe Checks
                    % if limits are reached, break loop
                    if errorCode == 1
                        break;
                    end
                end
            else
                batteryParam.soc(cellIDs) = 1; % 100% Charged
                break;
            end
        end
        %}
   % end
    
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
        if numCells > 1
            save(dataLocation + "005_" + cellConfig + "_ChargeTo" +num2str(round(battSOC*100,0))+ "%.mat", 'battTS', 'cellIDs');
        else
            save(dataLocation + "005_" + cellIDs(1) + "_ChargeTo" +num2str(round(battSOC*100,0))+ "%.mat", 'battTS');
        end
        % Save Battery Parameters
        save(dataLocation + "007BatteryParam.mat", 'batteryParam');
    end
catch ME_func
    script_resetDevices;
    %     disp("error")
    rethrow (ME_func)
end
%% Teardown
script_resetDevices;

end