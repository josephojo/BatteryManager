
% validateSOC; %Run Script to validate SOC value to have a point to start SOC estimation
% 
% wait(0.5); % Wait 0.5 Seconds before moving on with the next script

dischargeToEmpty; % Discharge to 0% SOC @ 5A. 0% in this case is set by us, it is related to the lowVoltLimit

% clearvars;
wait(0.5); % Wait 0.5 Seconds before moving on with the next script
 
% chargeTo(1.0, 0.2); % Charge to 100% SOC @ 0.2A
% 
% load('005ChargeTo100%');

chargeToFull;

% load('005ChargeToFull');

ocv_OCV = battTS.Data(:,5);
ocv_SOC = battTS.Data(:,7);

save(dataLocation + "008VOC_vs_SOC.mat", 'ocv_OCV', 'ocv_SOC');
