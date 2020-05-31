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

pause(0.5);

% % Initializations
% script_initializeDevices; % Initialized devices like Eload, PSU etc.
script_initializeVariables; % Run Script to initialize common variables

userReq = '';
curr = 2.5;

location = "C:\Users\100520035\Google Drive\School Related\Masters\00-Grad_Research\Projects\01_NNForBattCoreTempEst\01CoreTempEst\03TrainingDataGeneration\01CommonDataForBattery";

load('002CurrProfileCollection');
resultCollection = {};
figs = {};

cycleSocTargets = csvread('015cycleSocTargets.csv');
ccSocTargets = csvread('015ccSocTargets.csv');


%% DriveCycleMode
mode = 'cycle';
for i = 1:length(cycleSocTargets)
    initialSOC = cycleSocTargets(i,1);
    targetSOC = cycleSocTargets(i,2);
    for ii = 1:length(cycleProfiles) 
        load(dataLocation + "prevSOC.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
        
        % Adjusting initial SOC
        if(prevSOC >= initialSOC)
            disp(newline + "Adjusting Initial SOC (Cycle): Discharging to " + num2str(initialSOC * 100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
            dischargeTo(initialSOC, curr);
        else
            disp(newline + "Adjusting Initial SOC (Cycle): Charging to " + num2str(initialSOC*100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
            chargeTo(initialSOC, curr);
        end
                
        out1 = waitTillTemp(); % Wait for the Temperatures of the core and surface to equal out
        resultCollection{end+1} = [out1.Time, out1.Data];
         
        disp(newline + "Running Profile: " + cycleNames(ii) + " From: " + num2str(initialSOC)+ " To: "+ num2str(targetSOC))
        out2 = runProfile(cycleProfiles(ii), initialSOC, targetSOC, mode);
        
        resultCollection{end+1} = [out2.Time, out2.Data];
        disp("Data Stored in Collection.");
%         figs{end+1} = fig;
    end    
    
%     if strcmpi(userReq ,'pause')
%         
%     end
end

%% CCMode
mode = 'cc';
for i = 1:length(ccSocTargets)
    initialSOC = ccSocTargets(i,1);
    targetSOC = ccSocTargets(i,2);
    for ii = 1:length(ccProfiles)
        load(dataLocation + "prevSOC.mat"); % Load prevSOC variable for use in this script since the variable isn't updated here (only in the functions)
        
        % Adjusting initial SOC
        if(prevSOC >= initialSOC)
            disp(newline + "Adjusting Initial SOC (CC): Discharging to " + num2str(initialSOC100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
            dischargeTo(initialSOC, curr);
        else
            disp(newline + "Adjusting Initial SOC (CC): Charging to " + num2str(initialSOC100) + "%. Current SOC = " + num2str(prevSOC*100) + "%")
            chargeTo(initialSOC, curr);
        end
                
        out1 = waitTillTemp(); % Wait for the Temperatures of the core and surface to equal out
        resultCollection{end+1} = [out1.Time, out1.Data];
        
        if(targetSOC < initialSOC)
            profileTS = timeseries(-ccProfiles(ii).Data, ccProfiles(ii).Time);
        elseif (targetSOC > initialSOC)
            profileTS = ccProfiles(ii);
        else
            warning("Initial and Final SOC values are Equal (" + num2str(targetSOC*100) +  "%)");
            break;
        end
        
        disp(newline + "Running Profile: " + ccNames(ii) + " From: " + num2str(initialSOC)+ " To: " + num2str(targetSOC))
        out2 = runProfile(profileTS, initialSOC, targetSOC, mode);
        
        resultCollection{end+1} = [out2.Time, out2.Data]; 
        disp("Data Stored in Collection.");
%         figs{end+1} = fig;
    end   
end

saveLocation = ['C:\Users\100520035\Google Drive\School Related\Masters'...
    '\00-Grad_Research\Projects\01_NNForBattCoreTempEst\01CoreTempEst' ...
    '\01TrainingData\'];

save(saveLocation + "003TrainingDataFromExp.mat", 'resultCollection');

script_resetDevices;
catch ME
    script_resetDevices;
    rethrow(ME);
end