
% validateSOC; %Run Script to validate SOC value to have a point to start SOC estimation
% 

cRate = 1/30; % Run at C/30
ratedCap = 3.1031; % Ah
chargeCurr = cRate * ratedCap;
dischargeCurr = -(cRate * ratedCap);
testSettings.tempChnls = [9, 10];


% Charge at about 25°C
battTS = chargeToSOC(1, 2*ratedCap, 'cellIDs', "AB1", 'testSettings', testSettings);

battTS_Wait = waitTillTime(1200, 'cellIDs', "AB1", 'testSettings', testSettings);
battTS = appendBattTS2TS(battTS, battTS_Wait);

% Discharge at same (more or less constant temperature)
battTS_dsChrg = dischargeToSOC(0, dischargeCurr,  'cellIDs', "AB1",...
    'testSettings', testSettings); % Discharge to 0% SOC
battTS = appendBattTS2TS(battTS, battTS_dsChrg);

battTS_Wait = waitTillTime(1200, 'cellIDs', "AB1", 'testSettings', testSettings);
battTS = appendBattTS2TS(battTS, battTS_Wait);

% Charge at same (more or less constant temperature)
battTS_chrg = chargeToSOC(1, chargeCurr,  'cellIDs', "AB1",...
    'testSettings', testSettings);
battTS = appendBattTS2TS(battTS, battTS_chrg);

save(dataLocation + "008OCV_AB1.mat", 'battTS');

ocv_OCV = battTS.Data(:,1);
ocv_SOC = battTS.Data(:,3);

save(dataLocation + "008VOC_vs_SOC.mat", 'ocv_OCV', 'ocv_SOC');
