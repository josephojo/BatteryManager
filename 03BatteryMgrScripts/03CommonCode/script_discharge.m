% This script requires device initialization, and some variable
% initilization

% If the battery is not currently discharging, disconnect all
% and switch the relay. If you are discharging, just update the
% current
if ~strcmpi(battState, "discharging")
    psu.disconnect();
    eload.Disconnect();
        
    eload.SetLev_CC(abs(round(curr,3))); %curr is negative because
    eload.Connect();

    relayState = false; %true; % Place Relay is in the Normally Closed Position
    script_switchRelays;

else
    eload.SetLev_CC(abs(round(curr,3)));
end
battState = "discharging";
