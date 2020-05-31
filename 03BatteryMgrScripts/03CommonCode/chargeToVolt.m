function battTS = chargeToVolt(targVolt, chargeCurr, varargin)
%chargeToVolt Charges to the specified Voltage based on the charge current
%specified
%
%   Inputs: 
%       targVolt            : Target Voltage (V) to charge for
%      	chargeCurr          : Current (A) to charge
%       varargin   
%			trig1         	= false,  		: Accepts a Command to use the trigger activate something such as a heat pad
%			trig1_pin     	= 4,      		: Specifies what pin on the MCU to use(Initially used on a LABJack U3-HV)
%			trig1_startTime	= [10.0], 		: How long into the parent function to trigger. Can be an array of times (s)
%			trig1_duration	= [2.0],  		: How long should the trigger last
%											
%			cellIDs       	= [],     		: IDs of Cells being tested. If parallel specify all cells in string array
%			caller      	= "cmdWindow", 	: Specifies who the parent caller is. The GUI or MatLab's cmd window. Implementations between both can be different
%			psuArgs       	= [],     		: Connection details of the power supply
%			eloadArgs     	= [],     		: Connection details of the Electronic Load
%			thermoArgs    	= [],     		: Connection details of the Temperature measuring module
%			daqArgs     	= [],     		: Connection details of the Data Acquisition System. (Switches Relays and obtaines measurements)
%			dataQ         	= [],     		: Pollable DataQueue for real-time data transfer between 
%                                               2 parallel-run programs such as the function and GUI
%			errorQ        	= [],     		: Pollable DataQueue for real-time error data (exceptions) 
%                                               transfer between 2 parallel-run programs such as the function and GUI
%			testSettings  	= []);    		: Settings for the test such as cell configuration, sample time, data to capture etc


%% Setup Code

param = struct(...
    'trig1',            false,  ... % General to most functions
    'trig1_pin',        4,      ... %           "
    'trig1_startTime',  [10.0], ... %           "
    'trig1_duration',   [2.0],  ... %           "
                    ...             %           "
    'cellIDs',          [],     ... %           "
    'caller',      "cmdWindow", ... %           "
    'psuArgs',          [],     ... %           "
    'eloadArgs',        [],     ... %           "
    'thermoArgs',       [],     ... %           "
    'daqArgs',          [],     ... %           "
    'dataQ',            [],     ... %           "
    'errorQ',           [],     ... %           "
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

cellIDs = param.cellIDs;
caller = param.caller;
psuArgs = param.psuArgs;
eloadArgs = param.eloadArgs;
thermoArgs = param.thermoArgs;
daqArgs = param.daqArgs;
dataQ = param.dataQ;
errorQ = param.errorQ;
testSettings = param.testSettings;

trig1_On = false;
trig1_Ind = 1;

if param.trig1 == true
    trig1StartTime = param.trig1_startTime;
    trig1EndTime = param.trig1_startTime + param.trig1_duration;
    trig1TimeTol = 0.5; % Half a second
end


% Initializations
try
    script_initializeDevices; % Initialized devices like Eload, PSU etc.
    script_initializeVariables; % Run Script to initialize common variables
    curr = abs(chargeCurr); %2.5A is 1C for the ANR26650
    
%     testTimer = tic; % Start Timer for read period
    
    script_queryData; % Run Script to query data from devices
    script_failSafes; %Run FailSafe Checks
    script_charge; % Run Script to begin/update charging process
    
    
    % While the battery voltage is less than the limit (cc mode)
    while battVolt <= targVolt
        %% Measurements
        % Querys all measurements every readPeriod second(s)
        if toc(testTimer) - timerPrev(3) >= readPeriod
            timerPrev(3) = toc(testTimer);
            script_queryData; % Run Script to query data from devices
            script_failSafes; %Run FailSafe Checks
            % if limits are reached, break loop
            if errorCode == 1
                script_idle;
                break;
            end
        end
    end
   
    
    % Save data
    if tElasped > 5 % errorCode == 0 &&
        if numCells > 1
            save(dataLocation + "005_" + cellConfig + "_ChargeTo" +num2str(round(battSOC*100,0))+ "%.mat", 'battTS', 'cellIDs');
        else
            save(dataLocation + "005_" + cellIDs(1) + "_ChargeTo" +num2str(round(battSOC*100,0))+ "%.mat", 'battTS');
        end
        % Save Battery Parameters
        save(dataLocation + "007BatteryParam.mat", 'batteryParam');
    end
    
    if plotFigs == true
        currVals = ones(1, length(battTS.Time)) * curr;
        plotBattData(battTS, 'noCore');
    end
    
    
catch MEX
    script_resetDevices;
    if caller == "cmdWindow"
        rethrow(MEX);
    else
        send(errorQ, MEX)
    end
end

%% Teardown
script_resetDevices;

end