% This script requires device initialization, and some variable
% initilization


% If the battery is not currently charging, disconnect all
% and switch the relay. If you are charging, just update the
% current
if ~strcmpi(battState, "charging")
    psu.disconnect();
    eload.Disconnect();
    

    psu.setVolt(round(chargeVolt,3));
    psu.setCurr(round(curr,3));
    psu.connect();
        
%     wait(0.10)
    relayState = true; % Place Relay is in the Normally Opened Position
    script_switchPowerDevRelays;
    
else
    psu.setCurr(round(curr,4));
end
battState = "charging";