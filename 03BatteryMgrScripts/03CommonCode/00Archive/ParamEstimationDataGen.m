waitTime = 0.5;
dataLocation = "C:\Users\User\Documents\Projects\01CoreTemperatureEstimation\03TrainingDataGeneration\01CommonDataForBattery\";
chargeToFull;

waitTillTemp;

dischargeTo(0.2, 10);

% wait(waitTime);
waitTillTemp;

chargeTo(1.0, 7.5);

% dis = load('005DischargeTo20%.mat');
chrg = load('004ChargeTo100%');

% chrg.battTS.Time(:,1) = chrg.battTS.Time(:,1) + dis.battTS.Time(end,1) + waitTime;

currTS = timeseries(chrg.battTS.Data(:,6),chrg.battTS.Time);
airTempTS = timeseries(chrg.battTS.Data(:,8)+ 273,chrg.battTS.Time); % Convert the temp values to Kelvin
surfTempTS = timeseries(chrg.battTS.Data(:,9)+ 273,chrg.battTS.Time);
coreTempTS = timeseries(chrg.battTS.Data(:,10)+ 273,chrg.battTS.Time);
socTS = timeseries(chrg.battTS.Data(:,7),chrg.battTS.Time);
battTS = chrg.battTS;
save(dataLocation + "004ParamEstData",'battTS', 'currTS','airTempTS','surfTempTS','coreTempTS','socTS','-v7.3');