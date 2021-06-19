if caller == "gui"
    LJ_powerDev_RelayPins = sysMCUArgs.relayPins;
    
    % Pin to activate relay to allow the LJ MCU to measure Voltage. 
    % This is needed so that the MCU can measure a more accurate voltage. 
    % Keep in mind though that the MCU cannot measure series voltage
    % past 5V
    LJ_MeasVoltPin = 7; %#TODO Need to create a field for this in sysMCUArgs
else
    LJ_powerDev_RelayPins = [5, 6]; % Power Device Switching pins
    
    % Pin to activate relay to allow the LJ MCU to measure Voltage. 
    % This is needed so that the MCU can measure a more accurate voltage. 
    % Keep in mind though that the MCU cannot measure series voltage
    % past 5V
    LJ_MeasVoltPin = 7;
end
