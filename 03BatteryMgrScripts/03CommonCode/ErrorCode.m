classdef ErrorCode
    %ErrorCode This is the Error Enumaration class containing possible
    %error in the project
    %   
    %
    %   There is NO NEED to define an object for this class file yourself. 
    %   It is used in DC2100A.m
    %
    % ####################       Change Log       #########################
    %----------------------------------------------------------------------
    % REVISION	DATE-YYMMDD  |  CHANGE                                      
    %----------------------------------------------------------------------
    % 00        200501          Initial Release
    %
    
    enumeration
        % General Errors
        NO_ERROR 
        WARNING
        UNKNOWN_ERROR 
        EXCEPTION
        EMERGENCY_STOP
        FEATURE_UNAVAIL     % Feature requested has not yet been implemented
        OUT_OF_BOUNDS % The value chosen/being used is outside the allowable range
        
        % COMM ErrorCodes
        COMMPORT_NOTFOUND
        COMM_TIMEOUT
        COMMTEST_DATA_MISMATCH
        COMM_DC2100A_NOT_DETECTED
        
        % Parsing Errors
        USB_DELAYED
        USB_DROPPED
        USB_PARSER
        OVUV % Over-voltage and Under-Voltage
        OV % Over Voltage
        UV % Under Voltage
        OC % Over Current Error
        UC % Under Current
        USB_PARSER_NOTDONE % The full response has not been received, exit and wait for it without deleting anything from the buffer
        USB_PARSER_UNSUCCESSFUL         % The USB Parser was not able to finish either due to exception or an unmet condition
        USB_PARSER_UNKNOWN_COMMAND      % Unknown command received from the serial interface
        USB_PARSER_UNKNOWN_EEPROM_ITEM % Item does not include capacity or current calibration data
        USB_PARSER_UNKNOWN_BOARD
        USB_PARSER_UNKNOWN_DFLT_STRING
        USB_PARSER_UNKNOWN_IDSTRING
        
        % Special DC2100A Errors
        LTC6804_FAILED_CFG_WRITE    % Errata in early LTC6804 silicon was detected, where configuration registers do not write successfully.
        LTC6804_CRC                 % An LTC6804 response had an incorrect CRC.
        LTC3300_CRC                 % An LTC3300 response had an incorrect CRC.
        LTC6804_ADC_CLEAR           % An LTC6804 ADC conversion returned clear, indicating that the command to start the conversion was not received.
        LTC3300_FAILED_CMD_WRITE    % An LTC3300 Balancer Command Read did not match the last value written.
        
        % Power Device ErrorCodes
        BAD_DEV_ARG                 % The arguments meant to initlize the device objects are either invalid or nonexistent
        BAD_SETTING                 % One of the test setting arguments are invalid.
        
    end
end

