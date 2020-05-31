
load('002CurrProfileCollection');
cycleSocTargets = csvread('015cycleSocTargets.csv');
ccSocTargets = csvread('015ccSocTargets.csv');

cycleFinalSOC = {};
ccFinalSOC = {};

for i = 1:length(cycleSocTargets)
    initialSOC = cycleSocTargets(i,1);
    targetSOC = cycleSocTargets(i,2);
    for ii = 1:length(cycleProfiles)
        cycleFinalSOC{i, ii} = newSOCAfterProfile(initialSOC,cycleProfiles(ii)); %[soc, ahUsed, ahRemain]
    end
end

for i = 1:length(ccSocTargets)
    initialSOC = ccSocTargets(i,1);
    targetSOC = ccSocTargets(i,2);
    for ii = 1:length(ccProfiles)
        ccFinalSOC{i, ii} = newSOCAfterProfile(initialSOC,ccProfiles(ii));
    end
end

saveLocation = ['C:\Users\100520035\Google Drive\School Related\Masters\' ...
    '00-Grad_Research\Projects\01_NNForBattCoreTempEst\01CoreTempEst\' ...
    '03TrainingDataGeneration\01CommonDataForBattery'];

save(saveLocation + "017FinalExperimentSOCsFromProfiles.mat", 'ccFinalSOC', 'cycleFinalSOC')