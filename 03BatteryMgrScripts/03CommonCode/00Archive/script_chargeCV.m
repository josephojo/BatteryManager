% This script requires device initialization, and some variable
% initilization

if battVolt >= highVoltLimit
    highVoltLimitPassed = true;
end

if highVoltLimitPassed == true
    %     chargeVolt = round(battVolt,1);
    error = battVolt - highVoltLimit;
    script_calcPID;
    curr = curr - round(pidVal,1);
    disp("curr: "+ num2str(curr)+ "\tpid: "+ num2str(pidVal));
    if curr > 2.5
        
        disp("Curr is way too high: " + num2str(curr))
        curr = 1;
    end
else
    chargeVolt = round((curr*0.11) + highVoltLimit,1);
end

% If the battery is not currently charging, disconnect all
% and switch the relay. If you are charging, just update the
% current
if ~strcmpi(battState, "charging")
    psu.Disconnect();
    eload.Disconnect();
    
    relayState = false; % Relay is in the Normally Opened Position
    disp ("Battery Charging ...");
    ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4,relayState, 0);
    ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 5,relayState, 0);
    ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 6,relayState, 0);
    wait(0.16); % Wait for the relays to switch
    
    psu.SetVolt(chargeVolt);
    psu.SetCurr(curr);
    psu.Connect();
    
else
    psu.SetVolt(chargeVolt);
    psu.SetCurr(curr);
end
battState = "charging";