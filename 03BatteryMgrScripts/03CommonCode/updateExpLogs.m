function updateExpLogs(Filename, Purpose, cellIDs, batteryParam)
% updateExpLogs Update Experiment Logs File
%%
currFilePath = mfilename('fullpath');
% Seperates the path directory and the filename
[path, ~, ~] = fileparts(currFilePath);

saveLocation = extractBetween(path,"",...
    "00BattManager","Boundaries","inclusive");

%%

DateCompleted = string(datestr(now,'yymmdd'));
TimeCompleted = string(datestr(now,'HHMM'));

T = readtable(saveLocation + "ExperimentLogs.xlsx");

BatteryChem = batteryParam.chemistry(cellIDs(1));
capacityLeft = batteryParam.capacity(cellIDs);

numCells = length(cellIDs);

CellIDs = ""; CapacityLeft = "";
for i = 1:numCells
    if i ~= 1
        CellIDs = CellIDs + ", ";
        CapacityLeft = CapacityLeft + ", ";
    end
    CellIDs = CellIDs + cellIDs(i);
    CapacityLeft = CapacityLeft + capacityLeft(i);
end
Tnew = table(Purpose,Filename,CellIDs,DateCompleted,TimeCompleted,...
    BatteryChem, CapacityLeft);

T = [T;Tnew];

writetable(T, saveLocation + "ExperimentLogs.xlsx",'Sheet',1,'Range','A1')

disp("Experiment Log Updated");

end