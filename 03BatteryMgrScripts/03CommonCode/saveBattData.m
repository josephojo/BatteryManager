function saveBattData(battTS, metadata, testSettings, cellData_lastTS, testName)
%SAVEBATTDATA Summary of this function goes here
%   Detailed explanation goes here


metadata.endDate = string(datetime('now', 'Format','yyMMdd'));
metadata.endTime = string(datetime('now', 'Format','HHmm'));

if battTS.Time(end) > 5 
    if strcmpi(testSettings.cellConfig, "single")
        save(testSettings.dataLocation + "006_" + metadata.cellIDs(1) + "_" + testName + ".mat", 'battTS', 'metadata', 'cellData_lastTS');
    else
        save(testSettings.dataLocation + "006_" + metadata.packID + "_" + testName + ".mat", 'battTS', 'metadata', 'cellData_lastTS');
    end
end

disp(newline + "Data saved to ..\01CommonDataForBattery" + newline);
end

