
try
%THERMOCOUPLE MODULE
%##########################################################################
thermo = modbus('serialrtu','COM5','Timeout',10); % Initializes a Modbus
%protocol object using serial RTU interface connecting to COM5 and a Time
%out of 10s.
thermo.BaudRate = 38400;
%--------------------------------------------------------------------------

cellID = "AA6"; % ID in Cell Part Number (e.g BAT11-FEP-AA1). Defined again in initializeVariables

% FILE
%##########################################################################
dataLocation = "C:\Users\User\Documents\Projects\03ThermalFaultDetection\03DataGen\01CommonDataForBattery\";
dateStringFile = cellstr(datetime('now', 'Format', 'yyMMdd-HH_mm'));
filePath = dataLocation +cellID+"_TcData_" + dateStringFile + ".xlsx";

% if isfile(fileName)
%     % If File exists. append new data to it
%     fileID = fopen(fileName, 'at+');
% else
%     % File does not exist. Create new one and add the top row
%     fileID = fopen(fileName, 'at+');
%     fprintf(fileID,"%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n", "Date", ...
%         "Time", "Ambient Temp", "Surface Temp", "Core Temp");
% end
% -------------------------------------------------------------------------


tic;
readPeriod = 1; % in seconds
tempData = [];
prev = toc;
prev2 = toc;

Date = {};
Time = {};
DateTime = {};
AmbientTemp = [];
% SurfTempAA7 = [];
SurfTempAA6 = [];
SurfTempAA5 = [];

thermoData = read(thermo,'holdingregs',9,4);

while true %toc - prev < 70884 % 19.69 hrs (1.1 safety limit)
    if toc(testTimer) - prev2 >= readPeriod
        prev2 = toc(testTimer);
        %Measure Data from thermometer. Using holdingregs function (03), read data
        %from 3 registers starting at register 9
        thermoData = read(thermo,'holdingregs',9,4);
        
        dateString = datestr(datetime);
        dateTime = strsplit(dateString, ' ');
        
%         Date{end+1,1} =  dateTime(1,1);
%         Time{end+1,1} =  dateTime(1,2);
        Date{end+1,1} =  [string(dateTime(1,1))];
        Time{end+1,1} =  [string(dateTime(1,2))];
        DateTime{end+1, 1} = dateString;
        AmbientTemp(end+1,1) = thermoData(1)/10;
        SurfTempAA5(end+1,1) = thermoData(2)/10;
        SurfTempAA6(end+1,1) = thermoData(3)/10;
        
        dt = sprintf("%s : %s, Duration: %.0f s",dateTime{1}, dateTime{2}, (toc - prev));
        Tstr = sprintf("TC Amb = %.1f ºC\tTC AA5 = %.1f ºC\tTC AA6 = %.1f ºC" ,... % \tTC AA6 = %.1f ºC
            thermoData(1)/10, thermoData(2)/10, thermoData(3)/10); %, thermoData(4)/10);
        fprintf(dt + newline + Tstr + newline + newline);
    end
end

%% Finish up
T = table(Date, Time, DateTime, AmbientTemp, SurfTempAA5, SurfTempAA6);%, SurfTempAA5);
writetable(T, filePath);
% type(filePath)

%% Clean up
if exist('thermo','var')
    clear thermo;
    disp("Device Reset");
end

catch ME
    
    if exist('thermo','var')
        clear thermo;
        disp("Device Reset");
    end
    rethrow(ME);
end