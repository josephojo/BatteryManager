battID = "AD0_2";

waitTime = 1800; % wait time for cool down periods in seconds (30 mins)
if ~exist('caller', 'var')
    caller = "cmdWindow";
end

testSettings.tempChnls = [9, 10, 11, 12, 13];

currFilePath = mfilename('fullpath');
% Seperates the path directory and the filename
[path, filename, ~] = fileparts(currFilePath);
newStr = extractBetween(path,"",...
               "03DataGen","Boundaries","inclusive");
dataLocation = newStr + "\01CommonDataForBattery\";

load(dataLocation + "007BatteryParam.mat");
CAP = batteryParam.ratedCapacity(battID);
dschrgVolt = batteryParam.dischargedVolt(battID);
chrgVolt = batteryParam.chargedVolt(battID);

saveName = "001ModelingData_" + battID;

dateStr = string(datetime('now', 'Format','yyMMdd_HHmm'));
metadata.startDate = string(datetime('now', 'Format','yyMMdd'));
metadata.startTime = string(datetime('now', 'Format','HHmm'));

cRates = [1.0, 0.1;...
          1.0, 0.5;...
          1.0, 1.0;...
          1.0, 2.0]; % [Discharge, Charge]

save(dataLocation + saveName + "_" + dateStr, "cRates", "CAP", "metadata");

%% Cycle 
for i = 1:length(cRates(:, 1))
    
battData = struct;
    
% Discharge Stage
targetVolt = dschrgVolt;
msg = newline + "Cycle "+ i +": Discharging to " + targetVolt + "V. NextUp: Cycle "+ i +" Cool Down A.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end
battData.("Cyc_" + i).Dchrg = dischargeToVolt(targetVolt, cRates(i, 1)*CAP, 'battID', battID, 'testSettings', testSettings);
save(dataLocation + saveName + "_" + dateStr, '-struct', "battData", '-append');

% Wait A
msg = newline + "Cycle "+ i +": Waiting for "+ waitTime + " seconds. NextUp: Cycle "+ i +" Charge.";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end    
battData.("Cyc_" + i).wait_A = waitTillTime(waitTime, 'battID', battID,...
    'testSettings', testSettings);
save(dataLocation + saveName + "_" + dateStr, '-struct', "battData", '-append');

% Charge
targetVolt = chrgVolt;
msg = newline + "Cycle "+ i +": Charging to " + targetVolt + "V. NextUp: Cycle "+ i +" Cool Down B";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end
battData.("Cyc_" + i).Chrg = chargeToVolt(targetVolt, cRates(i, 2)*CAP, 'battID', battID, 'testSettings', testSettings);
save(dataLocation + saveName + "_" + dateStr, '-struct', "battData", '-append');

% Wait B
msg = newline + "Cycle "+ i +": Waiting for "+ waitTime + " seconds. NextUp: Cycle "+ i+1 +".";
if strcmpi(caller, "gui"), send(randQ, msg); else, disp(msg);end    
battData.("Cyc_" + i).wait_B = waitTillTime(waitTime, 'battID', battID,...
    'testSettings', testSettings);

save(dataLocation + saveName + "_" + dateStr, '-struct', "battData", '-append');

end

%% Save End MetaData
metadata.endDate = string(datetime('now', 'Format','yyMMdd'));
metadata.endTime = string(datetime('now', 'Format','HHmm'));

save(dataLocation + saveName + "_" + dateStr,  "metadata", '-append');
