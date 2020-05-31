% This script requires device initialization, and some variable
% initilization


% If the battery is not currently charging, disconnect all
% and switch the relay. If you are charging, just update the
% current
if ~strcmpi(battState, "charging")
    psu.disconnect();
    eload.Disconnect();
    
    relayState = true; % false; % Relay is in the Normally Opened Position
    script_switchRelays;
%     disp ("Battery Charging ...");

    psu.setVolt(round(chargeVolt,4));
    psu.setCurr(round(curr,4));
    psu.connect();
        
    wait(0.10)
%     relayState = true; % false; % Relay is in the Normally Opened Position
%     disp ("Battery Charging ...");
%     script_switchRelays;
    
else
    psu.setCurr(round(curr,4));
end
battState = "charging";