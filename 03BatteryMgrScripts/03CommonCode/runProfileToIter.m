function [battTS, cells] = runProfileToIter(profileTS, iterations, varargin)
%RUNPROFILETOITER Runs profile for the number of iterations specified.
%   Runs profile for the number of iterations specified.
%   Inputs:
%       profileTS           : Timeseries formatted data with time and
%                               current values so that each current value
%                               can be applied at the corresponding times.
%       iterations          : How many times to run it.
%
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

if iterations == 0 || isempty(iterations)
   iterations = inf; 
end


if (isempty(testSettings) || ~isfield(testSettings, 'trigPins')) ...
        && param.trig1 == true
    testSettings.trigPins = param.trig1_pin;
    testSettings.trigStartTimes = {param.trig1_startTime};
    testSettings.trigStartTimes = {param.trig1_duration};
    testSettings.trigInvert = zeros(length(param.trig1_startTime), 1);
end

if isfield(testSettings, 'trigPins') && ~isempty(testSettings.trigPins) % param.trig1 == true
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
        if strcmpi(caller, "gui")
            err.code = ErrorCode.BAD_SETTING;
            err.msg = "The number of trigger pins and time inputs do not match." + newline + ...
                " Make sure to enter a start time and duration for each trigger pin.";
            send(errorQ, err);
        end
    end
    
else
    trigAvail = false;
end


%% Begin Test
try
    % Initializations
    script_initializeDevices; % Initialized devices like Eload, PSU etc.
    script_initializeVariables; % Run Script to initialize common variables
    
    readPeriod = 0.3;
    writePeriod = readPeriod; % Period to resample the input current profile
    
    % Resamples the input profile to the interval given in readPeriod
    timevec = profileTS.Time(1):writePeriod:profileTS.Time(end);
    profileTS = resample(profileTS, timevec);
    
    script_queryData; % Run Script to query data from devices
    script_failSafes; %Run FailSafe Checks
    
    for iter = 1:iterations    
        if strcmpi(testStatus, "stop"), break; end
        
        disp("Beginning Iteration Number: " + num2str(iter) + " ;" + newline + ...
            "Estimated Time to completion: " + ...
        string(datetime('now') + minutes((profileTS.Time(end) * ((iterations + 1) - iter))/60)));
        
        counter = 1; %In order for the sampling of data from profile
        % to be based on the number of samples    
        timerPrev(2) = toc(testTimer);
        
        % While Loop: Runs through the currProfile
        while counter <= length(profileTS.Time)            
            %% Commands
            % Evaluates and changes commands based on the timing provided in the
            % profile
            if (toc(testTimer)- timerPrev(2)) >= profileTS.Time(counter)
                
                % Evaluator
                % If the next current value is positive and the battery is
                % currently charging, discharge the battery or else
                % charge the battery (charging is simulating regen braking
                if (round(profileTS.Data(counter),2) < 0) % if current is negative
%                 chargeReq = false; % Make current command a discharge command
                    curr = profileTS.Data(counter);
                    script_discharge; % Run Script to begin/update discharging process
                elseif (round(profileTS.Data(counter),2) > 0) % if current is positive
%                 chargeReq = true; % Make current command a charge command
                    curr = profileTS.Data(counter);
                    script_charge; % Run Script to begin/update charging process
                else
%                 chargeReq = 3; % Not charging or discharging
                    script_idle; % Run Script to allow rest
                end
                
                script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
                script_failSafes; %Run FailSafe Checks
                script_checkGUICmd; % Check to see if there are any commands from GUI
                % if limits are reached, break loop
                if errorCode == 1 || strcmpi(testStatus, "stop")
                    script_idle;
                    break;
                end
                
                %% Triggers (GPIO from LabJack)
                script_triggerDigitalPins;
                
                counter = counter + 1;
            end % End of IF toc
        end % While Loop
        
        save(dataLocation + "007BatteryParam.mat", 'batteryParam');
    end
    
catch MEX
    script_resetDevices;
    if caller == "cmdWindow"
        rethrow(MEX);
    else
        send(errorQ, MEX)
    end
end

%% Teardown Section

script_resetDevices; % Runs the resetDevices script

end

