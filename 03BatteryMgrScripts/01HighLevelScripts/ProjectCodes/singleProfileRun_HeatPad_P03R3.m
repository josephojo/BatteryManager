%multiProfileRuns
%   Runs a single or multiple current profiles based on driving cycle in
%   01DrivingCycles directory.


%Change Log
%   REVISION    CHANGE                                          DATE-YYMMDD
%   00          Initial Revision                                190304
%   01          Adopted from P01 - NN4CoreTemp                  190520
%   02          After purchase of new PSU, CV charging          190711
%               is now possible.
%   03          Implemented functionality for multi-cell stacks 191115

% clearvars; clc;
try
    
    cellIDs = ["AA7"]; % ID in Cell Part Number (e.g BAT11-FEP-AA1). Defined again in initializeVariables
    
    %     disp("Validating SOC...");
    %     validateSOC;
    
    %     AhCounter(cellIDs, 1);
    
    
    % % Initializations
    % script_initializeDevices; % Initialized devices like Eload, PSU etc.
    script_initializeVariables; % Run Script to initialize common variables
    
    % SOC Adjustment current
    if strcmpi (cellConfig, 'parallel')
        adjCurr = sum(batteryParam.ratedCapacity(cellIDs))*1; % X of rated Capacity
    else
        adjCurr = batteryParam.ratedCapacity(cellIDs(1))*1; % X of rated Capacity
    end
    
    resultCollection = {};
    figs = {};
    prevSeqTime = 0; % As code runs, this variable stores the time of the last
    %     data collected to be used as the start time for the next data
    %     collection.
    
    runHtPad = true;
    htPadPin = 4;
    htPadStartTime = 100; % seconds into process
    htPadDuration = 15;
    
    
    adjCRate = 4;
    
    % This is the column where the Ah in resultCollection.Data (without time)
    % is stored.
    AhCapInd = [4]; 
    
    ahCounts = [];
    
    modes2Run = ["cy"]; % "cc", "cy",
    
    Filename   = "AA7_FaultedData2_03L";
    Purpose    = "Rnd 2 NN Faulted Data consisting of CY Data (EUDC). " + ...
        " Rerunning this again since temp in AA7_FaultedData_03L_200109 rises more than AA5 and AA6 for paper. Need 50°C temp peak.";
    
    
%     Filename   = "AA6_FaultedData_3cChg_03L";
%     Purpose    = "NN Faulted Data consisting of CC charge at 3C. " + ...
%         " Test is run for a total of 600 seconds. Previous data has an abrupt temp rise due to the TC module";
%     
    %     prompt = {'Please Enter a name to save the data: ', 'Provide a purpose for the experiment: '};
    %         dlgtitle = ['New Multi-Profile Experiment'];
    %         dims = [1 50; 7 50];
    %         definput = {'PK01_NNData_01S', 'NN Training Data for P01_Rev5'};
    %         params = inputdlg(prompt,dlgtitle,dims,definput);
    %
    %         Filename   = string(params{1});
    %         Purpose    = string(params{2});
    
    %     if length(modes2Run) > 1 && ~exist('saveName', 'var')
    %        saveName = string(inputdlg('What SaveName would you like to use?: ', 'Save Name'));
    %     end
    
    iterations = 1;
    prev3 = toc;
    saveIntvl = 1; % Interval to save data (hr)
    saveInd = 1; % Number of intermittent Saves
    
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
                        disp(newline + "Iter: " + num2str(iter) + ...
                            " | Running Profile: " + num2str(ii) + "C From: " +...
                            num2str(prevSOC * 100)+ "%. To: " +...
                            num2str(targetSOC * 100) + "%. ")
                        out = dischargeTo(targetSOC, adjCurr, 'cellIDs', cellIDs);
%                         resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
%                         prevSeqTime = prevSeqTime + out.Time(end);
                    else
                        disp(newline + "Iter: " + num2str(iter) + ...
                            " | Running CC Profile: " + num2str(ii) + "C From: " +...
                            num2str(prevSOC * 100)+ "%. To: " +...
                            num2str(targetSOC * 100) + "%. ")
                        out = chargeTo(targetSOC, adjCurr,  'cellIDs', cellIDs);
%                         resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
%                         prevSeqTime = prevSeqTime + out.Time(end);
                    end
                    
                    % Saves Capacity when battery fully charges
                    if abs(initialSOC) <= 0.02 && targetSOC == 1
                        load(dataLocation + "007BatteryParam.mat");
                        batteryParam.capacity(cellIDs) = out.Data(end, AhCapInd);
                        ahCounts(end+1, :) = out.Data(end, AhCapInd);
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
                        'cellIDs', cellIDs,...
                        'trig1', runHtPad,...
                        'trig1_pin', htPadPin,...
                        'trig1_startTime', htPadStartTime,...
                        'trig1_duration',  htPadDuration );
                    
                    resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    prevSeqTime = prevSeqTime + out.Time(end);
                    
                    if numThermo > 2
                        out = waitTillTemp('surfcore', 'cellIDs', cellIDs);
                    else
                        %{
%                     % Wait till a random temperature within a range.
%                     % Random number falls between the most recent ambTemp measurement
%                     % and the most recent surfTemp *0.8. Similar to randi([20 30]).
%                     L = length(out.Data(1, :));
%                     for ind = L:-1:1
%                         if out.Data(1,ind) < 15
%                             startCol = ind +1;
%                             break;
%                         end
%                     end
%                     loTemp = ceil(out.Data(end, startCol));
%                     hiTemp = round(out.Data(end, startCol) + (out.Data(end, startCol+1)-out.Data(end, startCol))*0.8);
%                     if hiTemp < loTemp
%                         hiTemp = loTemp;
%                     end
%                     out = waitTillTemp('surf', randi([loTemp, hiTemp]), 'cellID', cellID);
                        %}
                        
%                         disp(newline + "Running CC Profile " + num2str(ii) + "C")
%                         out = waitTillTime(600, 'cellIDs', cellIDs);
                    end
%                     resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
%                     prevSeqTime = prevSeqTime + out.Time(end);
                    
                    if (toc - prev3) >= (saveIntvl*3600)
                        prev3 = toc;
                        disp("Beginning to Save Data Interval: " + num2str(saveInd))
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
                fName = dir("002_" + cellIDs(1)+ "_CurrProfiles*");
            else
                fName = dir("002_" + num2str(numCells) + upper(cellConfig(1)) + ...
                    batteryParam.chemistry(cellIDs(1))+ "_CurrProfiles*");
            end
            cd(cur)
            
            if strcmpi(batteryParam.chemistry(cellIDs(1)), "LFP")
                cRate = 6;
            else
                cRate = 3;
            end
            
            % Create Current profile if it does not currently exist
            if isempty(fName)
                multiProfileGen(sum(batteryParam.ratedCapacity(cellIDs))*cRate,...
                    cellIDs, dataLocation, cellConfig, batteryParam)
                cur = pwd;
                cd(dataLocation)
                fName = dir("002_" + num2str(numCells) + upper(cellConfig(1)) + ...
                    batteryParam.chemistry(cellIDs(1))+ "_CurrProfiles*");
                cd(cur)
            end
            load(fName.name); % Loads CycleProfiles and others
            
            mode = modes2Run(ind);
            %     cycleSocTargets = csvread('015cycleSocTargets.csv');
            cycleSocTargets = [0.8, 0.1]; %[1, 0.1; 0.8, 0.1; 0.6, 0.1]; % ; 0.5, 0.1];
            startProfileInd = 1; % 6;
            endProfileInd = 1; % length(cycleProfiles);
            for i = 1:length(cycleSocTargets(:, 1))
                initialSOC = cycleSocTargets(i,1);
                targetSOC = cycleSocTargets(i,2);
                for ii = startProfileInd:endProfileInd
                    load(dataLocation + "007BatteryParam.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
                    prevSOC = mean(batteryParam.soc(cellIDs));
                    
                    %% Adjusting current SOC to initial SOC
                    if(prevSOC >= initialSOC)
                        disp(newline + "Iter: " + num2str(iter) + ...
                            " | Profile # " + num2str(ii) + newline +...
                            "Adjusting Initial SOC (Cycle): Discharging to " +...
                            num2str(initialSOC * 100) + "%. Current SOC = " +...
                            num2str(prevSOC*100) + "%")
                        out = dischargeTo(initialSOC, adjCurr, 'cellIDs', cellIDs);
%                         if ~isempty(out.Time)
%                             resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
%                             prevSeqTime = prevSeqTime + out.Time(end);
%                         end
                        disp("Done Discharging" + newline);
                    else
                        disp(newline + "Iter: " + num2str(iter) + ...
                            " | Profile # " + num2str(ii) + newline +...
                            "Adjusting Initial SOC (Cycle): Charging to " + ...
                            num2str(initialSOC*100) + "%. Current SOC = " + ...
                            num2str(prevSOC*100) + "%")
                        out = chargeTo(initialSOC, adjCurr, 'cellIDs', cellIDs);
%                         if ~isempty(out.Time)
%                             resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
%                             prevSeqTime = prevSeqTime + out.Time(end);
%                         end
                        disp("Done Charging" + newline);
                    end
                    
                    %% Cool Down After Adjusting SOC
                    %                 if numThermo > 2
                    %                     out = waitTillTemp('surfcore', 'cellIDs', cellIDs);
                    %                 else
                    %                     waitTime = 600; % in seconds
                    %                     disp(newline + "Beginning Cool Down after Adj. SOC. " + ...
                    %                         "Waiting for " + waitTime + " seconds")
                    %                     out = waitTillTime(waitTime, 'cellIDs', cellIDs);
                    %                 end
                    %
                    %                 resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    %                 prevSeqTime = prevSeqTime + out.Time(end);
                    
                    %% Running Profile
                    disp(newline + "Iter: " + num2str(iter) + ...
                        " | Running Profile # " + ii + " : " +...
                        cycleNames(ii) + " From: " + num2str(initialSOC)+...
                        " To: "+ num2str(targetSOC))
                    out = runProfile(cycleProfiles(ii), initialSOC, targetSOC, mode,...
                        'cellIDs', cellIDs,...
                        'trig1', runHtPad,...
                        'trig1_pin', htPadPin,...
                        'trig1_startTime', htPadStartTime,...
                        'trig1_duration',  htPadDuration );
                    
                    resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    prevSeqTime = prevSeqTime + out.Time(end);
                    
                    %% Cool Down After Profile
                    %                 if numThermo > 2
                    %                     out = waitTillTemp('surfcore', 'cellIDs', cellIDs);
                    %                 else
                    %                     waitTime = 600; % in seconds
                    %                     disp(newline + "Beginning Cool Down after runProfile. Waiting for " + waitTime + " seconds")
                    %                     out = waitTillTime(waitTime, 'cellIDs', cellIDs);
                    %                 end
                    %
                    %                 resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    %                 prevSeqTime = prevSeqTime + out.Time(end);
                    %
                    
                    disp("Data Stored in Collection." + newline);
                end
            end
        end
        
    end
    %% Finishing Touches
    
    % Don't save battery param here, it updates the
    % good values stored by "runProfile"
    
    saveLocation = ['C:\Users\User\Documents\00BattManager\'];
    
    DateCompleted = string(datestr(now,'yymmdd'));
    
    Filename   = Filename + "_" + DateCompleted;
    
    %     if length(modes2Run) == 1
    %     saveName = cellID + "NNData_" + upper(mode) + ...
    %         num2str(startProfileInd) + "-" + num2str(endProfileInd) +...
    %         "_"+ datestr(now,'yymmdd')+".mat";
    %     end
    
    saveName = Filename + ".mat";
    
    save(saveLocation + "02RawNNData\" + saveName , 'resultCollection');
    
    script_postProcessResCollection;
    
    % Remove the AhCap columns
%     resultCollection_withAhCap = resultCollection;
    resultCollection(:, [5:8, 11]) = [];
    
    save(saveLocation + "01NNData\" + saveName , 'resultCollection');
    if ~isempty(ahCounts)
        save(saveLocation + "02RawNNData\AhCounts_" + saveName , 'ahCounts');
    end
        
    % Update Experiment Logs File
    T = readtable(saveLocation + "ExperimentLogs.xlsx");
    
    BatteryChem = batteryParam.chemistry(cellIDs(1));
    CapacityLeft = "";
    Features = "";
    
    CellIDs = "";
    for i = 1:numCells
        if i ~= 1
            CellIDs = CellIDs + ", ";
        end
        CellIDs = CellIDs + cellIDs(i);
    end
    Tnew = table(Purpose,Filename,CellIDs,DateCompleted,BatteryChem,...
        CapacityLeft, Features);
    
    T = [T;Tnew];
    
    writetable(T, saveLocation + "ExperimentLogs.xlsx",'Sheet',1,'Range','A1')
    
    disp("Experiment Log Updated");
    
    disp("Program Finished");
    
catch ME
    script_resetDevices;
    rethrow(ME);
end