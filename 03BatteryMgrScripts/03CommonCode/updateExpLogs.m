function updateExpLogs(Filename, Purpose, battID, batteryParam)
% updateExpLogs Update Experiment Logs File
%%
currFilePath = mfilename('fullpath');
% Seperates the path directory and the filename
[filePath, ~, ~] = fileparts(currFilePath);

parentDir = extractBefore(filePath, "03BatteryMgrScripts");
% Go to one above the parent Dir
s = strsplit(parentDir, "\");
if strcmpi(s(end), "")
    saveLocation = strjoin(s(1:end-2), "\");
else
    saveLocation = strjoin(s(1:end-1), "\");
end

%%

DateCompleted = string(datestr(now,'yymmdd'));
TimeCompleted = string(datestr(now,'HHMM'));

T = readtable(saveLocation + "ExperimentLogs.xlsx");

BatteryChem = batteryParam.chemistry(battID(1));
capacityLeft = batteryParam.capacity(battID);

numCells = length(battID);

battID = ""; CapacityLeft = "";
for i = 1:numCells
    if i ~= 1
        battID = battID + ", ";
        CapacityLeft = CapacityLeft + ", ";
    end
    battID = battID + battID(i);
    CapacityLeft = CapacityLeft + capacityLeft(i);
end
Tnew = table(Purpose,Filename,battID,DateCompleted,TimeCompleted,...
    BatteryChem, CapacityLeft);

T = [T;Tnew];

writetable(T, saveLocation + "ExperimentLogs.xlsx",'Sheet',1,'Range','A1')

disp("Experiment Log Updated");

end