cellIDs = "AB6";
testSettings.cellConfig = "single";
testSettings.tempChnls = [9, 10];

currFilePath = mfilename('fullpath');
% Seperates the path directory and the filename
[path, filename, ~] = fileparts(currFilePath);
newStr = extractBetween(path,"",...
               "03DataGen","Boundaries","inclusive");
dataLocation = newStr + "\01CommonDataForBattery\";

load(dataLocation + "007BatteryParam.mat");
CAP = batteryParam.capacity(cellIDs);

dateStr = string(datetime('now', 'Format','yyMMdd_HHmm'));
metadata.startDate = string(datetime('now', 'Format','yyMMdd'));
metadata.startTime = string(datetime('now', 'Format','HHmm'));

cRates = [0.4, 0.3;...
          1.5, 1.0;...
          4.0, 3.0]; % [Discharge, Charge]

save(dataLocation + "001Cycle3Times_"+dateStr,...
    "cRates", "CAP", "metadata");

%% Cycle 1
battTS_Dchrg_1 = dischargeToSOC(0, cRates(1, 1)*CAP, 'cellIDs', cellIDs, 'testSettings', testSettings);
battTS_Chrg_1 = chargeToSOC(1, cRates(1, 2)*CAP, 'cellIDs', cellIDs, 'testSettings', testSettings);

save(dataLocation + "001Cycle3Times_"+dateStr,...
    "battTS_Dchrg_1", "battTS_Chrg_1", '-append');

%% Cycle 2
battTS_Dchrg_2 = dischargeToSOC(0, cRates(2, 1)*CAP, 'cellIDs', cellIDs, 'testSettings', testSettings);
battTS_Chrg_2 = chargeToSOC(1, cRates(2, 2)*CAP, 'cellIDs', cellIDs, 'testSettings', testSettings);

save(dataLocation + "001Cycle3Times_"+dateStr,...
    "battTS_Dchrg_2", "battTS_Chrg_2", '-append');

%% Cycle 3
battTS_Dchrg_3 = dischargeToSOC(0, cRates(3, 1)*CAP, 'cellIDs', cellIDs, 'testSettings', testSettings);
battTS_Chrg_3 = chargeToSOC(1, cRates(3, 2)*CAP, 'cellIDs', cellIDs, 'testSettings', testSettings);

save(dataLocation + "001Cycle3Times_"+dateStr,...
    "battTS_Dchrg_3", "battTS_Chrg_3", '-append');

metadata.endDate = string(datetime('now', 'Format','yyMMdd'));
metadata.endTime = string(datetime('now', 'Format','HHmm'));

save(dataLocation + "001Cycle3Times_"+dateStr,  "metadata", '-append');
