
cellID = "AB6";
testSettings.tempChnls = [9, 11];


ahCount_cRates = [0.4, 0.3];

chrgCurr = 1.2;
targetSOC = 0.12; % 0.18; % 0.2; % 0.15; % 

%% Count the Charge in the cell

ahCount = AhCounter('cRates', ahCount_cRates, 'cellIDs', cellID, 'waitTime', 900,...
'testSettings', testSettings);

%% After Counting the cell charge, charge the cell to specified SOC

battTS_Chrg = chargeToSOC(targetSOC, chrgCurr, 'cellIDs', cellID, 'testSettings', testSettings);