function ForceRelaySwitchToELoad()
%FORCERELAYSWITCHTOELOAD This function forces the Power Relays to switch to the ELoad
%   The reason for this function is to force the power relays from staying
%   connected to the PSU since the terminals on the PSU drain the connected 
%   battery

%% Connect to the Lab Jack MCU if not already connected
if ~exist('ljasm','var')
        ljasm = NET.addAssembly('LJUDDotNet');
        ljudObj = LabJack.LabJackUD.LJUD;
        
        % Open the first found LabJack U3.
        [ljerror, ljhandle] = ljudObj.OpenLabJackS('LJ_dtU3', 'LJ_ctUSB', '0', ...
            true, 0);
        
        % Constant values used in the loop.
        LJ_ioGET_AIN = ljudObj.StringToConstant('LJ_ioGET_AIN');
        LJ_ioGET_AIN_DIFF = ljudObj.StringToConstant('LJ_ioGET_AIN_DIFF');
        LJE_NO_MORE_DATA_AVAILABLE = ljudObj.StringToConstant('LJE_NO_MORE_DATA_AVAILABLE');
        
        % Start by using the pin_configuration_reset IOType so that all pin
        % assignments are in the factory default condition.
%         ljudObj.ePutS(ljhandle, 'LJ_ioPIN_CONFIGURATION_RESET', 0, 0, 0);

% This pin (7) is a DIO that was used as an AIN to measure ref voltage for
% current measurement. The pin is now being used to allow/disallow cell voltage measurement
% on the Labjack
%         ljudObj.ePutS(ljhandle, 'LJ_ioPUT_ANALOG_ENABLE_BIT', 7, 1, 0);
       

%% Switch Relays and disconnect
caller = "cmdWindow";
script_defineLJPinNums; % Define pins in use on the LJ MCU
    
if exist('ljasm','var')
    relayState = false;
    if (isempty(ljasm) == 0)
        LJ_MeasVolt = false;
        LJ_MeasVolt_Inverted = true;
        [ljudObj,ljhandle] = MCU_digitalWrite(ljudObj, ljhandle, LJ_MeasVoltPin, LJ_MeasVolt, LJ_MeasVolt_Inverted);

        script_switchPowerDevRelays;
        ljudObj.Close();
        clear('ljudObj', 'ljasm');
    end
end
end
    
    

end

