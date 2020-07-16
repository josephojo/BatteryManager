
% If the test time so far is more than 60 seconds worth, back up data
% so as to avoid data loss
if tElasped > 60
    if exists('battTS', 'var')
        save(dataLocation + "script_DataBackup.mat", 'battTS', '-append');
    end
    if exists('ahCounts', 'var')
        save(dataLocation + "script_DataBackup.mat", 'ahCounts', '-append');
    end
    if exists('resultCollection', 'var')
        save(dataLocation + "script_DataBackup.mat", 'resultCollection', '-append');
    end
end
    
script_resetDevices;
if caller == "cmdWindow"
    rethrow(MEX);
else
    send(errorQ, MEX)
end