function saveBattData(testData, metadata, testSettings, testName)
%SAVEBATTDATA Summary of this function goes here
%   Detailed explanation goes here


metadata.endDate = string(datetime('now', 'Format','yyMMdd'));
metadata.endTime = string(datetime('now', 'Format','HHmm'));

if testData.time(end) > 5 
        save(testSettings.dataLocation + "006_" + metadata.battID + "_" + testName + ".mat", 'testData', 'metadata');
end

disp(newline + "Data saved to ..\01CommonDataForBattery" + newline);
end

