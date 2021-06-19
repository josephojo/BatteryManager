% True is off or in the normally closed position
% False is ON or normally open position
if strcmpi(caller, "gui")
    if strcmpi(sysMCUArgs.devName, "LJMCU")
        % Request a single-ended bit change to DIO5 (GND) and DIO6 (V1+).
        [ljudObj,ljhandle] = MCU_digitalWrite(ljudObj, ljhandle, LJ_powerDev_RelayPins, relayState);

    elseif strcmpi(sysMCUArgs.devName, "ArdMCU")
        err.code = ErrorCode.FEATURE_UNAVAIL;
        err.msg = "Using the arduino for relay switching has not yet been implemented.";
        send(errorQ, err);
    end
    
else
    % Request a single-ended bit change to DIO5 (GND) and DIO6 (V1+).
    [ljudObj,ljhandle] = MCU_digitalWrite(ljudObj, ljhandle, LJ_powerDev_RelayPins, relayState);
      
end