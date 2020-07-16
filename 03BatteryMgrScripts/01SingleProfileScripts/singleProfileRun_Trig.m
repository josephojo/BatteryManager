%singleProfileRun_Trig
%   Runs a single profile repeatedly from 90% to 10% for the purpose of
%   collecting and eventually identifying the RC parameters for an ECM
%   model. This process is based on Dr. Gregory Plett's Enhanced Cell model
%   http://mocha-java.uccs.edu/ECE5710/index.html

try
    % % Initializations
    % script_initializeDevices; % Initialized devices like Eload, PSU etc.
    script_initializeVariables; % Run Script to initialize common variables
    
    adjCRate = 4;
    waitTime = 1800; % wait time for cool down periods in seconds
    
    if ~exist('cellIDs', 'var') || isempty(cellIDs)
        cellIDs = "AB1"; % ID in Cell Part Number (e.g BAT11-FEP-AA1). Defined again in initializeVariables
    end
    
    if ~exist('testSettings', 'var') || isempty(testSettings)
        currFilePath = mfilename('fullpath');
        % Seperates the path directory and the filename
        [path, ~, ~] = fileparts(currFilePath);

        testSettings.saveDir = extractBetween(path,"",...
            "00BattManager","Boundaries","inclusive");
        caller = "cmdWindow";
        testSettings.saveName   = "DYNData_" + cellIDs + ".mat";   
        testSettings.purpose    = "To use in identifying the RC parameters for an ECM model";
        testSettings.tempChnls  = [9, 10];
        testSettings.trigPins = []; % Fin in every pin that should be triggered
        testSettings.trigInvert = []; % Fill in 1 for every pin that is reverse polarity (needs a zero to turn on)
        testSettings.trigStartTimes = {[100]}; % cell array of vectors. each vector corresponds to each the start times for each pin
        testSettings.trigDurations = {15}; % cell array of vectors. each vector corresponds to each the duration for each pin's trigger
    end
    
    profile2Run = "CYC_UDDS";
    
    resultCollection = {};
    prevSeqTime = 0; % As code runs, this variable stores the time of the last
    %     data collected to be used as the start time for the next data
    %     collection.
    
    
    ahCounts = [];
    
    modes2Run = ["cy"]; % "cc", "cy",
       
    iterations = 1;
    prev3 = toc(testTimer);
    saveIntvl = 1; % Interval to save data (hr)
    saveInd = 1; %Initial value for the number of intermittent Saves
    
    for iter = 1:iterations
        %% CCMode
        [isMem, ind] = ismember("cc", modes2Run);
        if isMem == true
            mode = modes2Run(ind);
            ccSocTargets = [0.2564, 0.2564]; %[1, 0.8]; %csvread('015ccSocTargets.csv');
            % Order of C-rates to cycle
            ccProfile = [3]; % Training Profiles
            %         ccProfile = [3,5]; % Testing Profiles
            startProfileInd = min(ccProfile);
            endProfileInd = max(ccProfile);
            for ii = ccProfile %startProfileInd:endProfileInd
                
                if strcmpi (cellConfig, 'parallel')
                    adjCurr = sum(batteryParam.ratedCapacity(cellIDs))*1; % X of rated Capacity
                else
                    adjCurr = batteryParam.ratedCapacity(cellIDs(1))*1; % X of rated Capacity
                end
                
                for i = 1:length(ccSocTargets(:, 1))
                    targetSOC = ccSocTargets(i,2);
                    load(dataLocation + "007BatteryParam.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
                    prevSOC = batteryParam.soc(cellIDs(1));
                    initialSOC = prevSOC;
                    % Adjusting initial SOC
                    if(initialSOC > targetSOC)
                        msg = newline + "Iter: " + num2str(iter) + ...
                            " | Running CC Profile: " + num2str(ii) + "C From: " +...
                            num2str(prevSOC * 100)+ "%. To: " +...
                            num2str(targetSOC * 100) + "%. ";
                        
                        if strcmpi(caller, "gui")
                            send(randQ, msg);
                        else
                            disp(msg);
                        end
                        
                        [out, cells] = dischargeToSOC(targetSOC, adjCurr, 'cellIDs', cellIDs, 'testSettings', testSettings);
%                         resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
%                         prevSeqTime = prevSeqTime + out.Time(end);
                    else
                        msg = newline + "Iter: " + num2str(iter) + ...
                            " | Running CC Profile: " + num2str(ii) + "C From: " +...
                            num2str(prevSOC * 100)+ "%. To: " +...
                            num2str(targetSOC * 100) + "%. ";
                        
                        if strcmpi(caller, "gui")
                            send(randQ, msg);
                        else
                            disp(msg);
                        end
                        
                        [out, cells] = chargeToSOC(targetSOC, adjCurr,  'cellIDs', cellIDs, 'testSettings', testSettings);
%                         resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
%                         prevSeqTime = prevSeqTime + out.Time(end);
                    end
                    
                    % Saves Capacity when battery fully charges
                    if abs(initialSOC) > 0.985 && targetSOC == 0
                        load(dataLocation + "007BatteryParam.mat");
                        batteryParam.capacity(cellIDs) = cells.AhCap(cellIDs);
                        ahCounts(end+1, :) = cells.AhCap(cellIDs);
                        save(dataLocation + "007BatteryParam.mat", 'batteryParam');
                        disp("Saved Capacity to file: " + num2str(ahCounts(end)) + "Ah or " + ...
                            num2str(ahCounts(end) * 3600));
                    end
                                        
                    % Run Faulty Discharge for specified seconds
                    
                    if strcmpi (cellConfig, 'parallel')
                        adjCurr = sum(batteryParam.ratedCapacity(cellIDs))*ii; % X of rated Capacity
                    else
                        adjCurr = batteryParam.ratedCapacity(cellIDs(1))*ii; % X of rated Capacity
                    end
                    
                    seconds = 600;
                    out = chargeToTime(seconds, adjCurr,...
                        'cellIDs', cellIDs, 'testSettings', testSettings);
                    
                    resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    prevSeqTime = prevSeqTime + out.Time(end);
                    
                    msg = newline + "Beginning Cool Down after Adj. SOC. " + ...
                        "Waiting for " + waitTime + " seconds";
                    if strcmpi(caller, "gui")
                        send(randQ, msg);
                    else
                        disp(msg);
                    end
                    out = waitTillTime(waitTime, 'cellIDs', cellIDs, 'testSettings', testSettings);
                    
                    
                    if (toc(testTimer) - prev3) >= (saveIntvl*3600)
                        prev3 = toc(testTimer);
                        msg = "Backing Data up for Save Interval: " + num2str(saveInd);
                        if strcmpi(caller, "gui")
                            send(randQ, msg);
                        else
                            disp(msg);
                        end
                        
                        % Change the variable name before saving
                        eval(['resultCollection_' num2str(saveInd) ' = resultCollection;']);
                        if saveInd == 1
                            save(saveLocation  + "02RawNNData\" +...
                                "BackUpNNData", "resultCollection_" + num2str(saveInd))
                        else
                            save(saveLocation  + "02RawNNData\" +...
                                "BackUpNNData", "resultCollection_" + num2str(saveInd)...
                                , '-append');
                        end
                        disp("Saved Data Interval: " + num2str(saveInd) + newline)
                        
                        saveInd = saveInd+1;
                    end
                    
                    disp("Data Stored in Collection." + newline);
                end
            end
        end
        
        %% DriveCycleMode
        [isMem, ind] = ismember("cy", modes2Run);
        if isMem == true %strcmpi(mode, 'cc')
            
            % SOC to Adjust the current SOC
            if strcmpi (cellConfig, 'parallel')
                adjCurr = sum(batteryParam.ratedCapacity(cellIDs))*adjCRate; % X of rated Capacity
            else
                adjCurr = mean(batteryParam.ratedCapacity(cellIDs))*adjCRate; % X of rated Capacity
            end
            
            cur = pwd;
            cd(dataLocation)
            if strcmpi (cellConfig, 'single')
                searchCriteria = "002_" + cellIDs(1)+ "_CurrProfiles*";
            else
                searchCriteria = "002_" + num2str(numCells) + upper(cellConfig(1)) + ...
                    batteryParam.chemistry(cellIDs(1))+ "_CurrProfiles*";
            end
            fName = dir(searchCriteria);
            cd(cur)
            
            % Create Current profile if it does not currently exist
            if isempty(fName)
                if strcmpi(cellConfig, 'parallel')
                    maxCurr = sum(batteryParam.maxCurr(cellIDs));
                else
                    maxCurr = batteryParam.maxCurr(cellIDs);
                end
                multiProfileGen(maxCurr,...
                    cellIDs, dataLocation, cellConfig, batteryParam)
                cur = pwd;
                cd(dataLocation)
                fName = dir(searchCriteria);
                cd(cur)
            end
            load(fName.name); % Loads CycleProfiles and others
            
            mode = modes2Run(ind);
            %     cycleSocTargets = csvread('015cycleSocTargets.csv');
            cycleSocTargets = [0.9, 0.1]; 
            startProfileInd = find(cycleNames == profile2Run); 
            endProfileInd = startProfileInd; % length(cycleProfiles);
            
            for i = 1:length(cycleSocTargets(:, 1))
                initialSOC = cycleSocTargets(i,1);
                targetSOC = cycleSocTargets(i,2);
                for ii = startProfileInd:endProfileInd
                    load(dataLocation + "007BatteryParam.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
                    prevSOC = mean(batteryParam.soc(cellIDs));
                    
                    %% Adjusting current SOC to initial SOC
                    if(prevSOC >= initialSOC)
                        msg = newline + "Iter: " + num2str(iter) + ...
                            " | Profile # " + num2str(ii) + newline +...
                            "Adjusting Initial SOC (Cycle): Discharging to " +...
                            num2str(initialSOC * 100) + "%. Current SOC = " +...
                            num2str(prevSOC*100) + "%";
                        if strcmpi(caller, "gui")
                            send(randQ, msg);
                        else
                            disp(msg);
                        end
                        out = dischargeToSOC(initialSOC, adjCurr, 'cellIDs', cellIDs, 'testSettings', testSettings);
                        resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                        prevSeqTime = prevSeqTime + out.Time(end);
                    else
                        msg = newline + "Iter: " + num2str(iter) + ...
                            " | Profile # " + num2str(ii) + newline +...
                            "Adjusting Initial SOC (Cycle): Charging to " + ...
                            num2str(initialSOC*100) + "%. Current SOC = " + ...
                            num2str(prevSOC*100) + "%";
                        if strcmpi(caller, "gui")
                            send(randQ, msg);
                        else
                            disp(msg);
                        end
                        
                        out = chargeToSOC(initialSOC, adjCurr, 'cellIDs', cellIDs, 'testSettings', testSettings);
                        resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                        prevSeqTime = prevSeqTime + out.Time(end);
                    end
                    
                    %% Cool Down After Adjusting SOC
                    msg = newline + "Beginning Cool Down after Adj. SOC. " + ...
                        "Waiting for " + waitTime + " seconds";
                        if strcmpi(caller, "gui")
                            send(randQ, msg);
                        else
                            disp(msg);
                        end
                    out = waitTillTime(waitTime, 'cellIDs', cellIDs, 'testSettings', testSettings);
                    resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    prevSeqTime = prevSeqTime + out.Time(end);

                    
                    %% Running Profile
                    msg = newline + "Iter: " + num2str(iter) + ...
                        " | Running Profile # " + ii + " : " +...
                        cycleNames(ii) + " From: " + num2str(initialSOC)+...
                        " To: "+ num2str(targetSOC);
                    if strcmpi(caller, "gui")
                        send(randQ, msg);
                    else
                        disp(msg);
                    end

                    [out, cells_lastTest] = runProfileToSOC(cycleProfiles(ii), targetSOC, [],...
                        'cellIDs', cellIDs, 'testSettings', testSettings);
                    resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    prevSeqTime = prevSeqTime + out.Time(end);

                    
                    %% Cool Down After Profile
                    msg = newline + "Beginning Cool Down after Adj. SOC. " + ...
                        "Waiting for " + waitTime + " seconds";
                        if strcmpi(caller, "gui")
                            send(randQ, msg);
                        else
                            disp(msg);
                        end
                    out = waitTillTime(waitTime, 'cellIDs', cellIDs);

                    resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    prevSeqTime = prevSeqTime + out.Time(end);
                    
%                     disp("Data Stored in Collection." + newline);
                end
            end
        end
        
    end
    %% Finishing Touches
    
    % Don't save battery param here, it updates the
    % good values stored by "runProfile"
        
    DateCompleted = string(datestr(now,'yymmdd'));
    
    Filename = testSettings.saveName + "_" + DateCompleted;
        
    saveName = Filename + ".mat";
    
    save(testSettings.saveDir + "02RawNNData\" + saveName , 'resultCollection', 'ahCounts');
    
    script_postProcessResCollection;
    
    % Remove the AhCap columns
%     resultCollection_withAhCap = resultCollection;
    resultCollection(:, [5:8, 11]) = [];
    
    save(saveLocation + "01NNData\" + saveName , 'resultCollection');
%     if ~isempty(ahCounts)
%         save(saveLocation + "02RawNNData\AhCounts_" + saveName , 'ahCounts');
%     end
        
    % Update Experiment Logs File
    updateExpLogs(fileName, testSettings.purpose, cellIDs, batteryParam);

    
%     disp("Program Finished");
    
catch ME
    sscript_resetDevices;
    if caller == "cmdWindow"
        rethrow(MEX);
    else
        send(errorQ, MEX)
    end
end