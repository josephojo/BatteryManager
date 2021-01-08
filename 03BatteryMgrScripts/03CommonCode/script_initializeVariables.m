
% Send the command Queue object back to the caller so that commands such as
% "stop" and "pause" can be sent to the program as it runs
if strcmpi(caller, "gui")
   cmdQ = parallel.pool.PollableDataQueue; 
   if ~isempty(randQ)
       send(randQ, cmdQ);
   end
end

%% Gets the full path for the current file and changes directory
if caller == "gui"
    dataLocation = testSettings.dataLocation + "\";
else
    currFilePath = mfilename('fullpath');
    % Seperates the path directory and the filename
    [path, filename, ~] = fileparts(currFilePath);
    
    newStr = extractBetween(path,"",...
                   "03DataGen","Boundaries","inclusive");
    dataLocation = newStr + "\01CommonDataForBattery\";
    testSettings.dataLocation = dataLocation;

    %{
%     % goes to path
%     cd(path + "\..\..")
% 
%     % Retreives current directory
%     path = pwd;
%     dataLocation = path + "\01CommonDataForBattery\";
    %}
end

%% Default input settings for running from cmd window

% Default action for when the command window is the caller and testSetting
% is empty
if strcmpi(caller, "cmdWindow") && ~isfield(testSettings, "data2Record")
    testSettings.data2Record = ["volt", "curr", "SOC", "Cap", "Temp"];
end
if strcmpi(caller, "cmdWindow") && ~isfield(testSettings, "voltMeasDev")
    testSettings.voltMeasDev = "mcu";
end
if strcmpi(caller, "cmdWindow") && ~isfield(testSettings, "currMeasDev")
    testSettings.currMeasDev = "powerDev";
end
if strcmpi(caller, "cmdWindow") && ~isfield(testSettings, "tempMeasDev")
    testSettings.tempMeasDev = "Mod16Ch";
end

%% Configure Relay pins on the LAbJack MCU
if caller == "gui"
    LJ_powerDev_RelayPins = sysMCUArgs.relayPins;
    LJ_MeasVoltPin = 7; %#TODO Need to create a field for this in sysMCUArgs
else
    LJ_powerDev_RelayPins = [5, 6]; % Power Device Switching pins
    LJ_MeasVoltPin = 7;
end

%% Battery Connection Info

% If for some reason the variable (cellIDs) does not exist.
% This dialog popup method is really slow. It is only being used in extreme
% scenarios.
if ~exist("battID", 'var') || isempty(battID)
%     cellID_In = upper(input('Please enter the cellID for the battery being tested: ','s')); % ID in Cell Part Number (e.g BAT11-FEP-AA1)
    prompt = {'Enter the S/N for the battery (cell/pack) being tested: '};
    dlgtitle = 'Battery ID Request';
    dims = [1 50];
    definput = {'e.g AB1 or ab1'};
    battID_In = upper(inputdlg(prompt,dlgtitle,dims,definput));
    battID = string(battID_In{1});
end

%Load Battery Parameters
load(dataLocation + "007BatteryParam.mat", 'batteryParam');

% Battery Configuration
stackConfig = batteryParam.stackConfig(battID);
numCells_Ser = double(extractBetween(stackConfig, 1, 1)); % Number of cells in series
numCells_Par = double(extractBetween(stackConfig, 3, 3)); %Number of cells in parallel
numCells = numCells_Ser * numCells_Par; % Total number of cells in system



% Let the user enter the parameter for the cellIDs specified if they don't
% exist
if caller == "cmdWindow"
    % Input data for new battery into database.
    
    if max(ismember(batteryParam.Row, battID)) == 0
        
        answer = questdlg(['Parameters for ' char(battID) ' does not exist in storage.'...
            newline newline 'Would you like to create them now?' newline], ...
            ['Cell with name ' char(battID) ' does not exist in database'], ...
            'Yes, Create Now','No, Quit Program','No, Quit Program');
        % Handle response
        switch answer
            case 'Yes, Create Now'
                disp(newline + "Here we go ...");
            case 'No, Quit Program'
                errorCode = 2;
                error(newline + "Rerun the program to try again." + newline +...
                    "Quitting  now."  + newline);
        end
        
        prompt = {'Chemistry?: ','Stack Configuration (xSnP): ','Capacity (Ah)?: ','ChargeTo Voltage (V)?: ', 'DishargeTo Voltage (V)?: ',...
            'CV charge stop current (A)?: ', 'Maximum Voltage Limit (V)?: ',...
            'Minimum Voltage Limit (V)?: ', 'Maximum Discharge Current Limit (A)?: ', ...
            'Maximum Charge Current Limit (A)?: ', 'Rated Capacity from Manufacturer (Ah)?: ',...
            'Maximum Surface Temp Limit (°C)?: ', 'Maximum Core Temp Limit (°C)?: '};
        dlgtitle = ['Parameter input for Battery ID ' char(battID)];
        dims = [1 50];
        definput = {'LFP', '2.5', '3.6', '2.5', '0.125', '3.61', '2.49', '30',...
            '-16', '2.5', '50', '55'};
        params = inputdlg(prompt,dlgtitle,dims,definput);
        
        chemistry       = upper(string(params{1}));
        stackConfig     = upper(string(params{2}));
        capacity        = str2double(params{3});
        cellCap         = str2double(params{4});
        soc             = 1;
        chargedVolt     = str2double(params{5});
        dischargedVolt  = str2double(params{6});
        cvStopCurr      = str2double(params{7});
        maxVolt         = str2double(params{8});
        minVolt         = str2double(params{9});
        maxCurr         = str2double(params{10});
        minCurr         = -abs(str2double(params{11})); % For while charging
        ratedCapacity   = str2double(params{12});
        maxSurfTemp     = str2double(params{13});
        maxCoreTemp     = str2double(params{14});
        
        
        Tnew = table(chemistry,stackConfig,capacity, cellCap, soc, ...
            chargedVolt, dischargedVolt,...
            cvStopCurr, maxVolt,minVolt,maxCurr,minCurr,maxSurfTemp,...
            maxCoreTemp,ratedCapacity, 'RowNames', { char(battID)});
        
        batteryParam = [batteryParam;Tnew];
    end
    save(dataLocation + "007BatteryParam.mat", 'batteryParam');
end


%% Choose Battery Connection Configuration

if caller == "gui"
    cellConfig = testSettings.cellConfig;
else
    if ~exist('cellConfig', 'var') && ~isfield(testSettings, 'cellConfig')
        if numCells == 1
            cellConfig = "single";
            testSettings.cellConfig = cellConfig; % Update in the testSettings variable
        else
            if numCells_Ser > 1 && numCells_Par == 1
                cellConfig = 'series';
            elseif numCells_Ser == 1 && numCells_Par > 1
                cellConfig = 'parallel';
            elseif numCells_Ser > 1 && numCells_Par > 1
                cellConfig = 'SerPar';
            end
            
            testSettings.cellConfig = cellConfig; % Update in the testSettings variable
        end
    elseif isfield(testSettings, 'cellConfig')
        cellConfig = testSettings.cellConfig;
    end

    if strcmpi(cellConfig, "single")
        testSettings.voltMeasDev = "mcu";
    elseif strcmpi(cellConfig, "series") || strcmpi(cellConfig, "SerPar")
        testSettings.voltMeasDev = "balancer";
        testSettings.currMeasDev = "balancer";
    end
end

%% TC Info
if caller == "gui"
    tempChnls = testSettings.tempChnls;
else   
    if ~isempty(testSettings) && isfield(testSettings, 'tempChnls')
        tempChnls = testSettings.tempChnls;
    else
        prompt = {'What channels have the temperature sensors been connected to? (Seperate by commas)'};
        dlgtitle = 'Info on Temp. Sensors';
        dims = [1 50];
        definput = {'9, 10, 11, 12, 13'};
        answer = inputdlg(prompt,dlgtitle,dims,definput);
        if ~isempty(answer)
            tempVal = str2double(strsplit(answer{1},','));
            tempChnls = tempVal(~isnan(tempVal));
            disp("You have entered the following channels : " + strjoin(string(tempChnls), ', '))
        end
    end
    
    
end

%% Individual cell related variables % #Needed?
batt = struct;
batt.prevSOC = batteryParam.soc(battID);
volt = zeros(numCells_Ser, 1); 
curr = zeros(numCells_Ser, 1); 
AhCap = zeros(numCells_Ser, 1); 


%% Battery Stack Related Variables
% Initializes the Constants used in Data Generation
psuData = zeros(1, 2); % Container for storing PSU Data
eloadData = zeros(1, 2); % Container for storing Eload Data
thermoData = zeros(1, length(tempChnls)); % Container for storing TC Data
% ambTemp = 0;


if ismember("curr", testSettings.data2Record) && strcmpi(testSettings.currMeasDev, "mcu") 
    if ~isempty(sysMCUArgs) && isfield(sysMCUArgs, 'currMeasPins')
        currPinPos = sysMCUArgs.currMeasPins(1);
        currPinNeg = sysMCUArgs.currMeasPins(2);
    else
        % Pins on the LABJACK U3-HV that measures shunt Voltage
        currPinPos = 0; 
        currPinNeg = 7;
    end
    currNeg = []; currPos = []; adcAvgCounter = 0; % Variables used for labjack(LJ) averaging
    adcAvgCount = 10; %20;

end
if ismember("volt", testSettings.data2Record) && strcmpi(testSettings.voltMeasDev, "mcu") 
    if ~isempty(sysMCUArgs) && isfield(sysMCUArgs, 'voltMeasPins')
        voltPinPos = sysMCUArgs.voltMeasPins(1);
        voltPinNeg = sysMCUArgs.voltMeasPins(2);
    else
        voltPinPos = 2;  % Analog input pin for measuring +ve terminal voltage wrt MCU Gnd
        voltPinNeg = 3;  % Analog input pin for measuring -ve terminal voltage wrt MCU Gnd
    end 
    
    voltNeg = 0; voltPos = 0; adcAvgCounter = 0; 
    adcAvgCount = 10; %20;

end
        

% Creates an container that will be used to record previous time measurements
timerPrev = zeros(5, 1); 
% timerPrev(1): For Total Elapsed Time 
% timerPrev(2): For Profile period
% timerPrev(3): For Measurement Period
% timerPrev(4): For packSOC Estimation
% timerPrev(5): For Progress dot (Dot that shows while code runs)

% Keeping this incase user in GUI wants to change some Args that are not
% reflected in batteryParam
if strcmpi(caller, "gui")
    % Battery Properties of the specific battery being tested. Info here is
    % similar to what is batteryParam.
    battProp = stackArgs;  
else
    battProp = batteryParam(battID, :); % Battery Properties
end

% Fully charged voltage
highVoltLimit = battProp.chargedVolt(battID);  % sum(batteryParam.chargedVolt(cellIDs)); 
% Fully Discharged Voltage
lowVoltLimit  = battProp.dischargedVolt(battID); 

chargeReq = 0; % Charge Request - true/1 = Charging, false/0 = discharging
chargeVolt = highVoltLimit + 0.003; % Due to the small resistance in the wiring

prevSOC = battProp.soc(battID); % Previous SOC for the Pack

% Transformation Matrix for calculating SOC in an Active Balancing process 
% [1]	L. McCurlie, M. Preindl, P. Malysz, and A. Emadi, Eds., 
% Simplified control for redistributive balancing systems using bidirectional 
% flyback converters. 2015 IEEE Transportation Electrification Conference and Expo (ITEC), 2015.
L2 = [zeros(numCells_Ser-1, 1), (-1 * eye(numCells_Ser-1))];
L1 = eye(numCells_Ser);
L1(end, :) = [];
L = L1 + L2; 

AhCap = 0;
battState = "idle"; % State of the battery ("charging", "discharging or idle")
packVolt = 0; % Measured Voltage of the battery stack
packCurr = 0; % Current from either PSU or ELOAD depending on the battState
packSOC = prevSOC; % Estimated SOC of the battery is stored here

maxBattVoltLimit = battProp.maxVolt(battID); % Maximum Voltage limit of the operating range of the battery stack
minBattVoltLimit = battProp.minVolt(battID); % Minimum Voltage limit of the operating range of the battery stack
coulombs = battProp.capacity(battID)*3600; % Convert Ah to coulombs

cvMinCurr = batteryParam.cvStopCurr(battID); % Typically 10% of 1C
maxBattCurrLimit = battProp.maxCurr(battID); % Maximum Specified (by the user) Current limit of the operating range of the battery
minBattCurrLimit = battProp.minCurr(battID); % Minimum Specified (by the user) Current limit of the operating range of the battery

battSurfTempLimit = battProp.maxSurfTemp(battID); % Maximum Surface limit of the battery
battCoreTempLimit = battProp.maxCoreTemp(battID); % Maximum Core limit of the battery
errorCode = 0;

if ~exist('eventLog', 'var') || isempty(eventLog) || ~isvalid(eventLog)
    eventLog = [];
end

% Opens the Event Logger
if strcmpi(caller, "gui")
    eventLog = balArgs.eventLog;
else
    if strcmpi(cellConfig, 'series')
        if ~exist('eventLog', 'var')
            eventLog = EventLogger();
        end
    end
end

verbosity = 0; % How often to display (stream to screen). 1 = constantly, 0 = once a while
if ~exist("verbosity", 'var')
    verbosity = 1;
end

dotCounter = 0;
tElasped = 0;

if caller == "gui"
    readPeriod = testSettings.readPeriod;
else
    readPeriod = 0.5; %0.25; % Number of seconds to wait before reading values from devices
end

% Track SOC FailSafe (if it goes above or below rated SOC
if ~exist("trackSOCFS", 'var')
    trackSOCFS = true;
end

battTS = timeseries();
testData = struct;
% Placing all cell specific data horizontally despite some data being data 
% for series stack (since time is vertical).
testData.cellSOC = []; 
testData.packSOC = [];
testData.cellVolt = [];
testData.packVolt = [];
testData.cellCurr = [];
testData.packCurr = [];
testData.cellCap = [];
testData.packCap = [];
testData.temp = [];
testData.time = [];


testStatus = "running";

% Variables needed to compute current of the balancers since they're
% bidirectional in nature, so if one cell discharges, the others charge
chrgEff = 0.7;
dischrgEff = 0.7;
T_chrg = eye(numCells_Ser) - (repmat(1/numCells_Ser, numCells_Ser) / chrgEff); % Current Transformation to convert primary cell currents to net cell currents to each cell during charging
T_dchrg =  eye(numCells_Ser) - (repmat(1/numCells_Ser, numCells_Ser) * dischrgEff); % Current Transformation to convert primary cell currents to net cell currents to each cell during discharging

% Initialize Metadata struct that is saved with Data after Test
dateStr = string(datetime('now', 'Format','yyMMdd_HHmm'));
metadata.startDate = string(datetime('now', 'Format','yyMMdd'));
metadata.startTime = string(datetime('now', 'Format','HHmm'));
metadata.dataSample = readPeriod;
metadata.battID = battID;


% #DEP_01 - If this order changes, the order in "script_queryData" should 
% also be altered
metadata.dataColumnHeaders = ["Pack Voltage", "Pack Current", "Pack SOC", "Pack Transferred Capacity"];
colHeaderTemp1 = [];
for seriesInd = 1:numCells_Ser
    colHeaderTemp1 = [colHeaderTemp1; ["Cell(" + seriesInd + ", :) Voltage", ...
                                       "Cell(" + seriesInd + ", :) Current", ...
                                       "Cell(" + seriesInd + ", :) SOC"    , ...
                                       "Cell(" + seriesInd + ", :) Transferred Capacity"]];
end
colHeaderTemp2 = [];
for i = 1:length(tempChnls)
    colHeaderTemp2 = [colHeaderTemp2, "TC@Ch " + tempChnls(i)];
end
metadata.dataColumnHeaders = [metadata.dataColumnHeaders, colHeaderTemp1(:)', colHeaderTemp2(:)'];
