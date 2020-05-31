% True is off or in the normally open position
% False is ON or normally open position

%     % Request a single-ended bit change to DIO4 (LED).
%     ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4,relayState, 0, 0);% GND
    
    % Request a single-ended bit change to DIO5 (GND).
    ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', LJRelayPins(1),relayState, 0, 0);% LED
    
    % Request a single-ended bit change to DIO6 (V1+).
    ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', LJRelayPins(2),relayState, 0, 0);% V1+
    
%     % Request a single-ended bit change to DIO7 (V2+).
%     ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', LJRelayPins(3),relayState, 0, 0);% V2+
    %
    % Execute the requests.
    ljudObj.GoOne(ljhandle);