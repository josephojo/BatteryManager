%collectDynECMData
%   Runs a single profile repeatedly from 90% to 10% for the purpose of
%   collecting and eventually identifying the RC parameters for an ECM
%   model. This process is based on Dr. Gregory Plett's Enhanced Cell model
%   http://mocha-java.uccs.edu/ECE5710/index.html

try
    % % Initializations
    
    adjCRate = 1;
    waitTime = 1800; % wait time for cool down periods in seconds
    cycleSocTargets = [0.9, 0.1];
    
    if ~exist('cellIDs', 'var') || isempty(cellIDs)
        % cellIDs should only be one cell
        cellIDs = "AB1"; % ID in Cell Part Number (e.g BAT11-FEP-AA1). Defined again in initializeVariables
    end
    
    if ~exist('caller', 'var')
        caller = "cmdWindow";
    end
    
    if ~exist('psuArgs', 'var')
        psuArgs = [];
        eloadArgs = [];
        tempModArgs = [];
        balArgs = [];
        sysMCUArgs = [];
        stackArgs = [];
    end
    
    if ~exist('testSettings', 'var') || isempty(testSettings)
        currFilePath = mfilename('fullpath');
        % Seperates the path directory and the filename
        [path, ~, ~] = fileparts(currFilePath);
        
        str = extractBetween(path,"",...
            "03DataGen","Boundaries","inclusive");
        testSettings.saveDir = str + "\01CommonDataForBattery";
        
        testSettings.saveName   = "01DYNData_" + cellIDs;
        testSettings.purpose    = "To use in identifying the RC parameters for an ECM model";
        testSettings.tempChnls  = [9, 10, 11];
        testSettings.trigPins = []; % Fin in every pin that should be triggered
        testSettings.trigInvert = []; % Fill in 1 for every pin that is reverse polarity (needs a zero to turn on)
        testSettings.trigStartTimes = {[100]}; % cell array of vectors. each vector corresponds to each the start times for each pin
        testSettings.trigDurations = {15}; % cell array of vectors. each vector corresponds to each the duration for each pin's trigger
    end
    
    script_initializeVariables; % Run Script to initialize common variables
    
    profile2Run = "CYC_UDDS";
    
    volt_ind = 1;
    curr_ind = 2;
    ah_ind = 4;
    
    resultCollection = {};
    prevSeqTime = 0; % As code runs, this variable stores the time of the last
    %     data collected to be used as the start time for the next data
    %     collection.
        
    testTimer = tic;    
    prev3 = toc(testTimer);
    saveIntvl = 1; % Interval to save data (hr)
    saveInd = 1; %Initial value for the number of intermittent Saves
    
    %% Script 1 : Run Profile from 90% to 10% to prevent over and under voltage
    
    % ############### SOC to Adjust the current SOC ###############
    if strcmpi (cellConfig, 'parallel')
        adjCurr = sum(batteryParam.ratedCapacity(cellIDs))*adjCRate; % X of rated Capacity
    else
        adjCurr = mean(batteryParam.ratedCapacity(cellIDs))*adjCRate; % X of rated Capacity
    end
    
    profile_cRate = 1;
    cur = pwd;
    cd(dataLocation)
    if strcmpi (cellConfig, 'single')
        searchCriteria = "002_" + cellIDs(1) + "_" + profile_cRate + "C_CurrProfiles*";
    else
        searchCriteria = "002_" + num2str(numCells) + upper(cellConfig(1)) + ...
            batteryParam.chemistry(cellIDs(1)) + "_" + profile_cRate + "C_CurrProfiles*";
    end
    fName = dir(searchCriteria);
    cd(cur)
    
    % Create Current profile if it does not currently exist
    if isempty(fName)
        multiProfileGen(profile_cRate,...
            cellIDs, dataLocation, cellConfig, batteryParam)
        cur = pwd;
        cd(dataLocation)
        fName = dir(searchCriteria);
        cd(cur)
    end
    load(fName.name); % Loads CycleProfiles and others
    
    startProfileInd = find(cycleNames == profile2Run);
    endProfileInd = startProfileInd; % length(cycleProfiles);
    
    initialSOC = cycleSocTargets(1,1);
    targetSOC = cycleSocTargets(1,2);
    
    ii = startProfileInd:endProfileInd;
    load(dataLocation + "007BatteryParam.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
    prevSOC = mean(batteryParam.soc(cellIDs));
    
    % ############### Cool Down Before Adjusting SOC ###############
    msg = newline + "Beginning to Cool Down Before Adj. SOC. " + ...
        "Waiting for " + waitTime + " seconds";
    if strcmpi(caller, "gui")
        send(randQ, msg);
    else
        disp(msg);
    end
    [out1_wait, cell1_wait] = waitTillTime(waitTime, 'cellIDs', cellIDs,...
        'testSettings', testSettings);
    battTS = out1_wait;
%     resultCollection{end+1} = [out1_wait1.Time + prevSeqTime, out1_wait1.Data];
%     prevSeqTime = prevSeqTime + out1_wait1.Time(end);
    
    % ############### Adjusting current SOC to initial SOC ###############
    if(prevSOC >= initialSOC)
        msg = newline + "Script 1." + newline + ...
            "Profile # " + num2str(ii) + newline +...
            "Adjusting Initial SOC (Cycle): Discharging to " +...
            num2str(initialSOC * 100) + "%. Current SOC = " +...
            num2str(prevSOC*100) + "%";
        if strcmpi(caller, "gui")
            send(randQ, msg);
        else
            disp(msg);
        end
        [out1_adj, cells_adj] = dischargeToSOC(initialSOC, adjCurr, 'cellIDs',...
            cellIDs, 'testSettings', testSettings);
        
    else
         msg = newline + "Script 1." + newline + ...
         "Profile # " + num2str(ii) + newline +...
            "Adjusting Initial SOC (Cycle): Charging to " + ...
            num2str(initialSOC*100) + "%. Current SOC = " + ...
            num2str(prevSOC*100) + "%";
        if strcmpi(caller, "gui")
            send(randQ, msg);
        else
            disp(msg);
        end
        
        [out1_adj, cells_adj] = chargeToSOC(initialSOC, adjCurr, 'cellIDs', cellIDs,...
            'testSettings', testSettings);
    end
    battTS = appendBattTS2TS(battTS, out1_adj);
    
    
    % ############### Running Profile ###############
    msg = newline + "Script 1." + newline + ...
        "Running Profile # " + ii + " : " +...
        cycleNames(ii) + " From: " + num2str(initialSOC)+...
        " To: "+ num2str(targetSOC);
    if strcmpi(caller, "gui")
        send(randQ, msg);
    else
        disp(msg);
    end
    
    [out1, cells1] = runProfileToSOC(cycleProfiles(ii), targetSOC, [],...
        'cellIDs', cellIDs, 'testSettings', testSettings);
    battTS = appendBattTS2TS(battTS, out1);
%     resultCollection{end+1} = [out1.Time + prevSeqTime, out1.Data];
%     prevSeqTime = prevSeqTime + out1.Time(end);
    
    
    %% Script 2: Get Cell Voltage to Vmin
    % Cool Down After Profile
    msg = newline + "Beginning to Cool Down after Adj. SOC. " + ...
        "Waiting for " + waitTime + " seconds";
    if strcmpi(caller, "gui")
        send(randQ, msg);
    else
        disp(msg);
    end
    [out2_wait, cell2_wait] = waitTillTime(waitTime, 'cellIDs', cellIDs,...
            'testSettings', testSettings);
    battTS = appendBattTS2TS(battTS, out2_wait);
    

    msg = newline + "Script 2." + newline + ...
        "Leveling battery voltage to discharged Voltage. ";
    if strcmpi(caller, "gui")
        send(randQ, msg);
    else
        disp(msg);
    end
    
    load(dataLocation + "007BatteryParam.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
    volt = cell2_wait.volt(end); % First column
    dischargedVolt = batteryParam.dischargedVolt(cellIDs);
    
    if strcmpi(cellConfig, 'parallel')
        curr = sum(batteryParam.ratedCapacity(cellIDs))/30; % X of rated Capacity
    else
        curr = mean(batteryParam.ratedCapacity(cellIDs))/30; % X of rated Capacity
    end

    % if cell is undervoltaged, charge back up or discharge if vice versa
    if max(volt > dischargedVolt) % Max is here incase cellIDs contains more than one cellID
       [out2, cells2] = dischargeToVolt(dischargedVolt, curr, 'cellIDs', cellIDs, ...
           'testSettings', testSettings);
        elseif max(volt < dischargedVolt)
        [out2, cells2] = chargeToVolt(dischargedVolt, curr, 'cellIDs', cellIDs, ...
           'testSettings', testSettings);
    end
    battTS = appendBattTS2TS(battTS, out2);
    
    % Can add a runProfile test based on a dither current profile
        
    %% Script 3: Fully Charge Cell
    msg = newline + "Script 3." + newline + ...
        "Fully Charging battery. ";
    if strcmpi(caller, "gui")
        send(randQ, msg);
    else
        disp(msg);
    end
    [out3, cells3] = chargeToSOC(1, adjCurr, 'cellIDs', cellIDs,...
            'testSettings', testSettings);
    battTS = appendBattTS2TS(battTS, out3);
    % Can add a runProfile test based on a dither current profile

    
    %% Finishing Touches
    % Save Data for Script 1                        
    DYNData.script1.time =    [ out1_wait.time(:)', ...
                                out1_adj.time(:)', ...
                                out1.time(:)' ];
    
    DYNData.script1.voltage = [ out1_wait.data(:, volt_ind)', ...
                                out1_adj.data(:, volt_ind)', ...
                                out1.data(:, volt_ind)' ];
                            
    DYNData.script1.current = [ out1_wait.data(:, curr_ind)', ...
                                out1_adj.data(:, curr_ind)', ...
                                out1.data(:, curr_ind)' ] * -1; % Xly by -1 since charge = +ve and dischrg = -ve in the data collection, but "runProcessDynamic.m" identifies parameters with chrg = -ve etc
                            
    DYNData.script1.ahCap = [ out1_wait.data(:, ah_ind)', ...
                                out1_adj.data(:, ah_ind)', ...
                                out1.data(:, ah_ind)' + out1_adj.data(end, ah_ind) ];
                            
    % Save Data for Script 2                        
    DYNData.script2.time =    [ out2_wait.time(:)', ...
                                out2.time(:)'  ];
    
    DYNData.script2.voltage = [ out2_wait.data(:, volt_ind)', ...
                                out2.data(:, volt_ind)'  ];
                            
    DYNData.script2.current = [ out2_wait.data(:, curr_ind)', ...
                                out2.data(:, curr_ind)' ] * -1; % Xly by -1 since charge = +ve and dischrg = -ve in the data collection, but "runProcessDynamic.m" identifies parameters with chrg = -ve etc
                            
    DYNData.script2.ahCap =   [ out2_wait.data(:, ah_ind)', ...
                                out2.data(:, ah_ind)' ];
    
                            
    % Save Data for Script 3                        
    DYNData.script3.time =     out3.time(:)' ;
    
    DYNData.script3.voltage =  out3.data(:, volt_ind)' ;
                            
    DYNData.script3.current =  out3.data(:, curr_ind)'  * -1; % Xly by -1 since charge = +ve and dischrg = -ve in the data collection, but "runProcessDynamic.m" identifies parameters with chrg = -ve etc
                            
    DYNData.script3.ahCap =    out3.data(:, ah_ind)';
                            
                            
    % Don't save battery param here, it updates the
    % good values stored by "runProfile"
    DateCompleted = string(datestr(now,'yymmdd_HHMM'));
    Filename = testSettings.saveName + "_" + DateCompleted;
    
    saveName = Filename + ".mat";
    
    save(testSettings.saveDir + "\" + saveName , 'DYNData', 'battTS');
        
        
    % Update Experiment Logs File
    updateExpLogs(saveName, testSettings.purpose, cellIDs, batteryParam);
    
    
    %     disp("Program Finished");
    
catch ME
    script_handleException;
end