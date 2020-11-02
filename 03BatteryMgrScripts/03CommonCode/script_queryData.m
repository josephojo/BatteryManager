% Queries Data from devices and stores them in a collection in the
% following format:
%           PSU Voltage, PSU Current, ELoad Voltage, ELoad Current,
%       Battery Voltage, Battery Current, Battery State, BatterySOC
%       Ambient Temp, Surface Temp, Core Temp


% If the timer for the current test was not started, start it. 
% %
% Having this here is probably better than starting it in the main
% functions since it'll mark when the experiment starts recording. This
% approach is only valid if the query (this file) is run before the 
% instruments apply current.
if ~exist('testTimer', 'var')
    testTimer = tic; % Start Timer for read period
end

% Capture Time
tElasped = toc(testTimer) - timerPrev(1);

% Temperature Measurement for the stack. Each temp measurement is indicated
% by the channel numbers they are connected to
if ismember("Temp", testSettings.data2Record) && strcmpi(testSettings.tempMeasDev, "Mod16Ch")
    if ~isempty(tempChnls)
        %{
% if useArd4Temp == 1
%     % Use only the TC data (Hot_Junc) from Arduino
% %     numCh = 1;
%     thermoData(1) = read(thermo,'holdingregs',9,numThermo)/10;
%     fprintf(ard, '1');
%     data = fgetl(ard);
%     thermoData(2) = str2double(string(data(1:end-1)));
% else
        %}
        
        readChnls = min(tempChnls) : max(tempChnls);
        readCount = length(readChnls);
        %Measure Data from thermometer. Using holdingregs function (03), read data
        %from 3 registers starting at register 9
        % thermoData = read(thermo,'holdingregs',9,3);
        %     numCh = 2;
        thermoData = read(thermo,'holdingregs',min(tempChnls), readCount);
        thermoData = thermoData(ismember(readChnls, tempChnls))/10;
        
    end
    
elseif ismember("Temp", testSettings.data2Record) && strcmpi(testSettings.tempMeasDev, "ardMod")
    err.code = ErrorCode.FEATURE_UNAVAIL;
    err.msg = "Using the arduino for temperature measurements has not yet been implemented.";
    send(errorQ, err);
end


%{
% % Measure Data from PSU
% psuData = psu.measureVoltCurr();
% 
% % Measure Data from ELoad
% eloadData = eload.MeasureVoltCurr();


% psuData(1) = 0; psuData(2) = 0;
% eloadData(1) = 0; eloadData(2) = 0;
% thermoData(1) = 0; thermoData(2) = 0; thermoData(3) = 0;
%}

% Voltage Measurement for the stack. Each cell is so far made to equal that of the stack
if ismember("volt", testSettings.data2Record) && strcmpi(testSettings.voltMeasDev, "mcu")
    script_avgLJMeas;
    
    % %Finds avg of total voltages collected at batt terminals and current sensor
    vBattp = voltPos / adcAvgCount;
    vBattn = voltNeg / adcAvgCount;
    packVolt = round(vBattp - vBattn + 0.01, 3);
    
    adcAvgCounter = 0; voltPos = 0; voltNeg = 0;
    
    % Get cell measurements if available
    if strcmpi(cellConfig, 'series')
        % Implementation coming soon.
    else
        cells.volt(cellIDs) = packVolt; % Assign stack voltage to individual voltage
    end
    
elseif ismember("volt", testSettings.data2Record) && strcmpi(testSettings.voltMeasDev, "powerDev")
    % Use Voltage Data from either PSU or ELOAD for Battery current
    if strcmpi(battState, "discharging")
        packVolt = eload.MeasureVolt();
    elseif strcmpi(battState, "charging")
        packVolt = psu.measureVolt();
    elseif strcmpi(battState, "idle")
        packVolt = eload.MeasureVolt();
    end
    
    % Get cell measurements if available
    if strcmpi(cellConfig, 'series')
        cells.volt(cellIDs) = bal.Voltages(1, logical(bal.cellPresent(1, :)));
    else
        cells.volt(cellIDs) = packVolt; % Assign stack voltage to individual voltage
    end
elseif ismember("volt", testSettings.data2Record) && strcmpi(testSettings.voltMeasDev, "balancer")
    cells.volt(cellIDs) = bal.Voltages(1, logical(bal.cellPresent(1, :)))';
    packVolt = bal.Board_Summary_Data.Volt_Sum;
end


% Current Measurement for the stack. Each cell is so far made to equal that of the stack
if ismember("curr", testSettings.data2Record) && strcmpi(testSettings.currMeasDev, "mcu")  % if strcmp(cellConfig, 'single') ~= true
    % No need to re-run the script if it has already been run during voltage measurement
    if ~ismember("volt", testSettings.data2Record) || ~strcmpi(testSettings.voltMeasDev, "mcu") 
        script_avgLJMeas;
    end
    cSigP1 = currPos / adcAvgCount; % First Current Sensor (+ve term volt meas)
    cSigN1 = currNeg / adcAvgCount; % First Current Sensor (-ve term volt meas)
    cSigP_N1 = round(cSigP1 - cSigN1, 4); %4,'significant')+0.00;
    
    %{
    cSigP2 = ain1 / adcAvgCount; % Second Current Sensor (+ve term volt meas)
    cSigN2 = ain7 / adcAvgCount; % Second Current Sensor (-ve term volt meas)
    cSigP_N2 = round(cSigP2 - cSigN2, 4); %4,'significant')+0.00;
    cells.curr(cellIDs) = [(cSigP_N1 - 2.4902)/0.1, (cSigP_N2 - 2.5132)/0.1]; % Sensor Sensitivity = 100mV/A
    %}
    
    adcAvgCounter = 0; currPos = 0; currNeg = 0; % ain1 = 0;
    
    packCurr = -(cSigP_N1 - 2.4902)/0.1; % Negative for Charging, Pos for discharging
    
    if strcmpi(battState, "idle")
        packCurr = 0.0;
    end
    % Get cell measurements if available
    if strcmpi(cellConfig, 'parallel')
        % Implementation coming soon.
    else
        cells.curr(cellIDs) = packCurr; % Assign stack current to individual current
    end
    

elseif ismember("curr", testSettings.data2Record) && strcmpi(testSettings.currMeasDev, "powerDev") 
    % Use Current Data from either PSU or ELOAD for Battery current
    if strcmpi(battState, "discharging")
        packCurr = eload.MeasureCurr();
    elseif strcmpi(battState, "charging")
        packCurr = -psu.measureCurr();
    elseif strcmpi(battState, "idle")
        packCurr = 0.0;
    end
    
    % Get cell measurements if available
    if strcmpi(cellConfig, 'parallel')
        % Implementation coming soon.
    else
        cells.curr(cellIDs) = packCurr; % Assign stack current to individual current
    end
elseif ismember("curr", testSettings.data2Record) && strcmpi(testSettings.currMeasDev, "balancer")
    % Use Current Data from either PSU or ELOAD for Pack current
    if strcmpi(battState, "discharging")
        packCurr = eload.MeasureCurr(); % Discharge is positive
    elseif strcmpi(battState, "charging")
        packCurr = -psu.measureCurr(); % Charging is negative
    elseif strcmpi(battState, "idle")
        packCurr = 0.0;
    end
    
    balCurr = bal.Currents(1, logical(bal.cellPresent(1, :)));
    
    % % Compute Actual Current Through cells
    logicalInd = balCurr(:) >= 0;
    balActual_dchrg = T_dchrg * (balCurr(:) .* (logicalInd));
    balActual_chrg = T_chrg * (balCurr(:) .* (~logicalInd));
    balActual = balActual_chrg + balActual_dchrg;
    cells.curr(cellIDs) = packCurr + balActual(:); % Actual Current in each cell

%     cells.curr(cellIDs) = balEff * bal.Currents(1, logical(bal.cellPresent(1, :)) + packCurr);
end



% SOC and AhCap Estimation for the stack. Each cell is so far made to equal that of the stack
if ismember("SOC", testSettings.data2Record)
    tmpT = toc(testTimer);
    deltaT = tmpT - timerPrev(4);
    timerPrev(4) = tmpT; % Update Current time to previous
    
    if ismember("Cap", testSettings.data2Record)
        cells.AhCap(cellIDs) = cells.AhCap(cellIDs) + (cells.curr(cellIDs) * (deltaT/3600));
        AhCap = AhCap + (packCurr * (deltaT/3600));
    end
    
    if strcmpi(cellConfig, "series")
        % Get Change in SOCs
%         dSoc_bal = estimateDeltaSOC(cells.curr(cellIDs),...
%             deltaT, cells.coulomb(cellIDs), cellConfig); % Leave right after cell curr update since it is used in SOC estimation
%         dSoc_stack = estimateDeltaSOC(packCurr,...
%             deltaT, coulombs, cellConfig); % Leave right after packCurr update since it is used in SOC estimation
%         
%         % Update cell SOCs
%         cells.SOC(cellIDs) = cells.prevSOC(cellIDs) + (dSoc_bal + dSoc_stack);
%         
        cells.SOC(cellIDs) = estimateSOC(cells.curr(cellIDs),...
            deltaT, cells.prevSOC(cellIDs), cells.coulomb(cellIDs)); 
        packSOC = mean(cells.SOC(cellIDs));
       
    else
        cells.SOC(cellIDs) = estimateSOC(cells.curr(cellIDs),...
            deltaT, cells.prevSOC(cellIDs), coulombs);
        packSOC = estimateSOC(packCurr, deltaT, prevSOC, coulombs);
        
    end
    
    % Update Previous SOCs
    cells.prevSOC(cellIDs) = cells.SOC(cellIDs); % Update the current cell SOC as prev
    prevSOC = packSOC; % Update the current SOC as prev
    
    % Store the SOC of the pack in for both cells in the stack
    batteryParam.soc(cellIDs) = cells.SOC(cellIDs);
    
    if ~strcmpi(cellConfig, 'single')
        if exist('packParam' , 'var'), packParam.soc(packID) = packSOC; end
    end
    
end

% #DEP_01 - If this order changes, the order in "script_initializeVariables" 
% should also be altered
data = [packVolt, packCurr, packSOC, AhCap,...
            cells.volt(cellIDs)', cells.curr(cellIDs)',...
            cells.SOC(cellIDs)',cells.AhCap(cellIDs)',...
            thermoData(:)'];



battTS = addsample(battTS,'Data',data,'Time',tElasped);

if caller == "gui"
    battData.data = data;
    battData.time = tElasped;
    send(dataQ, battData);
else
    
    if verbosity == 0
        %     if tElasped - timerPrev(5) >= 1. % 2.2
        %         disp(tElasped - timerPrev(5))
        %         timerPrev(5) = tElasped;
        fprintf(".")
        dotCounter = dotCounter + 1;
        if dotCounter >= 60
            disp(newline)
            disp(num2str(tElasped,'%.2f') + " seconds");
            %             Tstr = sprintf("TC 1 = %.1f ºC\t\t\tTC 2 = %.2f ºC" ,thermoData(1), thermoData(2)); % \t\t\tTC 3 = %.1f ºC
            %             Tstr = "";
            %             for i = 1:numThermo
            %                 Tstr = Tstr + sprintf("TC " + num2str(i) + " = %.2f ºC\t\t\t" ,thermoData(i));
            %                 if mod(i, 2) == 0 && i ~= numThermo
            %                    Tstr = Tstr + newline;
            %                 end
            %             end
            Tstr = "";
            for i = 1:length(tempChnls)
                Tstr = Tstr + sprintf("TC@Ch" + tempChnls(i) + " = %.2fºC\t\t" ,thermoData(i));
                if mod(i, 3) == 0 && i ~= length(tempChnls)
                   Tstr = Tstr + newline;
                end
            end
            
            Bstr = "";
            for cellID = cellIDs           
                Bstr = Bstr + sprintf("Volt " + cellID + " = %.2f V\t", cells.volt(cellID));
                Bstr = Bstr + sprintf("Curr " + cellID + " = %.2f A\t", cells.curr(cellID));
                Bstr = Bstr + sprintf("SOC " + cellID + " = %.2f\t", cells.SOC(cellID)*100);
                Bstr = Bstr + sprintf("Ah " + cellID + " = %.3f Ah\t", cells.AhCap(cellID));
                Bstr = Bstr + newline;
            end
            
            Bstr = Bstr + sprintf("\nPack Volt = %.4f V\tPack Curr = %.4f A\n" + ...
                "Pack SOC = %.2f \t\tPack AH = %.3f\n\n", packVolt, packCurr,...
                packSOC*100, AhCap);
            fprintf(Tstr + newline);
            fprintf(Bstr);
            dotCounter = 0;
        end
        %     end
    elseif verbosity == 1
        disp(num2str(tElasped,'%.2f') + " seconds");
        %             Tstr = sprintf("TC 1 = %.1f ºC\t\t\tTC 2 = %.2f ºC" ,thermoData(1), thermoData(2)); % \t\t\tTC 3 = %.1f ºC
        %             Tstr = "";
        %             for i = 1:numThermo
        %                 Tstr = Tstr + sprintf("TC " + num2str(i) + " = %.2f ºC\t\t\t" ,thermoData(i));
        %                 if mod(i, 2) == 0 && i ~= numThermo
        %                    Tstr = Tstr + newline;
        %                 end
        %             end
        Tstr = "";
        for i = 1:length(tempChnls)
            Tstr = Tstr + sprintf("TC@Ch" + tempChnls(i) + " = %.2fºC\t\t" ,thermoData(i));
            if mod(i, 3) == 0 && i ~= length(tempChnls)
               Tstr = Tstr + newline;
            end
        end

        Bstr = "";
        for cellID = cellIDs     
            Bstr = Bstr + sprintf("Volt " + cellID + " = %.2f V\t", cells.volt(cellID));
            Bstr = Bstr + sprintf("Curr " + cellID + " = %.2f A\t\t", cells.curr(cellID));
            Bstr = Bstr + sprintf("SOC " + cellID + " = %.2f \t\t", cells.SOC(cellID)*100);
            Bstr = Bstr + sprintf("Ah " + cellID + " = %.3f Ah\t", cells.AhCap(cellID));
            Bstr = Bstr + newline;
        end

        Bstr = Bstr + sprintf("\tPack Volt = %.4f V\tPack Curr = %.4f A\n" + ...
            "Pack SOC = %.2f \t\tPack AH = %.3f\n\n", packVolt, packCurr,...
            packSOC*100, AhCap);
        fprintf(Tstr + newline);
        fprintf(Bstr);
    end
end
