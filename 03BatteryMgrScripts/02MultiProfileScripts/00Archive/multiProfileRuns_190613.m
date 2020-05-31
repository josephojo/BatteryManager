%multiProfileRuns
%   Runs a single power profile based on one driving cycle. There is an
%   option to run this profile multiple times
%
%Change Log
%   REVISION    CHANGE                                          DATE-YYMMDD
%   00          Initial Revision                                190304
%   01          Adopted from P01 - NN4CoreTemp                  190520

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
    
    % ONLY USE THIS IF SOC VALIDATION
    % was done somewhere else (e.g Cycler)
%     prevSOC = 0.995;
%     save(dataLocation + "prevSOC.mat", 'prevSOC');
        
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
    startCycleProfile = 1; % 6;
    endCycleProfile = 10; % length(cycleProfiles);
    for i = 1:1 %length(cycleSocTargets)
        initialSOC = cycleSocTargets(i,1);
        targetSOC = cycleSocTargets(i,2);
        for ii = startCycleProfile:endCycleProfile
            load(dataLocation + "prevSOC.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
            
            % Adjusting initial SOC
            if(prevSOC >= initialSOC)
                disp(newline + "Adjusting Initial SOC (Cycle): Discharging to " + num2str(initialSOC * 100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
                out = dischargeTo(initialSOC, adjCurr);
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
                disp("Done Discharging");
            else
                disp(newline + "Adjusting Initial SOC (Cycle): Charging to " + num2str(initialSOC*100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
                out = chargeTo(initialSOC, adjCurr);
                resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
                prevSeqTime = prevSeqTime + out.Time(end);
            end
            
            out = waitTillTemp(); % Wait for the Temperatures of the core and surface to equal out
            resultCollection{end+1} = [out.Time + prevSeqTime, out.Data];
            prevSeqTime = prevSeqTime + out.Time(end);
            
            if(ii < 3)
                heatPad = false;
            else
                heatPad = true;
            end
            
            disp(newline + "Running Profile: " + cycleNames(ii) + " From: " + num2str(initialSOC)+ " To: "+ num2str(targetSOC))
            out = runProfile(cycleProfiles(ii), initialSOC, targetSOC, mode, heatPad);
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
    saveLocation = ['C:\Users\User\Documents\Projects\03ThermalFaultDetection' ...
        '\02TestingData\'];

%     save(saveLocation + "003FaultyTempData_Cycle1.mat", 'resultCollection');
    save(saveLocation + "003TempData_Cycle1.mat", 'resultCollection');
    
%     script_resetDevices;
catch ME
    script_resetDevices;
    rethrow(ME);
end