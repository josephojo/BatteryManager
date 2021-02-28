function [status, msg] = saveTestData(testData, metadata, testSettings, testName)
%SAVETESTDATA Saves Data from a recent test as well as metadata


metadata.endDate = string(datetime('now', 'Format','yyMMdd'));
metadata.endTime = string(datetime('now', 'Format','HHmm'));

if ~isfield(testSettings, "saveDir")
    testSettings.saveDir = testSettings.dataLocation;
else
    if ~exist(testSettings.saveDir, 'dir')
        % Create Save Folder
        [status, msg, ~] = mkdir(testSettings.saveDir);
    end
end

if testData.time(end) > 5 
    if nargin < 4 && isfield(testSettings, "saveName")
        save(testSettings.saveDir + testSettings.saveName + ".mat", ...
            'testData', 'metadata', 'testSettings');
    else
        save(testSettings.saveDir + "006_" + metadata.battID +...
            "_" + testName + ".mat", 'testData', 'metadata', 'testSettings');
    end
end

dirs = strsplit(testSettings.saveDir, "\");

disp(newline + "Data saved to ..\" + strjoin(dirs(end-3:end), "\") + newline);
end

