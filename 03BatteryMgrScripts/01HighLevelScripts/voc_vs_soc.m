
% voc_vs_soc; %Run Script to collect OCV and SOC signals for Equivalent
% Circuit Models
%  Test should be done in about 25°C temp

%%
currFilePath = mfilename('fullpath');
% Seperates the path directory and the filename
[path, filename, ~] = fileparts(currFilePath);

newStr = extractBefore(path, "03BatteryMgrScripts");

dataLocation = newStr + "01CommonDataForBattery\";


%% Parameters

% Load Table with cell information
load(dataLocation + "007BatteryParam.mat", 'batteryParam')

% Set specific test data
battID = "AB1";
testSettings.tempChnls = [9, 10];
waitTime = 1800;

chargeVolt = batteryParam.chargedVolt(battID);
dischargeVolt = batteryParam.dischargedVolt(battID);

cRate = 1/30; % Run at C/30
ratedCap = batteryParam.capacity(battID); % Ah
chargeCurr = cRate * ratedCap;
dischargeCurr = -(cRate * ratedCap);

%% Begin Test
% Bring the cell to ful charge.
testData = chargeToSOC(1, 0.3*ratedCap, 'battIDs', battID, 'testSettings', testSettings);

testData_Wait_Chrg = waitTillTime(waitTime, 'battIDs', battID, 'testSettings', testSettings);
testData = appendTestDataStruts(testData, testData_Wait_Chrg);

% Discharge at same (more or less constant temperature)
testData_dchrg = dischargeToVolt(dischargeVolt, dischargeCurr,  'battIDs', battID,...
    'testSettings', testSettings); % Discharge to lowest voltage 
testData = appendTestDataStruts(testData, testData_dchrg);
save(dataLocation + "008OCV_" + battID + ".mat",'testData', 'testData_dchrg'); % ,'-append');

testData_Wait_dchrg = waitTillTime(waitTime, 'battIDs', battID, 'testSettings', testSettings);
testData = appendTestDataStruts(testData, testData_Wait_dchrg);
save(dataLocation + "008OCV_" + battID + ".mat",'testData', 'testData_Wait_dchrg','-append');

% Charge at same (more or less constant temperature)
testData_chrg = chargeToVolt(chargeVolt, chargeCurr,  'battIDs', battID,...
    'testSettings', testSettings);
testData = appendTestDataStruts(testData, testData_chrg);
save(dataLocation + "008OCV_" + battID + ".mat",'testData', 'testData_chrg','-append');


% ocv_OCV = testData.Data(:,1);
% ocv_SOC = testData.Data(:,3);

% save(dataLocation + "008OCV_" + battID + ".mat", 'ocv_OCV', 'ocv_SOC','-append');
