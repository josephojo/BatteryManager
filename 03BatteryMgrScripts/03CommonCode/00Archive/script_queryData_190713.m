% Queries Data from devices and stores them in a collection in the 
% following format:
%           PSU Voltage, PSU Current, ELoad Voltage, ELoad Current, 
%       Battery Voltage, Battery Current, Battery State, BatterySOC
%       Ambient Temp, Surface Temp, Core Temp

script_avgLJMeas;

tElasped = toc - timerPrev(1);

%Measure Data from thermometer. Using holdingregs function (03), read data
%from 3 registers starting at register 9
thermoData = read(thermo,'holdingregs',9,3);

% Measure Data from PSU
psuData = psu.measureVoltCurr();

% Measure Data from ELoad
eloadData = eload.MeasureVoltCurr();

% psuData(1) = 0; psuData(2) = 0; 
% eloadData(1) = 0; eloadData(2) = 0; 
% thermoData(1) = 0; thermoData(2) = 0; thermoData(3) = 0;

%Finds avg of total voltages collected at batt terminals and current sensor
vBattp = ain2 / adcAvgCount;
vBattn = ain3 / adcAvgCount;
cSigP = ain0 / adcAvgCount; 
cSigN = ain1 / adcAvgCount; 
cSigP_N = round(cSigP - cSigN, 3); %4,'significant')+0.00;

battVolt = round(vBattp - vBattn + 0.01, 3);
battCurr = round(((cSigP_N - cSigMid)*10), 2); % 2.639)/5.288) * 52.28, 3); 

adcAvgCounter = 0; ain0 = 0; ain1 = 0; ain2 = 0; ain3 = 0;  v = 0;

% socCurr = 0.0;
% % Use Current from either PSU or ELOAD for Battery Current
% if strcmpi(battState, "discharging")
%     socCurr = curr; % ELoad set current and multimeter current are similar
% elseif strcmpi(battState, "charging")
%     socCurr = curr - 0.023; % PSU set current is higher than the multimeter current by 0.023
% elseif strcmpi(battState, "idle")
%     battCurr = 0.0;
%     socCurr = 0.0; % Set Current
% end
if strcmpi(battState, "idle")
    battCurr = 0.0;
end

tempT = toc;
deltaT = tempT - timerPrev(4);
timerPrev(4) = tempT; % Update Current time to previous
AhCap = AhCap + (abs(battCurr) * (deltaT/3600));
battSOC = estimateSOC(battCurr, deltaT, prevSOC, 'Q', coulombs); % Leave right after battCurr update since it is used in SOC estimation
% timerPrev(4) = toc; % Update Current time to previous
prevSOC = battSOC; % Update the current SOC as prev
% save(dataLocation + "prevSOC.mat", 'prevSOC');  
batteryParam.soc(cellID) = prevSOC;

data = [psuData(1),psuData(2),eloadData(1),eloadData(2),battVolt, battCurr,...
    battSOC, thermoData(1)/10, thermoData(2)/10, thermoData(3)/10];

% data = [battVolt, battCurr, battSOC, AhCap, thermoData(1)/10, thermoData(2)/10];

battTS = addsample(battTS,'Data',data,'Time',tElasped);

% if toc - timerPrev(5) >= 2.2
%     timerPrev(5) = toc;
%     fprintf(".")
%     dotCounter = dotCounter + 1;
%     if dotCounter >= 55
        disp(newline + "ain0 / adcAvgCount = " + num2str(cSigP_N))
        disp(num2str(tElasped,'%.2f') + " seconds");
        Tstr = sprintf("TC 1 = %.1f ºC\t\t\tTC 2 = %.1f ºC\t\t\tTC 3 = %.1f ºC" ,thermoData(1)/10, thermoData(2)/10, thermoData(3)/10);
        Bstr = sprintf("Batt Volt = %.4f V\tBatt Curr = %.4f A\nBatt SOC = %.2f \t\tBatt AH = %.3f Ah", battVolt, battCurr, battSOC*100, AhCap);
        Dstr = sprintf("PSU Volt = %.4f V\t\tPSU Curr = %.4f A\nELoad Volt = %.4f V\tELoad Curr = %.4f A\n\n", psuData(1), psuData(2), eloadData(1), eloadData(2));
        fprintf(Tstr + newline);
        fprintf(Bstr + newline);
        fprintf(Dstr);
%         dotCounter = 0;
%     end
% end

% if toc - timerPrev(5) >= 2.2
%     timerPrev(5) = toc;
%     fprintf(".")
%     dotCounter = dotCounter + 1;
%     if dotCounter >= 55
%         disp(newline + "ain0 / adcAvgCount = " + num2str(cSigP_N))
%         disp(num2str(tElasped,'%.2f') + " seconds");
%         Tstr = sprintf("TC 1 = %.1f ºC\t\t\tTC 2 = %.1f ºC\t\t\tTC 3 = %.1f ºC" ,thermoData(1)/10, thermoData(2)/10, thermoData(3)/10);
%         Bstr = sprintf("Batt Volt = %.4f V\t\tBatt Curr = %.4f A\tBatt SOC = %.2f\nBatt AH = %.3f\n\n", battVolt, battCurr, battSOC*100, AhCap);
%         fprintf(Tstr + newline);
%         fprintf(Bstr);
%         dotCounter = 0;
%     end
% end
