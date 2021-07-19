

%% Initialize Variables and Devices
try
    if ~exist('battID', 'var') || isempty(battID)
        battID = ["AD0"]; % ID in Cell Part Number (e.g BAT11-FEP-AA1). Defined again in initializeVariables
    end
    
    if ~exist('caller', 'var')
        caller = "cmdWindow";
    end
    
    if ~exist('psuArgs', 'var')
        psuArgs = [];
        eloadArgs = [];
        tempModArgs = [];
        balArgs = [];
        sysMCUArgs = [];
        stackArgs = [];
    end
    
    if ~exist('testSettings', 'var') || isempty(testSettings)
        codeFilePath = mfilename('fullpath');
        % Seperates the path directory and the filename
        [codePath, codeFileName, ~] = fileparts(codeFilePath);
        
%         str = extractBetween(codePath,"",...
%             "00BattManager","Boundaries","inclusive");
        str = extractBefore(codePath, "03BatteryMgrScripts");
        testSettings.saveDir = str + "00ProjectData\" + extractBefore(codeFileName, 4) + "\";
        
        testSettings.cellConfig = "SerPar";
        testSettings.currMeasDev = "balancer";
        
        testSettings.saveName   = "00SP_HCFC_" + battID;
        testSettings.purpose    = "Test for the series stack health conscious charging algorithm";
        testSettings.tempChnls  = [9, 10, 11, 12, 13];
        testSettings.trigPins = []; % Find in every pin that should be triggered
        testSettings.trigInvert = []; % Fill in 1 for every pin that is reverse polarity (needs a zero to turn on)
        testSettings.trigStartTimes = {[100]}; % cell array of vectors. each vector corresponds to each the start times for each pin
        testSettings.trigDurations = {15}; % cell array of vectors. each vector corresponds to each the duration for each pin's trigger
    end
    
    script_initializeVariables; % Run Script to initialize common variables

    if ~exist('eventLog', 'var') || isempty(eventLog) || ~isvalid(eventLog)
        eventLog = EventLogger();
    end
    
    script_initializeDevices; % Run Script to initialize control devices
%     verbosity = 1; % Data measurements are fully displayed.
%     verbosity = 2; % Data measurements are not displayed since the results from the MPC will be.
    balBoard_num = 0; % ID for the main balancer board
    
    MAX_CELL_VOLT = batteryParam.maxVolt(battID)/numCells_Ser;
    MIN_CELL_VOLT = batteryParam.minVolt(battID)/numCells_Ser;

%     wait(2); % Wait for the EEprom Data to be updated

    % Set Balancer Voltage Thresholds
    bal.Set_OVUV_Threshold(MAX_CELL_VOLT(1, 1), MIN_CELL_VOLT(1, 1));
    wait(1);

catch ME
    script_handleException;
end   


%%


[testData, metadata, testSettings] = P06_SeriesPack_FC_HW(0.9, 5.4, "AD9", "eventLog", eventLog);

[testData, metadata, testSettings] = dischargeToSOC(0.4, 3.4, "AD9", "eventLog", eventLog);



%%
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

