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
    
    if ~exist('battID', 'var') || isempty(battID)
        % battID should only be one cell
        battID = "AB1"; % ID in Cell Part Number (e.g BAT11-FEP-AA1). Defined again in initializeVariables
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
        [filePath, contents, ~] = fileparts(currFilePath);
        
        str = extractBefore(filePath, "03BatteryMgrScripts");

        testSettings.saveDir = str + "01CommonDataForBattery";
        
        testSettings.saveName   = "01DYNData_" + battID;
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
        adjCurr = sum(batteryParam.ratedCapacity(battID))*adjCRate; % X of rated Capacity
    else
        adjCurr = mean(batteryParam.ratedCapacity(battID))*adjCRate; % X of rated Capacity
    end
    
    profile_cRate = 1;
    cur = pwd;
    cd(dataLocation)
    if strcmpi (cellConfig, 'single')
        searchCriteria = "002_" + battID(1) + "_" + profile_cRate + "C_CurrProfiles*";
    else
        searchCriteria = "002_" + num2str(numCells) + upper(cellConfig(1)) + ...
            batteryParam.chemistry(battID(1)) + "_" + profile_cRate + "C_CurrProfiles*";
    end
    contents = dir(searchCriteria);
    cd(cur)
    
    % Create Current profile if it does not currently exist
    if isempty(contents)
        multiProfileGen(profile_cRate,...
            battID, dataLocation, cellConfig, batteryParam)
        cur = pwd;
        cd(dataLocation)
        contents = dir(searchCriteria);
        cd(cur)
    end
    load(contents.name); % Loads CycleProfiles and others
    
    startProfileInd = find(cycleNames == profile2Run);
    endProfileInd = startProfileInd; % length(cycleProfiles);
    
    initialSOC = cycleSocTargets(1,1);
    targetSOC = cycleSocTargets(1,2);
    
    ii = startProfileInd:endProfileInd;
    load(dataLocation + "007BatteryParam.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
    prevSOC = mean(batteryParam.soc(battID));
    
    % ############### Cool Down Before Adjusting SOC ###############
    msg = newline + "Beginning to Cool Down Before Adj. SOC. " + ...
        "Waiting for " + waitTime + " seconds";
    if strcmpi(caller, "gui")
        send(randQ, msg);
    else
        disp(msg);
    end
    [out1_wait, cell1_wait] = waitTillTime(waitTime, 'battID', battID,...
        'testSettings', testSettings);
    testData = out1_wait;
    
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
        [out1_adj, cells_adj] = dischargeToSOC(initialSOC, adjCurr, 'battID',...
            battID, 'testSettings', testSettings);
        
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
        
        [out1_adj, cells_adj] = chargeToSOC(initialSOC, adjCurr, 'battID', battID,...
            'testSettings', testSettings);
    end
    testData = appendTestDataStruts(testData, out1_adj);
    
    
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
        'battID', battID, 'testSettings', testSettings);
    testData = appendTestDataStruts(testData, out1);
   
    
    %% Script 2: Get Cell Voltage to Vmin
    % Cool Down After Profile
    msg = newline + "Beginning to Cool Down after Adj. SOC. " + ...
        "Waiting for " + waitTime + " seconds";
    if strcmpi(caller, "gui")
        send(randQ, msg);
    else
        disp(msg);
    end
    [out2_wait, cell2_wait] = waitTillTime(waitTime, 'battID', battID,...
            'testSettings', testSettings);
    testData = appendTestDataStruts(testData, out2_wait);
    

    msg = newline + "Script 2." + newline + ...
        "Leveling battery voltage to discharged Voltage. ";
    if strcmpi(caller, "gui")
        send(randQ, msg);
    else
        disp(msg);
    end
    
    load(dataLocation + "007BatteryParam.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
    volt = cell2_wait.volt(end); % First column
    dischargedVolt = batteryParam.dischargedVolt(battID);
    
    if strcmpi(cellConfig, 'parallel')
        curr = sum(batteryParam.ratedCapacity(battID))/30; % X of rated Capacity
    else
        curr = mean(batteryParam.ratedCapacity(battID))/30; % X of rated Capacity
    end

    % if cell is undervoltaged, charge back up or discharge if vice versa
    if max(volt > dischargedVolt) % Max is here incase battID contains more than one battID
       [testData, metadata, testSettings] = dischargeToVolt(dischargedVolt, curr, 'battID', battID, ...
           'testSettings', testSettings);
        elseif max(volt < dischargedVolt)
        [out2, cells2] = chargeToVolt(dischargedVolt, curr, 'battID', battID, ...
           'testSettings', testSettings);
    end
    testData = appendTestDataStruts(testData, out2);
    
    % Can add a runProfile test based on a dither current profile
        
    %% Script 3: Fully Charge Cell
    msg = newline + "Script 3." + newline + ...
        "Fully Charging battery. ";
    if strcmpi(caller, "gui")
        send(randQ, msg);
    else
        disp(msg);
    end
    [out3, cells3] = chargeToSOC(1, adjCurr, 'battID', battID,...
            'testSettings', testSettings);
    testData = appendTestDataStruts(testData, out3);
    % Can add a runProfile test based on a dither current profile

    
    %% Finishing Touches
    % Save Data for Script 1                        
    DYNData.script1.time =    [ out1_wait.time(:)', ...
                                out1_adj.time(:)', ...
                                out1.time(:)' ];
    
    DYNData.script1.voltage = [ out1_wait.packVolt', ...
                                out1_adj.packVolt', ...
                                out1.packVolt' ];
                            
    DYNData.script1.current = [ out1_wait.packCurr', ...
                                out1_adj.packCurr', ...
                                out1.packCurr' ] * -1; % Xly by -1 since charge = +ve and dischrg = -ve in the data collection, but "runProcessDynamic.m" identifies parameters with chrg = -ve etc
                            
    DYNData.script1.ahCap = [ out1_wait.packCap', ...
                                out1_adj.packCap', ...
                                out1.packCap' + out1_adj.data(end, ah_ind) ];
                            
    % Save Data for Script 2                        
    DYNData.script2.time =    [ out2_wait.time(:)', ...
                                out2.time(:)'  ];
    
    DYNData.script2.voltage = [ out2_wait.packVolt', ...
                                out2.packVolt'  ];
                            
    DYNData.script2.current = [ out2_wait.packCurr', ...
                                out2.packCurr' ] * -1; % Xly by -1 since charge = +ve and dischrg = -ve in the data collection, but "runProcessDynamic.m" identifies parameters with chrg = -ve etc
                            
    DYNData.script2.ahCap =   [ out2_wait.packCap', ...
                                out2.packCap' ];
    
                            
    % Save Data for Script 3                        
    DYNData.script3.time =     out3.time(:)' ;
    
    DYNData.script3.voltage =  out3.packVolt' ;
                            
    DYNData.script3.current =  out3.packCurr'  * -1; % Xly by -1 since charge = +ve and dischrg = -ve in the data collection, but "runProcessDynamic.m" identifies parameters with chrg = -ve etc
                            
    DYNData.script3.ahCap =    out3.packCap';
                            
                            
    % Don't save battery param here, it updates the
    % good values stored by "runProfile"
    DateCompleted = string(datestr(now,'yymmdd_HHMM'));
    Filename = testSettings.saveName + "_" + DateCompleted;
    
    saveName = Filename + ".mat";
    
    save(testSettings.saveDir + "\" + saveName , 'DYNData', 'testData');
        
        
    % Update Experiment Logs File
    updateExpLogs(saveName, testSettings.purpose, battID, batteryParam);
    
    
    %     disp("Program Finished");
    
catch ME
    script_handleException;
end