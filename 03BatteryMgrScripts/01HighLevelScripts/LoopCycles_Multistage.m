%% Battery Parameters

battID = 'test123'; %Need to add the battery to 007BatteryParam file
ard = arduino; %Connection to the arduino board
ardChnls = [1 2 3 4];

waitTime = 300; %Cooldown period in seconds (5min)

newStr = extractBetween(path,"",...
               "NewFolder","Boundaries","inclusive");
dataLocation = newStr + "\Battery_data\";  %%Changed this to a seperate folder to store data
dateStr = string(datetime('now', 'Format','yyMMdd_HHmm'));
metadata.startDate = string(datetime('now', 'Format','yyMMdd'));
metadata.startTime = string(datetime('now', 'Format','HHmm'));

testSettings.saveDir = dataLocation;
testSettings.saveName = "test123_" + dateStr,  'metadata', '-append';
testSettings.tempChnls = [1, 2, 3, 4];

currFilePath = mfilename('fullpath');
[path, filename, ~] = fileparts(currFilePath);

load(dataLocation + "007BatteryParam.mat");
CAP = batteryParam.ratedCapacity(battID); %Need this to not change throughout cycles so used ratedCapacity instead

    %% Looping Cycles
for i = range(1:50)
    cycle = i;
    % Discharge
    % Discharging stage [0.5C]
    msg = newline + 'Cycle ' + i ' : Discharging to 10%'; disp(msg);
    battDischrg = dischargeToSOC(0.1, 0.5*CAP, 'battID', battID', 'testSettings', testSettings);
    saveTestData(testData, metadata, testSettings, filename);
    
    % Wait 
    msg = newline + 'Cycle ' + i ' : Waiting for ' + waitTime + ' seconds for cooldown'; disp(msg);
    battWait = waitTillTime(waitTime, 'battID', battID, 'testSettings', testSettings);
    saveTestData(testData, metadata, testSettings, filename);

    % Charge
    %First charging stage [-2C]
    msg = newline + 'Cycle ' + i ' : Charging to cutoff voltage of 3.5 V at 2C'; disp(msg);
    battCharg = chargeToVolt(3.5, 2*CAP, 'battID', battID, 'testSettings', testSettings);
    saveTestData(testData, metadata, testSettings, filename);

    % Second charging stage [-1.2C]
    msg = newline + 'Cycle ' + i ' : Charging to cutoff voltage of 3.5 V at 1.2C'; disp(msg);
    battCharg = chargeToVolt(3.5, 1.2*CAP, 'battID', battID, 'testSettings', testSettings);
    saveTestData(testData, metadata, testSettings, filename);

    % Third charging stage [-0.8C]
    msg = newline + 'Cycle ' + i ' : Charging to SOC of 90% at 0.8C'; disp(msg);
    battCharg = chargeToSOC(0.9, 0.8*CAP, 'battID', battID, 'testSettings', testSettings);
    saveTestData(testData, metadata, testSettings, filename);

    % Wait 
    msg = newline + 'Cycle ' + i ' : Waiting for ' + waitTime + ' seconds for cooldown'; disp(msg);
    battWait = waitTillTime(waitTime, 'battID', battID, 'testSettings', testSettings);
    saveTestData(testData, metadata, testSettings, filename);
end
