battID = "AB1";

waitTime = 900; % wait time for cool down periods in seconds (15 mins)
if ~exist('caller', 'var')
    caller = "cmdWindow";
end

testSettings.cellConfig = "single";
testSettings.tempChnls = [9, 10];

currFilePath = mfilename('fullpath');
% Seperates the path directory and the filename
[path, filename, ~] = fileparts(currFilePath);
newStr = extractBetween(path,"",...
               "03DataGen","Boundaries","inclusive");
dataLocation = newStr + "\01CommonDataForBattery\";

load(dataLocation + "007BatteryParam.mat");
CAP = batteryParam.capacity(battID);

dateStr = string(datetime('now', 'Format','yyMMdd_HHmm'));
metadata.startDate = string(datetime('now', 'Format','yyMMdd'));
metadata.startTime = string(datetime('now', 'Format','HHmm'));

cRates = [0.4, 0.3;...
          1.5, 1.0;...
          3.0, 2.5]; % [Discharge, Charge]

% save(dataLocation + "001Cycle3Times_"+dateStr,...
%     "cRates", "CAP", "metadata");

%% Cycle 1
% Discharge Stage
msg = newline + "Cycle 1: Discharging to 0%. NextUp: Cycle 1 Cool Down A.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end
battTS_Dchrg_1 = dischargeToSOC(0, cRates(1, 1)*CAP, 'battID', battID, 'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_Dchrg_1", '-append');

% Wait A
msg = newline + "Cycle 1: Waiting for "+ waitTime + " seconds. NextUp: Cycle 1 Charge.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end    
battTS_wait_1A = waitTillTime(waitTime, 'battID', battID,...
    'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_wait_1A", '-append');

% Charge
msg = newline + "Cycle 1: Charging to 100%. NextUp: Cycle 1 Cool Down B";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end
battTS_Chrg_1 = chargeToSOC(1, cRates(1, 2)*CAP, 'battID', battID, 'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_Chrg_1", '-append');

% Wait B
msg = newline + "Cycle 1: Waiting for "+ waitTime + " seconds. NextUp: Cycle 2.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end    
battTS_wait_1B = waitTillTime(waitTime, 'battID', battID,...
    'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_wait_1B", '-append');

%% Cycle 2
% Discharge Stage
msg = newline + "Cycle 2: Discharging to 0%. NextUp: Cycle 2 Cool Down A.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end
battTS_Dchrg_2 = dischargeToSOC(0, cRates(2, 1)*CAP, 'battID', battID, 'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_Dchrg_2", '-append');

% Waiting Stage A
msg = newline + "Cycle 2: Waiting for "+ waitTime + " seconds. NextUp: Cycle 2 Charge.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end    
battTS_wait_2A = waitTillTime(waitTime, 'battID', battID,...
    'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_wait_2A", '-append');

% Charge Stage
msg = newline + "Cycle 2: Charging to 100%. NextUp: Cycle 2 Cool Down B.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end
battTS_Chrg_2 = chargeToSOC(1, cRates(2, 2)*CAP, 'battID', battID, 'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_Chrg_2", '-append');

% Waiting Stage B
msg = newline + "Cycle 2: Waiting for "+ waitTime + " seconds. NextUp: Cycle 3.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end    
battTS_wait_2B = waitTillTime(waitTime, 'battID', battID,...
    'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_wait_2B", '-append');


%% Cycle 3
% Discharge Stage
msg = newline + "Cycle 3: Discharging to 0%. NextUp: Cycle 3 Cool Down A.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end
battTS_Dchrg_3 = dischargeToSOC(0, cRates(3, 1)*CAP, 'battID', battID, 'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_Dchrg_3", '-append');

% Waiting Stage
msg = newline + "Cycle 3: Waiting for "+ waitTime + " seconds. NextUp: Cycle 3 Charge.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end    
battTS_wait_3A = waitTillTime(waitTime, 'battID', battID,...
    'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_wait_3A", '-append');

% Charge Stage
msg = newline + "Cycle 3: Charging to 100%. NextUp: Cycle 3 Cool Down B";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end
battTS_Chrg_3 = chargeToSOC(1, cRates(3, 2)*CAP, 'battID', battID, 'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_Chrg_3", '-append');

% Waiting Stage
msg = newline + "Cycle 3: Waiting for "+ waitTime + " seconds. NextUp: End of Cycle.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end    
battTS_wait_3B = waitTillTime(waitTime, 'battID', battID,...
    'testSettings', testSettings);
save(dataLocation + "001Cycle3Times_"+dateStr, "battTS_wait_3B", '-append');

% save(dataLocation + "001Cycle3Times_"+dateStr,...
%     "battTS_Dchrg_3", "battTS_Chrg_3", '-append');

metadata.endDate = string(datetime('now', 'Format','yyMMdd'));
metadata.endTime = string(datetime('now', 'Format','HHmm'));

save(dataLocation + "001Cycle3Times_"+dateStr,  "metadata", '-append');
