clc;
try
    cellID = "AA6"; % ID in Cell Part Number (e.g BAT11-FEP-AA1). Defined again in initializeVariables
    
%     disp("Validating SOC...");
%     validateSOC;
    
    
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
    
    heatPad = false;
    
    %% DriveCycleMode
    mode = 'cy';
    startProfileInd = 1;
    endProfileInd = 1;
    
    initialSOC = cycleSocTargets(1,1);
    targetSOC = cycleSocTargets(1,2);
    for ii = startProfileInd:endProfileInd
        
        % Load prevSOC variable for use in
        % this script since the variable isn't updated here (only in the functions)
        load(dataLocation + "007BatteryParam.mat");
        prevSOC = batteryParam.soc(cellID);
        
        % Adjusting initial SOC
        if(prevSOC >= initialSOC)
            disp(newline + "Adjusting Initial SOC (Cycle): Discharging to " + num2str(initialSOC * 100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
            out = dischargeTo(initialSOC, adjCurr, cellID);
            battTS_DChg = out;
            %                 resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
            %                 prevSeqTime = prevSeqTime + out.Time(end);
            disp("Done Discharging" + newline);
        else
            disp(newline + "Adjusting Initial SOC (Cycle): Charging to " + num2str(initialSOC*100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
            out = chargeTo(initialSOC, adjCurr, cellID);
            battTS_Chg = out;
            %                 resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
            %                 prevSeqTime = prevSeqTime + out.Time(end);
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
        battTS_Wait = waitTillTemp(randi([loTemp, hiTemp]), cellID);
        
        %             resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
        %             prevSeqTime = prevSeqTime + out.Time(end);
        
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
    
    %% Finishing Touches
    
    % Don't save battery param here, it updates the 
    % good values stored by "runProfile"
    
    saveLocation = ['C:\Users\User\Documents\Projects' ...
        '\03ThermalFaultDetection\'];
    
    saveName = cellID + "FaultedData_" + upper(mode) + ...
        num2str(startProfileInd) + "-" + num2str(endProfileInd) +...
        "_"+ datestr(now,'yymmdd')+".mat";
    
    save(saveLocation + "02RawNNData\" + saveName , 'resultCollection');

    script_postProcessResCollection;
    
    
    % Remove the AhCap column
    resultCollection_withAhCap = resultCollection;
    resultCollection(:, startCol - 1) = [];
    
    save(saveLocation + "01NNData\" + saveName , 'resultCollection');
    
    %     script_resetDevices;
catch ME
    script_resetDevices;
    rethrow(ME);
end