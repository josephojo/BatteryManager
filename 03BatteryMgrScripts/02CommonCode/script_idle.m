% This script requires device initialization, and some variable
% initilization

% If the battery is not currently idle, disconnect all
% and switch the relay. If you are idling, do nothing
if ~strcmpi(battState, "idle")
    eload.Disconnect();
    psu.disconnect();
    
    relayState = false; % true; % Relay is in the Normally Closed Position
    script_switchPowerDevRelays;

end
battState = "idle";