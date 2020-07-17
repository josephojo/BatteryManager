
% Check if data is available to save in order to avoid data loss
if exist('battTS', 'var') && ~isempty(battTS.time)
    if battTS.time(end) > 60
        save(dataLocation + "script_DataBackup.mat", 'battTS', '-append');
    end
end
if exist('ahCounts', 'var') && ~isempty(ahCounts)
    save(dataLocation + "script_DataBackup.mat", 'ahCounts', '-append');
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