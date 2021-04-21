
function [measureCurr_Ard] = measureCurr_Ard(ard, varargin)
% measureCurr_Ard will measure the current from current sensors connected to an arduino platform
% 1.5% error at T=25C
%
%   Inputs: 
%       ard                 : Passing the arduino object to the function
%       varargin   
%			channels       	= [1 2 3 4],	: Specifies which arduino pin to read from. Channel 1 represents pin A0, 
%                                             channel 2 is for pin A1, etc...
%           VCC             = 5,            : Supplied voltage to the arduino board
%           sens            = 0.1           : Sensor sensitivity mV/A
%   Outputs:
%       measuredCurr        : Returns the measured current from all specified arduino pins

%% Default parameter values
param = struct(...
    'channels',         [0 1 2 3],  ... % Reads from pins A0, A1, A2, and A3
    'VCC',              5,          ... % Valid for all ACS712 current sensors
    'sens',             0.1);           % Valid for ACS712-20A sensors

% --------------------------

channels = param.channels;
VCC = param.VCC;
sens = param.sens;

QOV = 0.5*VCC;  % Quescient output voltage
curr = [];

%% Start routine

if ismember(0, channels)
    volt = readVoltage(ard, 'A0') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ismember(1, channels)
    volt = readVoltage(ard, 'A1') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ismember(2, channels)
    volt = readVoltage(ard, 'A2') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ismember(3, channels)
    volt = readVoltage(ard, 'A3') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ismember(4, channels)
    volt = readVoltage(ard, 'A4') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ismember(5, channels)
    volt = readVoltage(ard, 'A5') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ismember(6, channels)
    volt = readVoltage(ard, 'A6') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
if ismember(7, channels)
    volt = readVoltage(ard, 'A7') - QOV + 0.000; %Change 0.000 depending on error from sensors.
    % It should zero out the voltage when current is 0
    curr(end+1) = abs(volt/sens);
end
    
measureCurr_Ard = curr;

end

