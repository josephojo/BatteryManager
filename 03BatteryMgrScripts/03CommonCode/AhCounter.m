function battTS_temp = AhCounter(varargin)
%AhCounter Counts the mount of capacity left in a cell or pack
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
%			cellIDs       	= [],     		: IDs of Cells being tested. If parallel specify all cells in string array
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


%% Setup Code

param = struct(...
    'cRates',           1,      ... % General to most functions
    'waitTime',         1800,   ... %           "
    ...             %           "
    'cellIDs',          [],     ... %           "
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
    'testSettings',     []);        % -------------------------


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

cellIDs = param.cellIDs;
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

newStr = extractBetween(path,"",...
               "03DataGen","Boundaries","inclusive");
dataLocation = newStr + "\01CommonDataForBattery\";
    
%% Begin AhCounter
try 
    % Load Table with cell information
    load(dataLocation + "007BatteryParam.mat", 'batteryParam')
    cap = batteryParam.capacity(cellID); % Ah
    
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
    battTS_chrg = chargeToSOC(1, cRate_chrg*cap, 'cellIDs', cellIDs, 'testSettings', testSettings);

    % Step 2: Let the battery rest
    battTS_Wait_Chrg = waitTillTime(waitTime, 'cellIDs', cellIDs, 'testSettings', testSettings);
    battTS_temp = appendBattTS2TS(battTS_chrg, battTS_Wait_Chrg);

    % Step 3: Discharge to empty
    dischargeToEmpty; % there is an internal variable "battTS" in script
    battTS = appendBattTS2TS(battTS_temp, battTS);

    
    % Plot the data if true
    if plotFigs == true
        plotBattData(battTS);
    end
    
    % Save data
    if errorCode == 0 && tElasped > 1
        cellAhCap = abs(cells.AhCap(cellIDs));
        if strcmpi(cellConfig, 'parallel')
            batteryParam.capacity(cellIDs) = cellAhCap;
        else
            batteryParam.capacity(cellIDs) = cellAhCap;
        end
        
        if numCells > 1
            fileName = "007_" + cellConfig + "_AhCount.mat";
            save(dataLocation + fileName, 'battTS', 'cellIDs', 'cellAhCap');
        else
            fileName = "007_" + cellIDs(1) + "_AhCount.mat";
            save(dataLocation + fileName, 'battTS', 'cellAhCap');
        end
        
%         batteryParam.soc(cellIDs) = 0; % 0% SOC
        
        % Save Battery Parameters
        save(dataLocation + "007BatteryParam.mat", 'batteryParam');
        
        purpose = "To update capacity count for battery (pack).";
        updateExpLogs(fileName, purpose, cellIDs, cellAhCap, batteryParam);

    end
    
catch MEX
    script_resetDevices;
    if caller == "cmdWindow"
        rethrow(MEX);
    else
        send(errorQ, MEX)
    end
end

% Teardown
script_resetDevices;

end