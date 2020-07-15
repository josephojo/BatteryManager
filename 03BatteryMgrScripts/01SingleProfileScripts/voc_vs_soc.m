
% voc_vs_soc; %Run Script to collect OCV and SOC signals for Equivalent
% Circuit Models
%  Test should be done in about 25°C temp

%%
currFilePath = mfilename('fullpath');
% Seperates the path directory and the filename
[path, filename, ~] = fileparts(currFilePath);

newStr = extractBetween(path,"",...
               "03DataGen","Boundaries","inclusive");
dataLocation = newStr + "\01CommonDataForBattery\";


%% Parameters

% Load Table with cell information
load(dataLocation + "007BatteryParam.mat", 'batteryParam')

% Set specific test data
cellID = "AB1";
testSettings.tempChnls = [9, 10];
waitTime = 1800;

chargeVolt = batteryParam.chargedVolt(cellID);
dischargeVolt = batteryParam.dischargedVolt(cellID);

cRate = 1/30; % Run at C/30
ratedCap = batteryParam.capacity(cellID); % Ah
chargeCurr = cRate * ratedCap;
dischargeCurr = -(cRate * ratedCap);

%% Begin Test
% Bring the cell to ful charge.
battTS = chargeToSOC(1, 0.3*ratedCap, 'cellIDs', cellID, 'testSettings', testSettings);

battTS_Wait_Chrg = waitTillTime(waitTime, 'cellIDs', cellID, 'testSettings', testSettings);
battTS = appendBattTS2TS(battTS, battTS_Wait_Chrg);

% Discharge at same (more or less constant temperature)
battTS_dchrg = dischargeToVolt(dischargeVolt, dischargeCurr,  'cellIDs', cellID,...
    'testSettings', testSettings); % Discharge to lowest voltage 
battTS = appendBattTS2TS(battTS, battTS_dchrg);
save(dataLocation + "008OCV_" + cellID + ".mat",'battTS', 'battTS_dchrg'); % ,'-append');

battTS_Wait_dchrg = waitTillTime(waitTime, 'cellIDs', cellID, 'testSettings', testSettings);
battTS = appendBattTS2TS(battTS, battTS_Wait_dchrg);
save(dataLocation + "008OCV_" + cellID + ".mat",'battTS', 'battTS_Wait_dchrg','-append');

% Charge at same (more or less constant temperature)
battTS_chrg = chargeToVolt(chargeVolt, chargeCurr,  'cellIDs', cellID,...
    'testSettings', testSettings);
battTS = appendBattTS2TS(battTS, battTS_chrg);
save(dataLocation + "008OCV_" + cellID + ".mat",'battTS', 'battTS_chrg','-append');


% ocv_OCV = battTS.Data(:,1);
% ocv_SOC = battTS.Data(:,3);

% save(dataLocation + "008OCV_" + cellID + ".mat", 'ocv_OCV', 'ocv_SOC','-append');
