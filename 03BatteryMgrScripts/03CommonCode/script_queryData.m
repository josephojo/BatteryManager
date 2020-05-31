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

coreInd = [];

if numThermo ~= 0
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
    %Measure Data from thermometer. Using holdingregs function (03), read data
    %from 3 registers starting at register 9
    % thermoData = read(thermo,'holdingregs',9,3);
    %     numCh = 2;
    thermoData = read(thermo,'holdingregs',firstTCchnl,numThermo);
    for i = 1:numThermo
        thermoData(i) = thermoData(i)/10;
    end
    % Index of TC connections starting from "firstTCchnl"
    ambInd = [1];
    surfInd = [2];
    coreInd = [];
    
    ambTemp = thermoData(ambInd);
    cells.surfTemp(cellIDs) = thermoData(surfInd);
    if ~isempty(coreInd)
        cells.coreTemp(cellIDs) = thermoData(coreInd);
    end
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

script_avgLJMeas;

% %Finds avg of total voltages collected at batt terminals and current sensor
vBattp = ain2 / adcAvgCount;
vBattn = ain3 / adcAvgCount;
if strcmp(cellConfig, 'single') ~= true
    cSigP1 = ain0 / adcAvgCount; % First Current Sensor (+ve term volt meas)
    cSigN1 = ain7 / adcAvgCount; % First Current Sensor (-ve term volt meas)
    cSigP_N1 = round(cSigP1 - cSigN1, 4); %4,'significant')+0.00;
    cSigP2 = ain1 / adcAvgCount; % Second Current Sensor (+ve term volt meas)
    cSigN2 = ain7 / adcAvgCount; % Second Current Sensor (-ve term volt meas)
    cSigP_N2 = round(cSigP2 - cSigN2, 4); %4,'significant')+0.00;
end

adcAvgCounter = 0; ain0 = 0; ain1 = 0; ain2 = 0; ain3 = 0;  ain7 = 0;

% Use Current Data from either PSU or ELOAD for Battery current
if strcmpi(battState, "discharging")
    battCurr = -eload.MeasureCurr();
elseif strcmpi(battState, "charging")
    battCurr = psu.measureCurr();
elseif strcmpi(battState, "idle")
    battCurr = 0.0;
end

battVolt = round(vBattp - vBattn + 0.01, 3);
% Get cell measurements if available
if strcmpi(cellConfig, 'series')
    % Implementation coming soon.
else
    cells.volt(cellIDs) = battVolt; % Assign stack voltage to individual voltage
end

if strcmpi(battState, "idle")
    cells.curr(cellIDs) = 0;
else
    if strcmp(cellConfig, 'single') ~= true
        cells.curr(cellIDs) = [(cSigP_N1 - 2.4902)/0.1, (cSigP_N2 - 2.5132)/0.1]; % Sensor Sensitivity = 100mV/A
    else
        cells.curr(cellIDs) = battCurr;
    end
end

tempT = toc(testTimer);
deltaT = tempT - timerPrev(4);
timerPrev(4) = tempT; % Update Current time to previous
cells.AhCap(cellIDs) = cells.AhCap(cellIDs) + (abs(cells.curr(cellIDs)) * (deltaT/3600));
AhCap = AhCap + (abs(battCurr) * (deltaT/3600));

cells.SOC(cellIDs) = estimateSOC(cells.curr(cellIDs),...
    deltaT, cells.prevSOC(cellIDs), 'Q', cells.coulomb(cellIDs)); % Leave right after cell curr update since it is used in SOC estimation
battSOC = estimateSOC(battCurr, deltaT, prevSOC, 'Q', coulombs); % Leave right after battCurr update since it is used in SOC estimation

cells.prevSOC(cellIDs) = cells.SOC(cellIDs); % Update the current cell SOC as prev
prevSOC = battSOC; % Update the current SOC as prev

% Store the SOC of the pack in for both cells in the stack
batteryParam.soc(cellIDs) = cells.SOC(cellIDs); 


data = [battVolt, battCurr, battSOC, AhCap,...
            cells.curr(cellIDs)', cells.SOC(cellIDs)',cells.AhCap(cellIDs)',...
            ambTemp, cells.surfTemp(cellIDs)', ...
            cells.coreTemp(cellIDs)'];


battTS = addsample(battTS,'Data',data,'Time',tElasped);

if caller == "gui"
    battData.Data = data;
    battData.Time = tElasped;
    send(dataQ, battData);
end

if verbose == 0
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
            Bstr = "";
            for cellID = cellIDs
                Tstr = Tstr + sprintf("Ta " + cellID + " = %.2f ºC\t\t", ambTemp);
                Tstr = Tstr + sprintf("Ts " + cellID + " = %.2f ºC\t\t", cells.surfTemp(cellID));
                if isempty(coreInd)
                    Tstr = Tstr + sprintf("Tc " + cellID + " = %.2f ºC\t", cells.coreTemp(cellID));
                end
                
                Bstr = Bstr + sprintf("Curr " + cellID + " = %.2f A\t\t", cells.curr(cellID));
                Bstr = Bstr + sprintf("SOC " + cellID + " = %.2f \t\t", cells.SOC(cellID)*100);
                Bstr = Bstr + sprintf("Ah " + cellID + " = %.3f Ah\t", cells.AhCap(cellID));
                Bstr = Bstr + newline;
                Tstr = Tstr + newline;
            end

            Bstr = Bstr + sprintf("\nBatt Volt = %.4f V\tBatt Curr = %.4f A\n" + ...
                "Batt SOC = %.2f \t\tBatt AH = %.3f\n\n", battVolt, battCurr,...
                battSOC*100, AhCap);
            fprintf(Tstr + newline);
            fprintf(Bstr);
            dotCounter = 0;
        end
%     end
elseif verbose == 1
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
    Bstr = "";
    for cellID = cellIDs
        Tstr = Tstr + sprintf("Ta " + cellID + " = %.2f ºC\t\t", ambTemp);
        Tstr = Tstr + sprintf("Ts " + cellID + " = %.2f ºC\t\t", cells.surfTemp(cellID));
        if isempty(coreInd)
            Tstr = Tstr + sprintf("Tc " + cellID + " = %.2f ºC\t", cells.coreTemp(cellID));
        end
        
        Bstr = Bstr + sprintf("Curr " + cellID + " = %.2f A\t\t", cells.curr(cellID));
        Bstr = Bstr + sprintf("SOC " + cellID + " = %.2f \t\t", cells.SOC(cellID)*100);
        Bstr = Bstr + sprintf("Ah " + cellID + " = %.3f Ah\t", cells.AhCap(cellID));
        Bstr = Bstr + newline;
        Tstr = Tstr + newline;
    end
        
    Bstr = Bstr + sprintf("\nBatt Volt = %.4f V\tBatt Curr = %.4f A\n" + ...
        "Batt SOC = %.2f \t\tBatt AH = %.3f\n\n", battVolt, battCurr,...
        battSOC*100, AhCap);
    
    fprintf(Tstr + newline);
    fprintf(Bstr);
end
