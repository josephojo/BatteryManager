codeFilePath = mfilename('fullpath');
% Seperates the path directory and the filename
[path, fName, ~] = fileparts(codeFilePath);

%% 
battID = "AD0";
RATED_CAP = 13.4;

ExpName = "StdChrg";

testSettings.tempChnls = 9:13;
testSettings.initialBalVolt = 3.0; % This will be used for passively balancing series pack

if ~exist('eventLog', 'var')
    eventLog = EventLogger();
end


%% Charge to 90% using 0.3C of rated capacity
TARGET_SOC = 0.9;
chrgCurr = 0.3 * RATED_CAP;

[testData, metadata, testSettings] = chargeToSOC(TARGET_SOC, chrgCurr,...
    'battID', battID, 'testSettings', testSettings,...
    'eventLog', eventLog);


 %% Anode Potential Lookup table (From "01_INR18650F1L_AnodeMapData.mat")
load(testSettings.dataLocation + "001_AnodeMapData_" + batteryParam.cellPN(battID)+ ".mat"); % Lithium plating rate
anPotMdl.Curr = cRate_mesh * RATED_CAP;
anPotMdl.SOC = soc_mesh;
anPotMdl.ANPOT = mesh_anodeGap;

% Add AnodePot data from current and SOC data

testData.AnodePot = qinterp2(-anPotMdl.Curr, anPotMdl.SOC, anPotMdl.ANPOT,...
testData.cellCurr, testData.cellSOC);

%% Save Data

str = extractBefore(path, "03BatteryMgrScripts");

testSettings.saveName = "006_" + battID + "_StdCharge_W_PassiveBal";
testSettings.saveDir = str + "00ProjectData\" + extractBefore(fName, 4) + "\";

testSettings.saveDir = testSettings.saveDir + metadata.startDate...
        +"_"+ metadata.startTime + "_" + ExpName +"\";

% Save Data
[saveStatus, saveMsg] = saveTestData(testData, metadata, testSettings);
    
