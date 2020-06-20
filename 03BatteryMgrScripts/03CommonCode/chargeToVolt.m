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
    'trig1',            false,  ... % General to most functions
    'trig1_pin',        4,      ... %           "
    'trig1_startTime',  [10.0], ... %           "
    'trig1_duration',   [2.0],  ... %           "
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

if (isempty(testSettings) || ~isfield(testSettings, 'trigPins')) ...
        && param.trig1 == true  
    testSettings.trigPins = param.trig1_pin;
    testSettings.trigStartTimes = {param.trig1_startTime};
    testSettings.trigStartTimes = {param.trig1_duration};
    testSettings.trigInvert = zeros(length(param.trig1_startTime), 1);
end

if ~isempty(testSettings.trigPins) % param.trig1 == true
    if length(testSettings.trigPins) == size(testSettings.trigStartTimes, 1) && ...
            length(testSettings.trigPins) == size(testSettings.trigDurations, 1)
        
        trigPins = testSettings.trigPins;
        trigStartTimes = testSettings.trigStartTimes;
        trigDurations = testSettings.trigDurations;
        trigInvert   = testSettings.trigInvert;
        trigTimeTol = 0.5; % Half a second
        for i = 1:length(trigPins)
            pins2(i) = {repmat(trigPins(i), 1, length(trigStartTimes{i}))};
            inverts2(i) = {repmat(trigInvert(i), 1, length(trigStartTimes{i}))};
        end
        pins = horzcat(pins2{:})';
        inverts = horzcat(inverts2{:})';
        startTimes = horzcat(trigStartTimes{:})';
        durations = horzcat(trigDurations{:})';
        endTimes = startTimes + durations;
        
        triggers = sortrows(table(pins, startTimes, durations, endTimes, inverts), 'startTimes', 'ascend');
        
        trigAvail = true;
        trig_Ind = 1;
        trig_On = false(length(pins) , 1);

    else
        err.code = ErrorCode.BAD_SETTING;
        err.msg = "The number of trigger pins and time inputs do not match." + newline + ...
            " Make sure to enter a start time and duration for each trigger pin.";
        send(errorQ, err);
    end
    
else
    trigAvail = false;
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
            
            % Trigger1 (GPIO from LabJack)
            if trigAvail == true
                % The trigger is activated on trig1StartTime
                % and switches OFF trig1EndTime

                %{
                 if tElasped >= triggers.startTimes(trig_Ind) && ...
                        tElasped < triggers.startTimes(trig_Ind) + trigTimeTol && ...
                        trig_On(trig_Ind) == false
                %}
                trig_Ind = tElasped >= triggers.startTimes & ...
                    tElasped < triggers.startTimes + trigTimeTol;
                if max(trig_On(trig_Ind) == false)
                    disp("Trigger ON - " + num2str(timerPrev(3))+ newline)
                    if strcmpi(caller, "gui")
                        err.code = ErrorCode.WARNING;
                        err.msg = "Trigger ON - " + num2str(timerPrev(3))+ newline;
                        send(errorQ, err);
                    end
                    pinVal = ~(true & triggers.inverts(trig_Ind)); % Flips the pinVal if invert is true
                    % Make sure the heating pad is ON
                    ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', triggers.pins(trig_Ind), pinVal, 0, 0);
                    ljudObj.GoOne(ljhandle);
                    trig_On(trig_Ind) = true;
%                             trig_Ind = trig_Ind + 1;
                end

                %{
                if tElasped >= triggers.endTimes(trig_Ind) && ...
                        tElasped < triggers.endTimes(trig_Ind) + trigTimeTol && ...
                        trig_On(trig_Ind) == true
                %}
                trig_Ind = tElasped >= triggers.endTimes & ...
                        tElasped < triggers.endTimes + trigTimeTol;
                if max(trig_On(trig_Ind) == true)
                    disp("Trigger OFF - " + num2str(timerPrev(3))+ newline)
                    if strcmpi(caller, "gui")
                        err.code = ErrorCode.WARNING;
                        err.msg = "Trigger OFF - " + num2str(timerPrev(3))+ newline;
                        send(errorQ, err);
                    end
                    pinVal = ~(false & triggers.inverts(trig_Ind)); % Flips the pinVal if invert is true
                    % Make sure the heating pad is OFF
                    ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', triggers.pins(trig_Ind), pinVal, 0, 0);
                    ljudObj.GoOne(ljhandle);
                    trig_On(trig_Ind) = false;
%                             if length(trigStartTimes) > 1 && trig_Ind ~= length(trigStartTimes)
%                                 trig_Ind = trig_Ind + 1;
%                             end
                end
            end
            
            script_queryData; % Run Script to query data from devices
            script_failSafes; %Run FailSafe Checks
            script_checkGUICmd; % Check to see if there are any commands from GUI
            % if limits are reached, break loop
            if errorCode == 1 || strcmpi(testStatus, "stop")
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
    
    if ~isempty(testSettings.saveName)
        save(testSettings.saveDir + "\" + testSettings.saveName + ".mat", 'battTS');
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