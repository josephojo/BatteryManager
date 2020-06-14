
if strcmpi(caller, "gui")
%% Caller == GUI
    
    %ARRAY ELOAD
    %##########################################################################
    if exist('eloadArgs', 'var')
        if ~isempty(eloadArgs) && strcmpi(eloadArgs.type, "serial")
            if ~exist('eload','var') ...
                    || (isvalid(eload) && strcmpi(eload.serialStatus(), "Disconnected"))
                if strcmpi(eloadArgs.devName, "array")
                    eload = Array_ELoad(eloadArgs.COMPort, "baudRate", eloadArgs.baudRate);
                    eload.stopBits = eloadArgs.stopBits;
                    eload.byteOrder = eloadArgs.byteOrder;
                    eload.terminator = eloadArgs.terminator;
                    eload.timeout = eloadArgs.timeout;
                    eload.SetSystCtrl('remote');
                    eload.Disconnect();
                end
            end
        else
            err.code = ErrorCode.BAD_DEV_ARG;
            err.msg = "No connection type selected for the E-Load.";
            send(errorQ, err);
        end
    end
    
    %--------------------------------------------------------------------------
    %APM POWER SUPPLY
    %##########################################################################
    if exist('psuArgs', 'var')
        if ~isempty(psuArgs) && strcmpi(psuArgs.type, "serial")
            if ~exist('psu','var') ...
                    || (isvalid(eload) && strcmpi(psu.serialStatus(), "Disconnected"))
                if strcmpi(psuArgs.devName, "array")
                    psu = APM_PSU(psuArgs.COMPort, "baudRate", psuArgs.baudRate);
                    psu.stopBits    = psuArgs.stopBits;
                    psu.byteOrder   = psuArgs.byteOrder;
                    psu.terminator  = psuArgs.terminator;
                    psu.timeout     = psuArgs.timeout;
                    psu.setSystCtrl('remote');
                    psu.disconnect();
                end
            end
        else
            err.code = ErrorCode.BAD_DEV_ARG;
            err.msg = "No connection type selected for the PSU.";
            send(errorQ, err);
        end
    end
    %--------------------------------------------------------------------------
    
    %THERMOCOUPLE MODULE
    %##########################################################################
    if exist('tempModArgs', 'var')
        if ~isempty(tempModArgs)
            if tempModArgs.type == "modbus"
                thermo = modbus('serialrtu',tempModArgs.COMPort,...
                    'Timeout',thermoArgs.timeout); % Initializes a Modbus
                %protocol object using serial RTU interface connecting to COM6 and a Time
                %out of 10s.
                thermo.BaudRate = tempModArgs.baudRate;
                
            elseif tempModArgs.type == "serial"
                thermo = serialport(tempModArgs.COMPort, tempModArgs.baudRate);
                thermo.StopBits = tempModArgs.stopBits;
                thermo.ByteOrder = tempModArgs.byteOrder;
                thermo.Terminator = tempModArgs.terminator;
                thermo.Timeout = tempModArgs.timeout;
            else
                err.code = ErrorCode.BAD_DEV_ARG;
                err.msg = "No connection type selected for the Temp. Module.";
                send(errorQ, err);
            end
        end
    end
    %--------------------------------------------------------------------------
    
    % LABJACK
    %##########################################################################
    LJRelayPins = sysMCUArgs.relayPins;
    
    if strcmpi(sysMCUArgs.devName, "LJMCU")
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
            ljudObj.ePutS(ljhandle, 'LJ_ioPIN_CONFIGURATION_RESET', 0, 0, 0);
            
            % Enable measurement pins as analog pins
            ljudObj.ePutS(ljhandle, 'LJ_ioPUT_ANALOG_ENABLE_BIT', sysMCUArgs.currMeasPins(1), 1, 0);
            ljudObj.ePutS(ljhandle, 'LJ_ioPUT_ANALOG_ENABLE_BIT', sysMCUArgs.currMeasPins(2), 1, 0);
            ljudObj.ePutS(ljhandle, 'LJ_ioPUT_ANALOG_ENABLE_BIT', sysMCUArgs.voltMeasPins(1), 1, 0);
            ljudObj.ePutS(ljhandle, 'LJ_ioPUT_ANALOG_ENABLE_BIT', sysMCUArgs.voltMeasPins(2), 1, 0);
        end
    elseif strcmpi(sysMCUArgs.devName, "ArdMCU")
            err.code = ErrorCode.FEATURE_UNAVAIL;
            err.msg = "Using the arduino relay for switching and measurements has not yet been implemented.";
            send(errorQ, err);
        
        % Arduino
        %##########################################################################
%         ardPort = 'COM8';
%         ardSerial = instrfind('Port',ardPort, 'Status', 'open');
%         if isempty(ardSerial)
%             ard = serial(ardPort);
%             ard.BaudRate = 115200;
%             ard.DataBits = 8;
%             ard.Parity = 'none';
%             ard.StopBits = 1;
%             ard.Terminator = 'LF';
%             fopen(ard);
%         elseif ~exist('ard','var')
%             ard = ardSerial;
%         end
%         wait(2);
        % -------------------------------------------------------------------------
    
    end
    
elseif strcmpi(caller, "cmdWindow")
    %% Command Window
    % When called by the command window, the connection settings will need to be determined on its own
    
    % Arduino
    %##########################################################################
    % ardPort = 'COM8';
    % ardSerial = instrfind('Port',ardPort, 'Status', 'open');
    % if isempty(ardSerial)
    %     ard = serial(ardPort);
    %     ard.BaudRate = 115200;
    %     ard.DataBits = 8;
    %     ard.Parity = 'none';
    %     ard.StopBits = 1;
    %     ard.Terminator = 'LF';
    %     fopen(ard);
    % elseif ~exist('ard','var')
    %     ard = ardSerial;
    % end
    % wait(2);
    % -------------------------------------------------------------------------
    
    %ARRAY ELOAD
    %##########################################################################
    eloadPort = 'COM2';
    
    if ~exist('eload','var') ...
            || (isvalid(eload) && strcmpi(eload.serialStatus(), "Disconnected"))
        eload = Array_ELoad(eloadPort);
        eload.SetSystCtrl('remote');
        eload.Disconnect();
    end
    %--------------------------------------------------------------------------
    
    %APM POWER SUPPLY
    %##########################################################################
    psuPort = 'COM4';
    if ~exist('psu','var') ...
            || (isvalid(psu) && strcmpi(psu.serialStatus(), "Disconnected"))
        psu = APM_PSU(psuPort);
        psu.setSystCtrl('remote');
        psu.disconnect();
    end
    %--------------------------------------------------------------------------
    
    %THERMOCOUPLE MODULE
    %##########################################################################
    thermoPort = 'COM5';
    if ~exist('thermo','var')
        thermo = modbus('serialrtu',thermoPort,'Timeout',10); % Initializes a Modbus
        %protocol object using serial RTU interface connecting to COM6 and a Time
        %out of 10s.
        thermo.BaudRate = 38400;
    end
    %--------------------------------------------------------------------------
    
    % LABJACK
    %##########################################################################
    LJRelayPins = [5, 6];
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
        ljudObj.ePutS(ljhandle, 'LJ_ioPIN_CONFIGURATION_RESET', 0, 0, 0);
        ljudObj.ePutS(ljhandle, 'LJ_ioPUT_ANALOG_ENABLE_BIT', 7, 1, 0);
        
    end
    
    % -------------------------------------------------------------------------
    
    
    % % Get the 0A voltage from the current sensor connected to the LabJack.
    % % This section will give errors if script_initializeVariables isn't run
    % % before this script
    % cSigP = 0;
    % cSigN = 0;
    % n = 10;
    % script_initializeVariables;
    % for i = 1:n
    %     script_avgLJMeas; % Gets the zero values of the sensor. % If Error occurs here, it's because script_initializeVariables wasn't before script_initializeDevices
    %     cSigP = (ain0 / adcAvgCount) + cSigP;
    %     cSigN = (ain1 / adcAvgCount) + cSigN;
    % end
    % cSigMid = (cSigP/n) - (cSigN/n);
    % script_initializeVariables;
    
end