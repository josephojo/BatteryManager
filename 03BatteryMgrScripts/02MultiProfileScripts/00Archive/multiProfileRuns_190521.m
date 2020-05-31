%multiProfileRuns
%   Runs a single power profile based on one driving cycle. There is an
%   option to run this profile multiple times
%
%Change Log
%   REVISION    CHANGE                                          DATE-YYMMDD
%   00          Initial Revision                                190304

try
    % disp("Validating SOC...");
    % validateSOC;
    
    % totalChargeCounter;
    
    %     pause(0.5);
    
    % % Initializations
    % script_initializeDevices; % Initialized devices like Eload, PSU etc.
    script_initializeVariables; % Run Script to initialize common variables
    
    % SOC Adjustment current
    adjCurr = 2.5;
        
    load('002CurrProfileCollection');
    resultCollection = {};
    figs = {};
    prevSeqTime = 0; % As code runs, this variable stores the time of the last
    % data collected to be used as the start time for the next data
    % collection.
    
    %     cycleSocTargets = csvread('015cycleSocTargets.csv');
    cycleSocTargets = [0.8,0.3];
    ccSocTargets = csvread('015ccSocTargets.csv');
    
    
    %% DriveCycleMode
    mode = 'cycle';
    for i = 1:1 %length(cycleSocTargets)
        initialSOC = cycleSocTargets(i,1);
        targetSOC = cycleSocTargets(i,2);
        for ii = 6:length(cycleProfiles)
            load(dataLocation + "prevSOC.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
            
            % Adjusting initial SOC
            if(prevSOC >= initialSOC)
                disp(newline + "Adjusting Initial SOC (Cycle): Discharging to " + num2str(initialSOC * 100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
                out = dischargeTo(initialSOC, adjCurr);
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
            else
                disp(newline + "Adjusting Initial SOC (Cycle): Charging to " + num2str(initialSOC*100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
                out = chargeTo(initialSOC, adjCurr);
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
            end
            
            out = waitTillTemp(); % Wait for the Temperatures of the core and surface to equal out
            resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
            prevSeqTime = prevSeqTime + out.Time(end);
            
            disp(newline + "Running Profile: " + cycleNames(ii) + " From: " + num2str(initialSOC)+ " To: "+ num2str(targetSOC))
            out = runProfile(cycleProfiles(ii), initialSOC, targetSOC, mode);
            resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
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
                out = runProfile(profileTS, initialSOC, targetSOC, mode);
                
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
                disp("Data Stored in Collection." + newline);
                %         figs{end+1} = fig;
            end
        end
    end
    
    %% Finishing Touches
    saveLocation = ['C:\Users\User\Documents\Projects\01CoreTempEst' ...
        '\01TrainingData\'];

    save(saveLocation + "003NNTrainingData_Cycle.mat", 'resultCollection');
%     save(saveLocation + "003TrainingDataFromExp.mat", 'resultCollection');
    
    script_resetDevices;
catch ME
    script_resetDevices;
    rethrow(ME);
end