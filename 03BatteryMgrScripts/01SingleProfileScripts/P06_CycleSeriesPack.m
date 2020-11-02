cellIDs = ["AB1", "AB4", "AB5", "AB6"];

waitTime = 600; % wait time for cool down periods in seconds (10 mins)
if ~exist('caller', 'var')
    caller = "cmdWindow";
end

testSettings.cellConfig = "series";
testSettings.tempChnls = 9:13;

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

cRates = [1, 0]; % [Discharge, Charge]. 0 C-Rate here signifies fast charge algorithm
numCyles = 100;

% save(dataLocation + "001Cycle3Times_"+dateStr,...
%     "cRates", "CAP", "metadata");

%% Cycle 1
% Charge Stage
msg = newline + "Cycle 1: Discharging to 0%. NextUp: Cycle 1 Cool Down A.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end
battTS_Dchrg_1 = dischargeToSOC(0, cRates(1, 1)*CAP, 'cellIDs', cellIDs, 'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_Dchrg_1", '-append');

% Wait A
msg = newline + "Cycle 1: Waiting for "+ waitTime + " seconds. NextUp: Cycle 1 Charge.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end    
battTS_wait_1A = waitTillTime(waitTime, 'cellIDs', cellIDs,...
    'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_wait_1A", '-append');

% % Discharge Stage
msg = newline + "Cycle 1: Charging to 100%. NextUp: Cycle 1 Cool Down B";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end
battTS_Chrg_1 = chargeToSOC(1, cRates(1, 2)*CAP, 'cellIDs', cellIDs, 'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_Chrg_1", '-append');

% Wait B
msg = newline + "Cycle 1: Waiting for "+ waitTime + " seconds. NextUp: Cycle 2.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end    
battTS_wait_1B = waitTillTime(waitTime, 'cellIDs', cellIDs,...
    'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_wait_1B", '-append');


% Get Current File name
[~, filename, ~] = fileparts(mfilename('fullpath'));
% Save data
saveBattData(battTS, metadata, testSettings, cells, filename);

metadata.endDate = string(datetime('now', 'Format','yyMMdd'));
metadata.endTime = string(datetime('now', 'Format','HHmm'));

save(dataLocation + "001Cycle3Times_"+dateStr,  "metadata", '-append');
