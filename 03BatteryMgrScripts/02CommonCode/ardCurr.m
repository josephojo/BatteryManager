
function [ardCurr] = ardCurr(channels)
% 1.5% error at T=25C

VCC = 5; %Supply voltage
QOV = 0.5*VCC;  %Quescient output voltage
sens = 0.100; %From ACS712ELC-20A Datasheet
curr = [];

if ~ismember(1, channels)
    volt = readVoltage(ard, 'A0') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ~ismember(2, channels)
    volt = readVoltage(ard, 'A1') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ~ismember(3, channels)
    volt = readVoltage(ard, 'A2') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ~ismember(4, channels)
    volt = readVoltage(ard, 'A3') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ~ismember(5, channels)
    volt = readVoltage(ard, 'A4') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ~ismember(6, channels)
    volt = readVoltage(ard, 'A5') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ~ismember(7, channels)
    volt = readVoltage(ard, 'A6') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ~ismember(8, channels)
    volt = readVoltage(ard, 'A7') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
    
ardCurr = curr;

end

