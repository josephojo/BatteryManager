%multiProfileRuns
%   Runs a single or multiple current profiles based on driving cycle in
%   01DrivingCycles directory.


%Change Log
%   REVISION    CHANGE                                          DATE-YYMMDD
%   00          Initial Revision                                190304
%   01          Adopted from P01 - NN4CoreTemp                  190520
%   02          After purchase of new PSU, CV charging          190711
%               is now possible.
clearvars; clc;
try
    
    cellID = "AA8"; % ID in Cell Part Number (e.g BAT11-FEP-AA1). Defined again in initializeVariables
    
%     disp("Validating SOC...");
%     validateSOC;
    
%     disp("Counting Capacity ...");
%     AhCounter;
    
    
    % % Initializations
    % script_initializeDevices; % Initialized devices like Eload, PSU etc.
    script_initializeVariables; % Run Script to initialize common variables
    
    % SOC Adjustment current
    adjCurr = (batteryParam.ratedCapacity(cellID)*1); % X of rated Capacity
    
    resultCollection = {};
    figs = {};
    prevSeqTime = 0; % As code runs, this variable stores the time of the last
    % data collected to be used as the start time for the next data
    % collection.
    
    heatPad = false;
    
    ahCounts = [];
    
    modes2Run = ["cy"];
    
    %% DriveCycleMode
    [isMem, ind] = ismember("cy", modes2Run);
    if isMem == true %strcmpi(mode, 'cc')
        
        cur = pwd;
        cd(dataLocation)
        fName = dir("002_" + cellID + "_CurrProfiles*");
        cd(cur)

        if strcmpi(batteryParam.chemistry(cellID), "LFP")
            cRate = 6;
        else
            cRate = 3;
        end
        
        % Create Current profile if it does not currently exist
        if isempty(fName)
            multiProfileGen((batteryParam.ratedCapacity(cellID)*cRate),...
                cellID, dataLocation)
            cur = pwd;
            cd(dataLocation)
            fName = dir("002_" + cellID + "_CurrProfiles*");
            cd(cur)        
        end
        load(fName.name);
        
        mode = modes2Run(ind);
        %     cycleSocTargets = csvread('015cycleSocTargets.csv');
        cycleSocTargets = [0.8,0.3];
        startProfileInd = 1; % 6;
        endProfileInd = 5; % length(cycleProfiles);
        for i = 1:1 %length(cycleSocTargets)
            initialSOC = cycleSocTargets(i,1);
            targetSOC = cycleSocTargets(i,2);
            for ii = startProfileInd:endProfileInd
                load(dataLocation + "007BatteryParam.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
                prevSOC = batteryParam.soc(cellID);
                
                % Adjusting initial SOC
                if(prevSOC >= initialSOC)
                    disp(newline + "Profile # " + num2str(ii) + newline +...
                        "Adjusting Initial SOC (Cycle): Discharging to " +...
                        num2str(initialSOC * 100) + "%. Current SOC = " +...
                        num2str(prevSOC*100) + "%")
                    out = dischargeTo(initialSOC, adjCurr, cellID);
                    resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    prevSeqTime = prevSeqTime + out.Time(end);
                    disp("Done Discharging" + newline);
                else
                    disp(newline + "Profile # " + num2str(ii) + newline +...
                        "Adjusting Initial SOC (Cycle): Charging to " + ...
                        num2str(initialSOC*100) + "%. Current SOC = " + ...
                        num2str(prevSOC*100) + "%")
                    out = chargeTo(initialSOC, adjCurr, cellID);
                    resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    prevSeqTime = prevSeqTime + out.Time(end);
                    disp("Done Charging" + newline);
                end
                
%                 % Wait till a random temperature within a range.
%                 % Random number falls between the most recent ambTemp measurement
%                 % and the most recent surfTemp *0.8. Similar to randi([20 30]).
%                 L = length(out.Data(1, :));
%                 for ind = L:-1:1
%                     if out.Data(1,ind) < 15
%                         startCol = ind +1;
%                         break;
%                     end
%                 end
%                 loTemp = ceil(out.Data(end, startCol));
%                 hiTemp = floor(out.Data(end, startCol) + (out.Data(end, startCol+1)-out.Data(end, startCol))*0.8);
%                 if hiTemp < loTemp
%                     hiTemp = loTemp;
%                 end
%                 out = waitTillTemp(randi([loTemp, hiTemp]), cellID);

                disp(newline + "Waiting. Cycle # " + num2str(ii))
                out = waitTillTime(600, false, cellID);
                
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
                
                disp(newline + "Running Profile # " + ii + " : " + cycleNames(ii) + " From: " + num2str(initialSOC)+ " To: "+ num2str(targetSOC))
                out = runProfile(cycleProfiles(ii), initialSOC, targetSOC, mode, heatPad, cellID);
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
                
                
                disp("Data Stored in Collection." + newline);
            end
        end
    end
    
    %% CCMode
    [isMem, ind] = ismember("cc", modes2Run);
    if isMem == true %strcmpi(mode, 'cc')
        mode = modes2Run(ind);
        ccSocTargets = csvread('015ccSocTargets.csv');
        ccProfile = [1, 2, 3, 4, 5, 6, 6]; % Order of C-rates to cycle
        startProfileInd = min(ccProfile);
        endProfileInd = max(ccProfile);
        for ii = ccProfile %startProfileInd:endProfileInd
            
            adjCurr = (batteryParam.ratedCapacity(cellID)*ii); % X of rated Capacity
            
            for i = 1:length(ccSocTargets)
                targetSOC = ccSocTargets(i,2);
                load(dataLocation + "007BatteryParam.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
                prevSOC = batteryParam.soc(cellID);
                initialSOC = prevSOC;
                % Adjusting initial SOC
                if(initialSOC > targetSOC)
                    disp(newline + "Running Profile: " + num2str(ii) + "C From: " + num2str(prevSOC * 100)+ "%. To: " + num2str(targetSOC * 100) + "%. ")
                    out = dischargeTo(targetSOC, adjCurr, cellID);
                    resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    prevSeqTime = prevSeqTime + out.Time(end);
                else
                    disp(newline + "Running Profile: " + num2str(ii) + "C From: " + num2str(prevSOC * 100)+ "%. To: " + num2str(targetSOC * 100) + "%. ")
                    out = chargeTo(targetSOC, adjCurr, cellID);
                    resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    prevSeqTime = prevSeqTime + out.Time(end);
                end
                
                if abs(initialSOC) <= 2.0 && targetSOC == 1
                    load(dataLocation + "007BatteryParam.mat");
                    batteryParam.capacity(cellID) = out.Data(end, 4);
                    ahCounts(end+1) = out.Data(end, 4);
                    save(dataLocation + "007BatteryParam.mat", 'batteryParam');
                    disp("Saved Capacity to file: " + num2str(out.Data(end, 4)) + "Ah or " + ...
                        num2str(out.Data(end, 4) * 3600));
                end
                
                if numThermo == 3
                    out = waitTillTemp('surfcore', 'cellID', cellID);
                else
                % Wait till a random temperature within a range.
                % Random number falls between the most recent ambTemp measurement
                % and the most recent surfTemp *0.8. Similar to randi([20 30]).
                L = length(out.Data(1, :));
                for ind = L:-1:1
                    if out.Data(1,ind) < 15
                        startCol = ind +1;
                        break;
                    end
                end
                loTemp = ceil(out.Data(end, startCol));
                hiTemp = round(out.Data(end, startCol) + (out.Data(end, startCol+1)-out.Data(end, startCol))*0.8);
                if hiTemp < loTemp
                    hiTemp = loTemp;
                end
                out = waitTillTemp('surf', randi([loTemp, hiTemp]), 'cellID', cellID);
                end

%                 disp(newline + "Running Cycle # " + num2str(iter))
%                 out = waitTillTime(600, false, cellID);
                
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
                
%                 if(targetSOC < initialSOC)
%                     profileTS = timeseries(-ccProfiles(ii).Data, ccProfiles(ii).Time);
%                 elseif (targetSOC > initialSOC)
%                     profileTS = ccProfiles(ii);
%                 else
%                     warning("Initial and Final SOC values are Equal (" + num2str(targetSOC*100) +  "%)");
%                     break;
%                 end
%                 
%                 disp(newline + "Running Profile: " + ccNames(ii) + " From: " + num2str(initialSOC)+ " To: " + num2str(targetSOC))
%                 out = runProfile(profileTS, initialSOC, targetSOC, mode, heatPad, cellID);
%                 
%                 resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
%                 prevSeqTime = prevSeqTime + out.Time(end);
                disp("Data Stored in Collection." + newline);
                %         figs{end+1} = fig;
            end
        end
    end
    
    %% Finishing Touches
    
    % Don't save battery param here, it updates the
    % good values stored by "runProfile"
    
    saveLocation = ['C:\Users\User\Documents\00BattManager\'];
    
    saveName = cellID + "NNData_" + upper(mode) + ...
        num2str(startProfileInd) + "-" + num2str(endProfileInd) +...
        "_"+ datestr(now,'yymmdd')+".mat";
    
    save(saveLocation + "02RawNNData\" + saveName , 'resultCollection');
    
    script_postProcessResCollection;
    
    
    % Remove the AhCap column
    resultCollection_withAhCap = resultCollection;
    resultCollection(:, startCol - 1) = [];
    
    save(saveLocation + "01NNData\" + saveName , 'resultCollection');
    
    disp("Program Finished");
    
catch ME
    script_resetDevices;
    rethrow(ME);
end