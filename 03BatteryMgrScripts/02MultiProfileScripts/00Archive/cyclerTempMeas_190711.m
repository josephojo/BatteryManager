
try
%THERMOCOUPLE MODULE
%##########################################################################
thermo = modbus('serialrtu','COM5','Timeout',10); % Initializes a Modbus
%protocol object using serial RTU interface connecting to COM6 and a Time
%out of 10s.
thermo.BaudRate = 38400;
%--------------------------------------------------------------------------

% FILE
%##########################################################################
dataLocation = "C:\Users\User\Documents\Projects\01CoreTempEst\03TrainingDataGeneration\01CommonDataForBattery\";
dateString = cellstr(datetime('now', 'Format', 'yyMMdd-HH_mm'));
filePath = dataLocation + "016TempData_" + dateString + ".xlsx";

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
AmbientTemp = [];
SurfaceTemp = [];
CoreTemp = [];

thermoData = read(thermo,'holdingregs',9,3);

while true %toc - prev < 70884 % 19.69 hrs (1.1 safety limit)
    if toc - prev2 >= readPeriod
        prev2 = toc;
        %Measure Data from thermometer. Using holdingregs function (03), read data
        %from 3 registers starting at register 9
        thermoData = read(thermo,'holdingregs',9,3);
        
        dateString = datestr(datetime);
        dateTime = strsplit(dateString, ' ');
        
%         Date{end+1,1} =  dateTime(1,1);
%         Time{end+1,1} =  dateTime(1,2);
        Date{end+1,1} =  [string(dateTime(1,1))];
        Time{end+1,1} =  [string(dateTime(1,2))];
        AmbientTemp(end+1,1) = thermoData(1)/10;
        SurfaceTemp(end+1,1) = thermoData(2)/10;
        CoreTemp(end+1,1) = thermoData(3)/10;
        
        dt = sprintf("%s : %s, Duration: %.0f s",dateTime{1}, dateTime{2}, (toc - prev));
        Tstr = sprintf("TC 1 = %.1f ºC\t\t\tTC 2 = %.1f ºC\t\t\tTC 3 = %.1f ºC" ,thermoData(1)/10, thermoData(2)/10, thermoData(3)/10);
        fprintf(dt + newline + Tstr + newline + newline);
    end
end

%% Finish up
T = table(Date, Time, AmbientTemp, SurfaceTemp, CoreTemp);
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