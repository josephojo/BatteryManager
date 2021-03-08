function [testData, metadata, testSettings]  = AhCounter(varargin)
%AhCounter Counts the mount of capacity left in a cell or pack
% ahCount = AhCounter('cRates', [0.25, 0.25], 'battID', "AB1");
%
%   Inputs: 
%       varargin   
%           cRates          = 1             : CRate of rated capacity to cycle  for. Can be 1 value
%                                               for charge and discharge or a vector of 2 values one 
%                                               for each (Unitless).
%                                               DEFAULT = 1C for both charge and discharge
%                                              
%           waitTime        = 1800          : Time in seconds to wait between both charge and discharge.  
%                                               DEFAULT = 1800s
%
%			battID       	= [],     		: ID of Cell/Pack being tested.
%			caller      	= "cmdWindow", 	: Specifies who the parent caller is. The GUI or MatLab's cmd window. Implementations between both can be different
%			psuArgs       	= [],     		: Connection details of the power supply
%			eloadArgs     	= [],     		: Connection details of the Electronic Load
%			tempModArgs    	= [],     		: Connection details of the Temperature measuring module
%			sysMCUArgs     	= [],     		: Connection details of the Data Acquisition System. (Switches Relays and obtaines measurements)
%			sysMCUArgs     	= [],     		: Arguments from the GUI used to save Data results
%			saveArgs     	= [],     		: Arguments from the GUI used to save Data results
%			stackArgs     	= [],     		: Arguments from the GUI about the cells to be tested
%			dataQ         	= [],     		: Pollable DataQueue for real-time data transfer between
%                                               2 parallel-run programs such as the function and GUI
%			errorQ        	= [],     		: Pollable DataQueue for real-time error data (exceptions)
%                                               transfer between 2 parallel-run programs such as the function and GUI
%			randQ        	= [],     		: Pollable DataQueue for miscellaneous data (e.g confirmations etc)
%                                               transfer between 2 parallel-run programs such as the function and GUI
%			testSettings  	= []);    		: Settings for the test such as cell configuration, sample time, data to capture etc
%
%   Outputs:
%       testData            : Struct of Test Data
%       metadata            : Test MetaData such as starttime, Tested Batt etc
%       testSettings        : Device, data measurement, and other settings
%                               to allow the functioning of the test


%% Parse Input Argument or set Defaults

param = struct(...
    'cRates',           0.25,      ... % General to most functions
    'waitTime',         1800,   ... %           "
    ...             %           "
    'battID',           [],     ... %           "
    'caller',      "cmdWindow", ... %           "
    'psuArgs',          [],     ... %           "
    'eloadArgs',        [],     ... %           "
    'tempModArgs',      [],     ... %           "
    'balArgs',          [],     ... %           "
    'sysMCUArgs',       [],     ... %           "
    'saveArgs',         [],     ... %           "
    'stackArgs',        [],     ... %           "
    'dataQ',            [],     ... %           "
    'errorQ',           [],     ... %           "
    'randQ',            [],     ... %           "
    'testSettings',     [],     ... %           " 
    'eventLog',         []);        % -------------------------


% read the acceptable names
paramNames = fieldnames(param);

% Ensure variable entries are pairs
nArgs = length(varargin);
if round(nArgs/2)~=nArgs/2
    error('runProfile needs propertyName/propertyValue pairs')
end

for pair = reshape(varargin,2,[]) %# pair is {propName;propValue}
    inpName = pair{1}; %# make case insensitive
    
    if any(strcmpi(inpName,paramNames))
        %# overwrite options. If you want you can test for the right class here
        %# Also, if you find out that there is an option you keep getting wrong,
        %# you can use "if strcmp(inpName,'problemOption'),testMore,end"-statements
        param.(inpName) = pair{2};
    else
        error('%s is not a recognized parameter name',inpName)
    end
end

% ---------------------------------

cRates = param.cRates;
waitTime = param.waitTime;

battID = param.battID;
caller = param.caller;
psuArgs = param.psuArgs;
eloadArgs = param.eloadArgs;
tempModArgs = param.tempModArgs;
balArgs = param.balArgs;
sysMCUArgs = param.sysMCUArgs;
stackArgs = param.stackArgs;
dataQ = param.dataQ;
errorQ = param.errorQ;
randQ = param.randQ;
testSettings = param.testSettings;

%%
currFilePath = mfilename('fullpath');
% Seperates the path directory and the filename
[path, ~, ~] = fileparts(currFilePath);

parentDir = extractBefore(path, "03BatteryMgrScripts");

dataLocation = parentDir + "\01CommonDataForBattery\";
    
%% Begin AhCounter
try 
    % Load Table with cell information
    load(dataLocation + "007BatteryParam.mat", 'batteryParam')
    cap = batteryParam.capacity(battID); % Ah
    
    disp("Counting Capacity ...");
    
    if length(cRates) > 1
        cRate_chrg = cRates(1); % Use the first cRate for Charging
        cRate_dchrg = cRates(2); % Use the first cRate for Charging
    else
        cRate_chrg = cRates;
        cRate_dchrg = cRates;
    end
    
    if isempty(testSettings)
        testSettings.tempChnls = [9, 10];
        testSettings.cellConfig = 'single';
    end
    
    % Step 1: Bring the cell  to Full Capacity
    [testData_chrg, metadata_chrg] = chargeToSOC(1, cRate_chrg*cap, 'battID', battID, 'testSettings', testSettings);

    % Step 2: Let the battery rest
    [testData_Wait_Chrg, metadata_Wait_Chrg] = waitTillTime(waitTime, 'battID', battID, 'testSettings', testSettings);
    testData_temp = appendTestDataStruts(testData_chrg, testData_Wait_Chrg);
    metadata_temp = appendTestDataStruts(metadata_chrg, metadata_Wait_Chrg);

    % Step 3: Discharge to empty
    [testData_dchrg, metadata_dchrg, testSettings] = ...
        dischargeToSOC(0, cRate_chrg*cap, 'battID', battID, 'testSettings', testSettings);
    testData = appendTestDataStruts(testData_temp, testData_dchrg);
    metadata = appendTestDataStruts(metadata_temp, metadata_dchrg);

    
    % Save data
    if errorCode == 0 && tElasped > 1
        packAhCap = abs(testData.packCap(end, :));
        batteryParam.capacity(battID) = packAhCap;

        % Store the individual cell Capacities as well if connected in
        % series
        if strcmpi(cellConfig, 'series') || strcmpi(cellConfig, 'SerPar')
            cellAhCap = abs(testData.cellCap(end, :)');
            batteryParam.cellCap(battID) = cellAhCap;
        end
        
        testData.packAhCap = packAhCap;
        testData.cellAhCap = cellAhCap;
        testSettings.purpose = "To update capacity count for battery (pack).";
        
        % Get Current File name
        [~, filename, ~] = fileparts(mfilename('fullpath'));
        % Save data
        saveTestData(testData, metadata, testSettings, filename);
        
        updateExpLogs(fileName, purpose, battID, batteryParam);

    end
    
catch ME
    script_handleException;
end

% Teardown
script_resetDevices;

end