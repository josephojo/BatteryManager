%% Battery Parameters

battID = 'AD6'; %Need to add the battery to 007BatteryParam file
waitTime = 500; %Cooldown period in seconds (5min)

newStr = 'C:\Users\Linlab\Documents\00BattManager\03DataGen\01CommonDataForBattery\';
dataLocation = newStr + "BatteryData"; 
dateStr = string(datetime('now', 'Format','yyMMdd_HHmm'));
metadata.startDate = string(datetime('now', 'Format','yyMMdd'));
metadata.startTime = string(datetime('now', 'Format','HHmm'));

testSettings.saveDir = dataLocation;
testSettings.saveName = "AD6" + dateStr,  'metadata', '-append';
testSettings.tempChnls = [9, 10, 11, 12, 13];

currFilePath = mfilename('fullpath');
[path, filename, ~] = fileparts(currFilePath);

load(newStr + "007BatteryParam.mat");
CAP = batteryParam.ratedCapacity(battID); 

script_resetDevices

    %% Looping Cycles
for i = drange(1:50)
    
    % Discharge
    % Discharging stage [0.5C]
    disp(['Cycle ', num2str(i),': Discharging to 0% at 0.5C'])
    battDischrg = dischargeToSOC(0, 0.5*CAP, 'battID', battID, 'testSettings', testSettings);
    if i == 1
       save("DischrgCycles", 'battDischrg');
    else
       save("DischrgCycles", 'battDischrg', '-append');
    end
    
    % Wait 1
    disp(['Cycle ', num2str(i),': Waiting for ', num2str(waitTime), ' seconds for cooldown'])
    battWait = waitTillTime(waitTime, 'battID', battID, 'testSettings', testSettings);
    if i == 1
       save("Wait1Cycles", 'battWait');
    else
       save("Wait1Cycles", 'battWait', '-append');
    end

    % Charge
    % First charging stage [-2C]
    disp(['Cycle ', num2str(i),': Charging to cutoff voltage of 3.5V at 2C'])
    battCharg = chargeToVolt(4.2, 2*CAP, 'battID', battID, 'testSettings', testSettings);
    if i == 1
       save("Stg1Chrg", 'battCharg');
    else
       save("Stg1Chrg", 'battCharg', '-append');
    end
    
    % Second charging stage [-1.2C]
    disp(['Cycle ', num2str(i),': Charging to cutoff voltage of 3.5V at 1.2C'])
    battCharg = chargeToVolt(4.2, 1.2*CAP, 'battID', battID, 'testSettings', testSettings);
    if i == 1
       save("Stg2Chrg", 'battCharg');
    else
       save("Stg2Chrg", 'battCharg', '-append');
    end

    % Third charging stage [-0.8C]
    disp(['Cycle ', num2str(i),': Charging to SOC of 100% at 0.8C'])
    battCharg = chargeToSOC(1, 0.8*CAP, 'battID', battID, 'testSettings', testSettings);
    if i == 1
       save("Stg3Chrg", 'battCharg');
    else
       save("Stg3Chrg", 'battCharg', '-append');
    end
    
    % Wait 2
    disp(['Cycle ', num2str(i),': Waiting for ', num2str(waitTime), ' seconds for cooldown'])
    battWait = waitTillTime(waitTime, 'battID', battID, 'testSettings', testSettings);
    if i == 1
       save("Wait2Cycles", 'battWait');
    else
       save("Wait2Cycles", 'battWait', '-append');
    end
end
