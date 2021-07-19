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

%% Time Duration recording

% Capture Time
tElapsed = toc(testTimer) - timerPrev(1);
testData.time(end+1, :) = tElapsed;


%% Temperature Measurement for the stack. 
% Each temp measurement is indicated
% by the channel numbers they are connected to
if ismember("Temp", testSettings.data2Record) && strcmpi(testSettings.tempMeasDev, "Mod16Ch")
    if ~isempty(tempChnls)
       % Commented section uses Arduino and a single channel DAQ for TC measurements
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
        testData.temp(end+1, :) = thermoData;
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


%% Voltage Measurement for the stack.

% If using a single cell or a parallel cell stack and the 
% voltage measurement device is the Labjack U3-HV (LJ) for more accurate
% measurements, the relay connect the battery to the LJ for measurement
if ~isempty(testData.time)
    % We don't want this to constantly run. 
    % Only run if the test has just started running and LJ is asked to
    % measure voltage
    if testData.time(end, 1) < 0.1 && LJ_MeasVolt == true 
       % Activate relay to allow the LJ MCU to measure Voltage. 
        % This is needed so that the MCU can measure a more accurate voltage. 
        % Keep in mind though that the MCU cannot measure series voltage
        % past 5V
        [ljudObj,ljhandle] = MCU_digitalWrite(ljudObj, ljhandle, LJ_MeasVoltPin, LJ_MeasVolt, LJ_MeasVolt_Inverted);
    end
end

% Each cell is made to equal that of the stack if it is parallel ot single
% cell and is individually called for series/seris-parallel stacks if
% called from the DC2100A balancer
if ismember("volt", testSettings.data2Record) && strcmpi(testSettings.voltMeasDev, "mcu")
    script_avgLJMeas;
    
    % %Finds avg of total voltages collected at batt terminals and current sensor
    vBattp = voltPos / adcAvgCount;
    vBattn = voltNeg / adcAvgCount;
    testData.packVolt(end+1, :) = round(vBattp - vBattn + 0.01, 3);
    
    adcAvgCounter = 0; voltPos = 0; voltNeg = 0;
    
    % Get cell measurements if available
    if strcmpi(cellConfig, 'series') || strcmpi(cellConfig, 'SerPar')
        % Implementation coming soon.
    elseif strcmpi(cellConfig, 'parallel')
    %TO DO: measure voltage for each batteries in parallel
        testData.cellVolt(end+1, :) = testData.packVolt(end, :);
    else
        testData.cellVolt(end+1, :) = testData.packVolt(end, :); % Assign stack voltage to individual cell voltage
    end
    
elseif ismember("volt", testSettings.data2Record) && strcmpi(testSettings.voltMeasDev, "powerDev")
    % Use Voltage Data from either PSU or ELOAD for Battery current
    if strcmpi(battState, "discharging")
        testData.packVolt(end+1, :) = eload.MeasureVolt();
    elseif strcmpi(battState, "charging")
        testData.packVolt(end+1, :) = eload.MeasureVolt();
    elseif strcmpi(battState, "idle")
        testData.packVolt(end+1, :) = eload.MeasureVolt();
    end
    
    % Get cell measurements if available
    if strcmpi(cellConfig, 'series') || strcmpi(cellConfig, 'SerPar')
       % This is a VERY bad thing to do!!! 
       % Cells will most likely not be balanced at all times. 
       % Only leaving this here since the powerDevs cannot sense individual cell voltages
        testData.cellVolt(end+1, :) = testData.packVolt(end, :) / numCells_Ser; 
        warning("Dividing pack voltage to get cell Voltage is dangerous (overcharge)." + newline ... 
            + "Make sure cells are being balanced!!")
    else
        testData.cellVolt(end+1, :) = testData.packVolt(end, :); % Assign stack voltage to individual voltage
    end
    
elseif ismember("volt", testSettings.data2Record) && strcmpi(testSettings.voltMeasDev, "balancer")
    balVolts = bal.Voltages(1, logical(bal.cellPresent(1, :)));
    testData.cellVolt(end+1, :) = balVolts(:)'; % Placing these horizontally despite being data for series stack (since time is vertical).
    testData.packVolt(end+1, :) = bal.Board_Summary_Data.Volt_Sum;
    
end


%% Current Measurement for the stack. 
% Each cell is so far made to equal that of the stack

% Use Current Data from either PSU or ELOAD for Battery current
if strcmpi(battState, "discharging")
    testData.packCurr(end+1, :) = eload.MeasureCurr();
elseif strcmpi(battState, "charging")
    testData.packCurr(end+1, :) = -psu.measureCurr();
elseif strcmpi(battState, "idle")
    testData.packCurr(end+1, :) = 0.0;
end
    
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
    if strcmpi(battState, "idle")
        testData.packCurr(end+1, :) = 0.0;
    end
    % Get cell measurements from Arduino if available
    if strcmpi(cellConfig, 'parallel') || strcmpi(cellConfig, 'SerPar')
        if ~isempty(ard)
            testData.cellCurr(end+1, :) = measureCurr_Ard(ard);
        else
            testData.cellCurr(end+1, :) = testData.packCurr(end, :)/numCells_Par; % Assign stack current to individual current
        end
    else
        testData.cellCurr(end+1, :) = testData.packCurr(end, :); % Assign stack current to individual current
    end
    

elseif ismember("curr", testSettings.data2Record) && strcmpi(testSettings.currMeasDev, "powerDev")   
    % Get cell measurements if available
    if strcmpi(cellConfig, 'parallel') || strcmpi(cellConfig, 'SerPar')
        % This Implementation is wrong since current won't be the same due
        % to the battery's internal impedance
%         testData.cellCurr(end+1, :) = testData.packCurr(end, :)/numCells_Par; % Assign stack current to individual current
        testData.cellCurr(end+1, :) = measureCurr_Ard(ard);
    else
        testData.cellCurr(end+1, :) = testData.packCurr(end, :); % Assign stack current to individual current
    end
    
elseif ismember("curr", testSettings.data2Record) && strcmpi(testSettings.currMeasDev, "balancer")
    balCurr = bal.Currents(1, logical(bal.cellPresent(1, :)));
    testData.balCurr(end+1, :)       = balCurr'; % "measured" balance current
    % Combine currents for both active and passive balancing currents
    if bal.isPassiveBalancing == true
        balActual = balCurr;
    else
        % % Compute Actual Current Through cells
        logicalInd = balCurr(:) >= 0;
        balActual_dchrg = T_dchrg * (balCurr(:) .* (logicalInd));
        balActual_chrg = T_chrg * (balCurr(:) .* (~logicalInd));
        balActual = balActual_chrg + balActual_dchrg;
    end
    testData.cellCurr(end+1, :) = testData.packCurr(end, :) + balActual(:)'; % Actual Current in each cell
end


%% SOC and AhCap Estimation for the stack. 
% Each cell is so far made to equal that of the stack
if ismember("SOC", testSettings.data2Record)
    tmpT = toc(testTimer);
    deltaT = tmpT - timerPrev(4);
    timerPrev(4) = tmpT; % Update Current time to previous
    
    if ismember("Cap", testSettings.data2Record)
        if isempty(testData.cellCap)
            cellCap = 0;
            packCap = 0;
        else
            cellCap = testData.cellCap(end, :);
            packCap = testData.packCap(end, :);
        end
        testData.cellCap(end+1, :) = cellCap + (testData.cellCurr(end, :) * (deltaT/3600));
        testData.packCap(end+1, :) = packCap + (testData.packCurr(end, :) * (deltaT/3600));
    end
    
    if isempty(testData.cellSOC)
        cellSOC = batteryParam.cellSOC{battID}';
        packSOC = batteryParam.soc(battID); 
    else
        cellSOC = testData.cellSOC(end, :);
        packSOC = testData.packSOC(end, :);
    end
    if (testData.packCurr(end, :) < 0), colEff = batteryParam.cellEta{battID}; else, colEff = 1; end
    
    if strcmpi(cellConfig, "series") || strcmpi(cellConfig, 'SerPar')
        testData.cellSOC(end+1, :) = estimateSOC(testData.packCurr(end, :).*colEff(:)',...
            deltaT, cellSOC, (batteryParam.cellCap{battID}' * 3600)); % Capacity x 3600 = coulombs
        testData.packSOC(end+1, :) = mean(testData.cellSOC(end, :));
    elseif strcmpi(cellConfig, "parallel")
        testData.cellSOC(end+1, :) = estimateSOC(testData.cellCurr(end, :).*colEff(:),...
            deltaT, packSOC, batteryParam.capacity(battID)*3600); % Capacity x 3600 = coulombs
        testData.packSOC(end+1, :) = sum(testData.cellSOC(end, :))/numCells_Par;
    else
        testData.cellSOC(end+1, :) = estimateSOC(testData.packCurr(end, :).*colEff(:),...
            deltaT, packSOC, batteryParam.capacity(battID)*3600); % Capacity x 3600 = coulombs
        testData.packSOC(end+1, :) = sum(testData.cellSOC(end, :))/numCells_Par;
    end
    
%     % Update Previous SOCs
%     cells.prevSOC(cellIDs) = cells.SOC(cellIDs); % Update the current cell SOC as prev
%     prevSOC = testData.packSOC(end+1, :); % Update the current SOC as prev
%     
    % Store the SOC of the pack in for both cells in the stack
    batteryParam.cellSOC{battID} = testData.cellSOC(end, :)';
    batteryParam.soc(battID) = testData.packSOC(end, :);

end

%{
% Old Code that uses timeseries type instead of new struct method
% It is kept here in case. Should be removed soon
% #DEP_01 - If this order changes, the order in "script_initializeVariables" 
% should also be altered
data = [packVolt, packCurr, packSOC, AhCap,...
            cells.volt(cellIDs)', cells.curr(cellIDs)',...
            cells.SOC(cellIDs)',cells.AhCap(cellIDs)',...
            thermoData(:)'];



battTS = addsample(battTS,'Data',data,'Time',tElasped);
%}


%% Data Print in Console Section

if caller == "gui"
    battData.data = data;
    battData.time = tElapsed;
    send(dataQ, battData);
else
    
    if verbosity == 0
        fprintf(".")
        dotCounter = dotCounter + 1;
        if dotCounter >= 60
            disp(newline)
            disp(num2str(tElapsed,'%.2f') + " seconds");
            Tstr = "";
            for i = 1:length(tempChnls)
                Tstr = Tstr + sprintf("TC@Ch" + tempChnls(i) + " = %.2fºC\t\t" ,thermoData(i));
                if mod(i, 3) == 0 && i ~= length(tempChnls)
                   Tstr = Tstr + newline;
                end
            end
            
            Bstr = "";
            for cellPrintInd = 1:numCells_Ser           
%                 Bstr = Bstr + sprintf("Volt(" + cellPrintInd + ", :) = %.2fV\t\t", testData.cellVolt(end, cellPrintInd));
                Bstr = Bstr + sprintf("Volt(" + cellPrintInd + ", :) = %.2fV\t\t", testData.cellVolt(end, 1));
                Bstr = Bstr + sprintf("Curr(" + cellPrintInd + ", :) = %.2fA\t\t", testData.cellCurr(end, cellPrintInd));
                Bstr = Bstr + sprintf("SOC(" + cellPrintInd + ", :) = %.2f\t\t",    testData.cellSOC(end, cellPrintInd)*100);
                Bstr = Bstr + sprintf("Ah(" + cellPrintInd + ", :) = %.3fAh\t\t",  testData.cellCap(end, cellPrintInd));
                Bstr = Bstr + newline;
            end
            
            Bstr = Bstr + sprintf("\nPack Volt = %.4f V\tPack Curr = %.4f A\n" + ...
                "Pack SOC = %.2f \t\tPack AH = %.3f\n\n", testData.packVolt(end, :), testData.packCurr(end, :),...
                testData.packSOC(end, :)*100, testData.packCap(end, :));
            fprintf(Tstr + newline);
            fprintf(Bstr);
            dotCounter = 0;
        end
    elseif verbosity == 1
        disp(num2str(tElapsed,'%.2f') + " seconds");
        Tstr = "";
        for i = 1:length(tempChnls)
            Tstr = Tstr + sprintf("TC@Ch" + tempChnls(i) + " = %.2fºC\t\t" ,thermoData(i));
            if mod(i, 3) == 0 && i ~= length(tempChnls)
               Tstr = Tstr + newline;
            end
        end

        Bstr = "";
        % Depending on the configuration, this decides how many individual
        % cell data to print out
        if strcmpi(cellConfig, "series") || strcmpi(cellConfig, "SerPar")
            numCells_Print = numCells_Ser;
        elseif strcmpi(cellConfig, "parallel")
            numCells_Print = numCells_Par;
        else
            numCells_Print = 1;
        end

            
        for cellPrintInd = 1:numCells_Print           
%             Bstr = Bstr + sprintf("Volt(" + cellPrintInd + ", :) = %.2fV\t\t", testData.cellVolt(end, cellPrintInd));
            Bstr = Bstr + sprintf("Volt(" + cellPrintInd + ", :) = %.2fV\t\t", testData.cellVolt(end, cellPrintInd));
            Bstr = Bstr + sprintf("Curr(" + cellPrintInd + ", :) = %.2fA\t\t", testData.cellCurr(end, cellPrintInd));
            Bstr = Bstr + sprintf("SOC(" + cellPrintInd + ", :) = %.2f\t\t",    testData.cellSOC(end, cellPrintInd)*100);
            Bstr = Bstr + sprintf("Ah(" + cellPrintInd + ", :) = %.3f Ah\t\t",  testData.cellCap(end, cellPrintInd));
            Bstr = Bstr + newline;
        end

        Bstr = Bstr + sprintf("\nPack Volt = %.4f V\tPack Curr = %.4f A\n" + ...
                "Pack SOC = %.2f \t\tPack AH = %.3f\n\n", testData.packVolt(end, :), testData.packCurr(end, :),...
                testData.packSOC(end, :)*100, testData.packCap(end, :));
        fprintf(Tstr + newline);
        fprintf(Bstr);
    end
end
