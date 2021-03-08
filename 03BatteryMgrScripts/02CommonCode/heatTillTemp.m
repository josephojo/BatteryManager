function battTS = heatTillTemp(setTemp, varargin)
%heatTillTemp Turns on the heater until the temperature reaches the set
%temperature

try
    cellID = 'aa5';
    script_initializeDevices;
    script_initializeVariables;
    
    testTimer = tic; % Start Timer for read period
    
    verbose = 1;
    script_idle;
    script_queryData;
    
    heatPadStartTime = 10; %100.0;
    cooldownTime = 120;
    iter = 0;
    
    if nargin > 1 && strcmpi(class(varargin{1}),'double')
        numIterations = varargin{1};
    else
        numIterations = 1;
    end
    
    disp("Waiting till Temp = " + num2str(setTemp) + " ºC !");
    
    while (thermoData(3)/10 < setTemp)
        
        % Query Data
        if toc(testTimer) - timerPrev(3) >= readPeriod
            timerPrev(3) = toc(testTimer);
            script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
        end
        
        % HEATING PAD
        % The Relay that was origninally used for an LED has been repurposed
        % for the heating pad. The pad switches on heatPadStartTime (+5s)
        % and switches OFF when Temp = setTemp
        if tElasped >= heatPadStartTime && iter < numIterations
            disp("Heat Pad Turned ON - " + num2str(tElasped))
            % Turn the heat pad is ON
            ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4, true, 0, 0);
            ljudObj.GoOne(ljhandle);
            iter = iter + 1;
        end
    end
    
    disp("Heat Pad Turned OFF -  " + num2str(tElasped))
    % Make sure the heating pad is ON
    ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4, false, 0, 0);
    ljudObj.GoOne(ljhandle);
    
    disp("Cooling Down." + newline);
    t1 = toc(testTimer);
    t = 0;
    while t < cooldownTime
        t2 = toc(testTimer);
        t = t2 - t1;
        % Query Data
        if toc(testTimer) - timerPrev(3) >= readPeriod
            timerPrev(3) = toc(testTimer);
            script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
        end
    end

    script_resetDevices;
    
    disp("Done" + newline);
    
catch ME
    script_resetDevices;
    rethrow(ME);
end
% clearvars;
end
