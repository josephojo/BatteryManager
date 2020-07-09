
% validateSOC; %Run Script to validate SOC value to have a point to start SOC estimation
% 

currFilePath = mfilename('fullpath');
% Seperates the path directory and the filename
[path, filename, ~] = fileparts(currFilePath);

newStr = extractBetween(path,"",...
               "03DataGen","Boundaries","inclusive");
dataLocation = newStr + "\01CommonDataForBattery\";

cRate = 1/30; % Run at C/30
ratedCap = 3.178; % Ah
chargeCurr = cRate * ratedCap;
dischargeCurr = -(cRate * ratedCap);
testSettings.tempChnls = [9, 10];


% % Charge at about 25°C
% battTS = chargeToSOC(1, 2*ratedCap, 'cellIDs', "AB1", 'testSettings', testSettings);
% 
% battTS_Wait_Chrg = waitTillTime(1200, 'cellIDs', "AB1", 'testSettings', testSettings);
% battTS = appendBattTS2TS(battTS, battTS_Wait_Chrg);
% 
% % Discharge at same (more or less constant temperature)
% battTS_dchrg = dischargeToSOC(0, dischargeCurr,  'cellIDs', "AB1",...
%     'testSettings', testSettings); % Discharge to 0% SOC
% battTS = appendBattTS2TS(battTS, battTS_dchrg);
save(dataLocation + "008OCV_AB1.mat",'battTS', 'battTS_dchrg'); % ,'-append');

% battTS_Wait_dchrg = waitTillTime(1200, 'cellIDs', "AB1", 'testSettings', testSettings);
% battTS = appendBattTS2TS(battTS, battTS_Wait_dchrg);
% save(dataLocation + "008OCV_AB1.mat",'battTS', 'battTS_Wait_dchrg','-append');

% Charge at same (more or less constant temperature)
battTS_chrg = chargeToSOC(1, chargeCurr,  'cellIDs', "AB1",...
    'testSettings', testSettings);
battTS = appendBattTS2TS(battTS, battTS_chrg);
save(dataLocation + "008OCV_AB1.mat",'battTS', 'battTS_chrg','-append');


ocv_OCV = battTS.Data(:,1);
ocv_SOC = battTS.Data(:,3);

save(dataLocation + "008OCV_AB1.mat", 'ocv_OCV', 'ocv_SOC','-append');
