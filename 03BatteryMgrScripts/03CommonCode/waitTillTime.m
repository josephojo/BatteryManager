function battTS = waitTillTime(targTime, varargin)
%waitTillTime Idles the battery (pack) while waiting until the target time
%is up
%
%   Inputs: 
%       targTime            : Target time (s) to wait for
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

% clearvars;
try
    
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
    
    disp("Waiting for " + num2str(targTime) + " Seconds!");
    
    script_initializeDevices;
    script_initializeVariables;

    
    verbose = 0;
    battState = "idle";
    
    testTimer = tic;
    
    script_queryData;

    
    trig1_On = false;
    trig1_Ind = 1; % Index for iterating over the start times specified for trig1
    
    if param.trig1 == true
        trig1StartTime = param.trig1_startTime;
        trig1EndTime = param.trig1_startTime + param.trig1_duration;
        trig1TimeTol = 0.5; % Half a second
    end
    
    WaitTimer = tic;
    waitTicker = 0;
    
    while (waitTicker < targTime)
        waitTicker = toc(WaitTimer); % Counts up from zero
        
        if toc(testTimer) - timerPrev(3) >= readPeriod
            timerPrev(3) = toc(testTimer);
            script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
            script_failSafes; %Run FailSafe Checks

        end
        % Trigger1 (GPIO from LabJack)
        if param.trig1==true
            % The trigger is activated on trig1StartTime
            % and switches OFF trig1EndTime
            if tElasped >= trig1StartTime(trig1_Ind) && ...
                    tElasped < trig1StartTime(trig1_Ind) + trig1TimeTol && ...
                    trig1_On == false
                disp("Trigger ON - " + num2str(timerPrev(3))+ newline)
                pinVal = true;
                % Make sure the heating pad is ON
                ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', param.trig1_pin, pinVal, 0, 0);
                ljudObj.GoOne(ljhandle);
                trig1_On = true;
            elseif tElasped >= trig1EndTime(trig1_Ind) && ...
                    tElasped < trig1EndTime(trig1_Ind) + trig1TimeTol && ...
                    trig1_On == true
                disp("Trigger OFF - " + num2str(timerPrev(3))+ newline)
                % Make sure the heating pad is ON
                ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', param.trig1_pin, ~pinVal, 0, 0);
                ljudObj.GoOne(ljhandle);
                trig1_On = false;
                if length(trig1StartTime) > 1 && trig1_Ind ~= length(trig1StartTime)
                    trig1_Ind = trig1_Ind + 1;
                end
            end
        end
    end
    
    disp("Waiting Done" + newline);
    
catch MEX
    script_resetDevices;
    if caller == "cmdWindow"
        rethrow(MEX);
    else
        send(errorQ, MEX)
    end
end

script_resetDevices;

end
