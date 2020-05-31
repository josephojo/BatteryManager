%DegradeCyclesN_Times
%   Cycles a battery with the goal of degrading it

%Change Log
%   REVISION    CHANGE                                          DATE-YYMMDD
%   00          Initial Revision                                190304
%   01          Adopted from P01 - NN4CoreTemp                  190520
%   02          After purchase of new PSU, CV charging          190711
%               is now possible.
clearvars; clc;
try
    
%     cellIDs = ["AB2","AB3"]; % ID in Cell Part Number (e.g BAT11-FEP-AA1). Defined again in initializeVariables  
    cellIDs = ["AA6"];

    % % Initializations
    % script_initializeDevices; % Initialized devices like Eload, PSU etc.
    script_initializeVariables; % Run Script to initialize common variables
    
    resultCollection = {};
    figs = {};
    prevSeqTime = 0; % As code runs, this variable stores the time of the last
    % data collected to be used as the start time for the next data
    % collection.
    
    saveInd = 1; % Number of 

    saveLocation = ['C:\Users\User\Documents\00BattManager\'];
    Filename   = "AA6_dgrdData_03L";
    Purpose    = "Round 6.2 - 50 cycles of Degradation Data after receiving " + ...
                "feedback from review for P03_Rev3. 600 Cycles so far including this. This is completing the 50 cycles stored after misterious program crash.";
    
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

    
    ccSocTargets = [1, 0; 0, 1];
    
    heatPad = false;
    
    numIterations = 100; % Number of times to run the profile
    
    ahCounts = [];
    % Column index where all the AH capacity data are. This is used 
    % before the timestamps are added on the first column therefore 
    % the value is one less than in resultCollection
    AhCapInd = [4]; 
    c_rate = 4;
    % SOC Adjustment current
    if strcmpi (cellConfig, 'parallel')
        adjCurr = sum(batteryParam.ratedCapacity(cellIDs))*c_rate; % X of rated Capacity
    else
        adjCurr = mean(batteryParam.ratedCapacity(cellIDs))*c_rate; % X of rated Capacity
    end
    
    for iter = 1:numIterations
        if iter == 50
            msg = sprintf("Number of Cycles has reached 50.");
            notifyOwnerEmail(msg)
        end
        for i = 1:length(ccSocTargets)
            targetSOC = ccSocTargets(i,2);
            load(dataLocation + "007BatteryParam.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
            prevSOC = mean(batteryParam.soc(cellIDs));
            initialSOC = prevSOC;
            % Adjusting initial SOC
            if(initialSOC > targetSOC)
                disp(newline + "Running Cycle # " + num2str(iter) +...
                        " From: " + num2str(prevSOC * 100)+ "%. To: " +...
                        num2str(targetSOC * 100) + "%. ")
                out = dischargeTo(targetSOC, adjCurr, 'cellIDs', cellIDs);
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
            elseif(initialSOC < targetSOC)
                disp(newline + "Running Cycle # " + num2str(iter) +...
                        " From: " + num2str(prevSOC * 100)+ "%. To: " +...
                        num2str(targetSOC * 100) + "%. ")
                out = chargeTo(targetSOC, adjCurr, 'cellIDs', cellIDs);
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
            end
            
            if abs(initialSOC) <= 0.02 && targetSOC == 1
                load(dataLocation + "007BatteryParam.mat");
                batteryParam.capacity(cellIDs) = out.Data(end, AhCapInd);
                ahCounts(end+1, :) = out.Data(end, AhCapInd);
                save(dataLocation + "007BatteryParam.mat", 'batteryParam');
                disp("Saved Capacity to file: " + num2str(ahCounts(end)) + "Ah or " + ...
                    num2str(ahCounts(end) * 3600));
            end
           
            %{
%             % Wait till a random temperature within a range.
%             % Random number falls between the most recent ambTemp measurement
%             % and the most recent surfTemp *0.8. Similar to randi([20 30]).
%             L = length(out.Data(1, :));
%             for ind = L:-1:1
%                 if out.Data(1,ind) < 15
%                     startCol = ind +1;
%                     break;
%                 end
%             end
%             loTemp = ceil(out.Data(end, startCol));
%             hiTemp = round(out.Data(end, startCol) + (out.Data(end, startCol+1)-out.Data(end, startCol))*0.8);
%             if hiTemp < loTemp
%                 hiTemp = loTemp;
%             end
%             out = waitTillTemp(randi([loTemp, hiTemp]), 'cellIDs', cellIDs);
            %}
            disp(newline + "Running Cycle # " + num2str(iter))
            out = waitTillTime(600, 'cellIDs', cellIDs);

            resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
            prevSeqTime = prevSeqTime + out.Time(end);
            
            disp("Data Stored in Collection." + newline);
            %         figs{end+1} = fig;
        end
        
        if mod(iter, 10) == 0
            disp("Beginning to Save Data Interval: " + num2str(saveInd))
            % Change the variable name before saving
            eval(['resultCollection_' num2str(saveInd) ' = resultCollection;']);
            if saveInd == 1
                save(saveLocation  + "02RawNNData\" +...
                    "BackUpDgrdData", "resultCollection_" + num2str(saveInd))
            else
                save(saveLocation  + "02RawNNData\" +...
                    "BackUpDgrdData", "resultCollection_" + num2str(saveInd)...
                    , '-append');
            end
            disp("Saved Data Interval: " + num2str(saveInd) + newline)
            
            saveInd = saveInd+1;
        end
    end
    %% Finishing Touches
    
    % Don't save battery param here, it updates the
    % good values stored by "runProfile"
        
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
    resultCollection_withAhCap = resultCollection;
    resultCollection(:, [5:8, 11]) = [];
    
    save(saveLocation + "01NNData\" + saveName , 'resultCollection');
    save(saveLocation + "02RawNNData\AhCounts_" + saveName , 'ahCounts');
    
    % Update Experiment Logs File
    T = readtable(saveLocation + "ExperimentLogs.xlsx");
    
    BatteryChem = batteryParam.chemistry(cellIDs(1));
    CapacityLeft = "";
    Features = "";
    
    CellIDs = "";
    for i = 1:numCells 
        if i ~= 1
            CellIDs = CellIDs + ", ";
            CapacityLeft = CapacityLeft + ", ";
        end
        CellIDs = CellIDs + cellIDs(i); 
        CapacityLeft = CapacityLeft + ahCounts(end, i);
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