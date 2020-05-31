%multiProfileRuns
%   Runs a single or multiple current profiles based on driving cycle in 
%   01DrivingCycles directory.   

%Change Log
%   REVISION    CHANGE                                          DATE-YYMMDD
%   00          Initial Revision                                190304
%   01          Adopted from P01 - NN4CoreTemp                  190520
%   02          After purchase of new PSU, CV charging          190711
%               is now possible.

try
    cellID = "AA5"; % ID in Cell Part Number (e.g BAT11-FEP-AA1). Defined again in initializeVariables
    
    disp("Validating SOC...");
    validateSOC;

            
    % % Initializations
    % script_initializeDevices; % Initialized devices like Eload, PSU etc.
    script_initializeVariables; % Run Script to initialize common variables
    
    cur = pwd;
    cd(dataLocation)
    fName = dir("002_" + cellID + "_CurrProfiles*");
    cd(cur)
    
    if strcmpi(batteryParam.chemistry(cellID), "LFP")
        cRate = 6;
    else
        cRate = 5;
    end
    
    % Create Current profile if it does not currently exist
    if isempty(fName)
        multiProfileGen((batteryParam.ratedCapacity(cellID)*cRate),...
            cellID, dataLocation)
    end
    
    % SOC Adjustment current
    adjCurr = (batteryParam.ratedCapacity(cellID)*1); % X of rated Capacity
        
    load(fName.name);
    resultCollection = {};
    figs = {};
    prevSeqTime = 0; % As code runs, this variable stores the time of the last
    % data collected to be used as the start time for the next data
    % collection.
    
    %     cycleSocTargets = csvread('015cycleSocTargets.csv');
    cycleSocTargets = [0.8,0.3];
%     ccSocTargets = csvread('015ccSocTargets.csv');
    
    heatPad = false;
    
    %% DriveCycleMode
    mode = 'cy';
    startProfileInd = 1; % 6;
    endProfileInd = 1; %length(cycleProfiles);
    
    for i = 1:length(cycleSocTargets)
        initialSOC = cycleSocTargets(i,1);
        targetSOC = cycleSocTargets(i,2);
        for ii = startProfileInd:endProfileInd
            
            % Load prevSOC variable for use in 
            % this script since the variable isn't updated here (only in the functions)
            load(dataLocation + "007BatteryParam.mat");
            prevSOC = batteryParam.soc(cellID);
            
            % Adjusting initial SOC
            if(prevSOC >= initialSOC)
                disp(newline + "Adjusting Initial SOC (Cycle): Discharging to " + num2str(initialSOC * 100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
                out = dischargeTo(initialSOC, adjCurr, cellID);
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
                disp("Done Discharging" + newline);
            else
                disp(newline + "Adjusting Initial SOC (Cycle): Charging to " + num2str(initialSOC*100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
                out = chargeTo(initialSOC, adjCurr, cellID);
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
                disp("Done Charging" + newline);
            end
            
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
            loTemp = round(out.Data(end, startCol));
            hiTemp = round(out.Data(end, startCol) + (out.Data(end, startCol+1)-out.Data(end, startCol))*0.8);
            out = waitTillTemp(randi([loTemp, hiTemp]), cellID); 
            
            resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
            prevSeqTime = prevSeqTime + out.Time(end);
            
            if(ii == 1)
                heatPad = true;
            else
                heatPad = false;
            end
            
            disp(newline + "Running Profile: " + cycleNames(ii) + " From: " + num2str(initialSOC)+ " To: "+ num2str(targetSOC))
            out = runProfile(cycleProfiles(ii), initialSOC, targetSOC, mode, heatPad, cellID);
            resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
            if heatPad == true
               disp(newline + "Heatpad started: " + num2str(prevSeqTime+102)+...
                   "  And Ended: "  + num2str(prevSeqTime+222)) 
            end
            prevSeqTime = prevSeqTime + out.Time(end);
            
            
            disp("Data Stored in Collection." + newline);
        end
    end
    
    %% CCMode
    %     mode = 'cc'; % Comment this out to skip CC data run
    if strcmpi(mode, 'cc')
        for i = 1:length(ccSocTargets)
            initialSOC = ccSocTargets(i,1);
            targetSOC = ccSocTargets(i,2);
            for ii = 1:length(ccProfiles)
                load(dataLocation + "prevSOC.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
                
                % Adjusting initial SOC
                if(prevSOC >= initialSOC)
                    disp(newline + "Adjusting Initial SOC (CC): Discharging to " + num2str(initialSOC100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
                    out = dischargeTo(initialSOC, adjCurr);
                    resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    prevSeqTime = prevSeqTime + out.Time(end);
                else
                    disp(newline + "Adjusting Initial SOC (CC): Charging to " + num2str(initialSOC100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
                    out = chargeTo(initialSOC, adjCurr);
                    resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                    prevSeqTime = prevSeqTime + out.Time(end);
                end
                
                out = waitTillTemp(); % Wait for the Temperatures of the core and surface to equal out
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
                
                if(targetSOC < initialSOC)
                    profileTS = timeseries(-ccProfiles(ii).Data, ccProfiles(ii).Time);
                elseif (targetSOC > initialSOC)
                    profileTS = ccProfiles(ii);
                else
                    warning("Initial and Final SOC values are Equal (" + num2str(targetSOC*100) +  "%)");
                    break;
                end
                
                disp(newline + "Running Profile: " + ccNames(ii) + " From: " + num2str(initialSOC)+ " To: " + num2str(targetSOC))
                out = runProfile(profileTS, initialSOC, targetSOC, mode, heatPad);
                
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
                disp("Data Stored in Collection." + newline);
                %         figs{end+1} = fig;
            end
        end
    end
    
    %% Finishing Touches
    %% Finishing Touches
    saveLocation = ['C:\Users\User\Documents\Projects\03ThermalFaultDetection' ...
        '\01NNData\'];
    
    script_postProcessResCollection;
    
    saveName = cellID + "FaultyData_" + upper(mode) + ...
        num2str(startProfileInd) + "-" + num2str(endProfileInd) +...
        "_"+ datestr(now,'yymmdd')+".mat";
    
    save(saveLocation + saveName , 'resultCollection');
    
    save(dataLocation + "007BatteryParam.mat", 'batteryParam');
    
%     script_resetDevices;
catch ME
    script_resetDevices;
    rethrow(ME);
end