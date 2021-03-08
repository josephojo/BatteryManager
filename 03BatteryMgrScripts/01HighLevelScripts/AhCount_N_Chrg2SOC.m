
battID = "AB6";
testSettings.tempChnls = [9, 11];


ahCount_cRates = [0.4, 0.3];

chrgCurr = 1.2;

%% Count the Charge in the cell

ahCount = AhCounter('cRates', ahCount_cRates, 'battID', battID, 'waitTime', 900,...
'testSettings', testSettings);

%% After Counting the cell charge, charge the cell to specified SOC
targetSOC = 0.12; % 0.18; % 0.2; % 0.15; % 

[testData, metadata, testSettings] = chargeToSOC(targetSOC, chrgCurr, 'battID', battID, 'testSettings', testSettings);