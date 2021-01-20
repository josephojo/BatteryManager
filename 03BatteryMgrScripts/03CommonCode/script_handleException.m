
% Check if data is available to save in order to avoid data loss
if exist('testData', 'var') && ~isempty(testData.time)
    if testData.time(end) > 60
        save(dataLocation + "script_DataBackup.mat", 'testData', 'metaData', '-append');
    end
end

if exist('resultCollection', 'var') && ~isempty(resultCollection)
    save(dataLocation + "script_DataBackup.mat", 'resultCollection', '-append');
end
    
script_resetDevices;
if caller == "cmdWindow"
    rethrow(ME);
else
    send(errorQ, ME)
end