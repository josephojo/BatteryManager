% Queries Data from devices and stores them in a collection in the 
% following format:
%           PSU Voltage, PSU Current, ELoad Voltage, ELoad Current, 
%       Battery Voltage, Battery Current, Battery State, BatterySOC
%       Ambient Temp, Surface Temp, Core Temp

tElasped = toc - timerPrev(1); % timerPrev(2); %

% wait(0.15);

%Measure Data from thermometer. Using holdingregs function (03), read data
%from 3 registers starting at register 9
thermoData = read(thermo,'holdingregs',9,3);

% % i = toc;
% %Measure Data from PSU
% [psuData, psuMode] = psu.GetVoltCurrD();
% 
% %Measure Data from ELoad
% eloadData = eload.MeasureVoltCurr();

psuData(1) = 0; psuData(2) = 0; eloadData(1) = 0; eloadData(2) = 0; 


%Finds avg of total voltages collected at batt terminals and current sensor
vBattp = ain2 / adcAvgCount;
vBattn = ain3 / adcAvgCount;
cBattp = ain0 / adcAvgCount; 
cBattn = ain1 / adcAvgCount; 
% disp("ain0 / adcAvgCount = " + num2str(cBattp - cBattn))

% battVolt = eloadData(1); % Previous method for battery voltage through
                            % measurement from the ELoad
battVolt = round(vBattp - vBattn + 0.01, 3);
% disp("batt LJ Volt: " + num2str(vBattp - vBattn + 0.01)); % Displays measured Batt Voltage
% battCurr = round((((cBattp - cBattn - 0.007) - 2.592)/5.184) * 51.84, 3); % When Connected to arduino 
battCurr = round((((cBattp - cBattn) - 2.639)/5.28) * 52.28, 3); 

% battCurrAlt_ard = (((v/ adcAvgCount) - 2.5)/5) * 50; % Collects Current signal from arduino
% battCurrAlt = (36912 - ain0) * 50 / 65540; % Bit based conversion of
                                                % battery current
% ain(end+1) = (cBattp - cBattn);
% curr(end+1) = battCurrAlt;
% currArd(end+1) = battCurrAlt_ard;
% disp("batt LJ Curr: " + num2str(battCurrAlt));
% disp("batt LJ Curr Ard: " + num2str(battCurrAlt_ard));

adcAvgCounter = 0; ain0 = 0; ain1 = 0; ain2 = 0; ain3 = 0;  v = 0;


% % Use Current from either PSU or ELOAD for Battery Current
% if strcmpi(battState, "discharging")
%     battCurr =  -eloadData(2); % To imply discharge
% elseif strcmpi(battState, "charging")
%     battCurr =  psuData(2);
% elseif strcmpi(battState, "idle")
%     battCurr = 0.0;
% end

if strcmpi(battState, "idle")
    battCurr = 0.0;
end

deltaT = toc - timerPrev(4);
battSOC = estimateSOC(battCurr, deltaT, prevSOC, 'Q', coulombCount); % Leave right after battCurr update since it is used in SOC estimation
timerPrev(4) = toc; % Update Current time to previous
prevSOC = battSOC; % Update the current SOC as prev


data = [psuData(1),psuData(2),eloadData(1),eloadData(2),battVolt, battCurr,...
    battSOC, thermoData(1)/10, thermoData(2)/10, thermoData(3)/10];

battTS = addsample(battTS,'Data',data,'Time',tElasped);


disp(num2str(tElasped,'%.2f') + " seconds");
Pstr = sprintf("PSU Volt = %.3f V\t\tPSU Curr = %.3f A", psuData(1), psuData(2));
Estr = sprintf("ELoad Volt = %.3f V\tELoad Curr = %.3f A",  eloadData(1), eloadData(2));
Tstr = sprintf("TC 1 = %.1f ºC\t\t\tTC 2 = %.1f ºC\t\t\tTC 3 = %.1f ºC" ,thermoData(1)/10, thermoData(2)/10, thermoData(3)/10);
Bstr = sprintf("Batt Volt = %.3f V\t\tBatt Curr = %.3f A\tBatt SOC = %.2f\n\n", battVolt, battCurr, battSOC*100);
fprintf(Pstr + newline + Estr + newline + Tstr + newline + Bstr);
% duration = toc - i
%{
dateString = datestr(datetime);
dateTime = strsplit(dateString, ' ');

fprintf(fileID,"%s,%s,",dateTime{1}, dateTime{2});
fprintf(fileID,"%.1f,", tElasped);
fprintf(fileID,"%.3f,%.3f,%s,", psuData(1), psuData(2), psuMode);
fprintf(fileID,"%.3f,%.3f,",  eloadData(1), eloadData(2));
fprintf(fileID,"%.1f,%.1f,%.1f,",thermoData(1)/10, thermoData(2)/10, thermoData(3)/10);
fprintf(fileID,"%.3f,%s\n", battVolt, battState);
%}

