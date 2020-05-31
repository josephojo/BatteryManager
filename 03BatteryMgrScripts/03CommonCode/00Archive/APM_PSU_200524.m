classdef APM_PSU
    %APM_PSU class handles control and data recording for the
    %APM SPS80VDC1000W Power Supply.
    %   This class uses the serial (USB) protocol to send commands and
    %   receive data from the PSU.
    %
    %   The following Subsystems have not been implemented:
    %       - CC Protection functions
    %       - List Subsystem and Functions
    %       - Status Subsystem and Functions
    %
    %
    %Change Log
    %   CHANGE                                      REVISION	DATE-YYMMDD
    %   Initial Revision                            00          190626
        
    properties
        SerialObj
        COMPort % The COM Port of the device e.g 'COM3'
        COMBaudRate % The Baudrate of the device COM Port e.g 19200
        COMDataBits % The Databits of the device COM Port e.g 8
        COMParity % The Parity of the device COM Port e.g 'none'
        COMStopBits % The Stopbits of the device COM Port e.g 1
        COMTerminator % The Terminator of the Port e.g 'LF'(Works better)
%         PortConnected % Property for verifying whether or not the machine is connected
    end %End of PROPERTIES (Public)
    
    methods (Access = private)
        
        function set(obj, header1, header2, cmnd, value)
            %set Makes most write commands to the ELoad
            %   Writes the command - [header:]comnd<value>[LF] - to the
            %   serial port. Where "value" is either decimal or string.
            %   Returns reply: "Success" or "Failed - {Error}" from device.
            
            
            % If the value argument is not empty and is of type double
            if (isempty(value) == 0 && isa(value, 'double'))
                value = num2str(value);
                
                % If header1 and header2 are empty arguments
                if isempty(header1)&& isempty(header2)
                    command = strcat(cmnd," ", value);
                elseif isempty(header1)&& isempty(header2)== 0
                    command = strcat(header2, ':', cmnd," ",value);
                elseif isempty(header1) == 0 && isempty(header2)
                    command = strcat(header1, ':', cmnd," ",value);
                else
                    command = strcat(header1,':',header2,':',cmnd," ",value);
                end
                
                % If the value argument is not empty and is of type char
            elseif (isempty(value) == 0 && (isa(value, 'char') || isa(value, 'string')))
                % If header1 and header2 are empty arguments
                if isempty(header1)&& isempty(header2)
                    command = strcat(cmnd,"? ", value);
                elseif isempty(header1)&& isempty(header2)== 0
                    command = strcat(header2, ':', cmnd,"? ",value);
                elseif isempty(header1) == 0 && isempty(header2)
                    command = strcat(header1, ':', cmnd,"? ",value);
                else
                    command = strcat(header1,':',header2,':',cmnd,"? ",value);
                end
                
            else
                % If header1 and header2 are empty arguments
                if isempty(header1)&& isempty(header2)
                    command = strcat(cmnd);
                elseif isempty(header1)&& isempty(header2)== 0
                    command = strcat(header2, ':', cmnd);
                elseif isempty(header1) == 0 && isempty(header2)
                    command = strcat(header1, ':', cmnd);
                else
                    command = strcat(header1,':',header2,':',cmnd);
                end
                
            end
            
            command = upper(command);
            fprintf(obj.SerialObj, command);
            wait(0.01)
            
            %             % Check for Errors
            %             [~, alarm] = getAlarmCode(obj);
            %             reply = alarm;
            
        end %End of set
        
        %-----------------------------------------------------------------
        
        function data = get(obj, header1, header2, comnd, value)
            %get Makes most read commands from  the ELoad
            %   Writes the command - header:comnd?[LF] - and receives the
            %   reponse from the serialport including the reply 'Success'
            %   or Failed - {Error}.
            
            if (isempty(value) == 0 && (isa(value, 'char') || isa(value, 'string')))
                % If both headers are empty
                if isempty(header1) && isempty(header2)
                    command = strcat(comnd,"?", value);
                elseif isempty(header1)== 0 && isempty(header2)
                    command = strcat(header1, ':', comnd,"?", value);
                elseif isempty(header1) && isempty(header2)== 0
                    command = strcat(header2, ':', comnd,"?", value);
                else
                    command = strcat(header1,':',header2,':',comnd,"?",value);
                end
            else
                % If both headers are empty
                if isempty(header1) && isempty(header2)
                    command = strcat(comnd,"?");
                elseif isempty(header1)== 0 && isempty(header2)
                    command = strcat(header1, ':', comnd,"?");
                elseif isempty(header1) && isempty(header2)== 0
                    command = strcat(header2, ':', comnd,"?");
                else
                    command = strcat(header1,':',header2,':',comnd,"?");
                end
            end
            
            command = upper(command);
            fprintf(obj.SerialObj, command);
            wait(0.01)
            data = fgetl(obj.SerialObj);
            
            
            %             % Check for Errors
            %             [~, alarm] = getAlarmCode(obj);
            %             reply = alarm;
            
        end %End of get ###################################
        
        
    end %End of METHODS (Private)
    
    methods
        
        function obj = APM_PSU(varargin)
            %APM_PSU Initiates an instance of APM_PSU that takes
            %the COM port or serial object as an argument.
            %   This Constructor creates a generic serial object with
            %   Baudrate = 19200, DataBits = 8, Parity = 'none',
            %   StopBits = 1, and Terminator = 'LF'. These settings are
            %   adjustable for and on the APM SPS80VDC1000W PSU.
            %   port = 'COM#' (String)
            
            for i = 1:length(varargin)
                var = class(varargin{i});
                % If the argument is a serial port
                if (strcmpi(var, 'string') || strcmpi(var, 'char'))...
                        && contains(varargin{i}, 'COM','IgnoreCase',true)
                    port = string(varargin{i});
                    obj.COMPort = upper(port);
                    s = serial(port); %Creates a serial port object
                    obj.SerialObj = s;
                    obj.COMBaudRate = 19200; s.BaudRate = obj.COMBaudRate;
                    obj.COMDataBits = 8; s.DataBits = obj.COMDataBits;
                    obj.COMParity = 'none'; s.Parity = obj.COMParity;
                    obj.COMStopBits = 1; s.StopBits = obj.COMStopBits;
                    obj.COMTerminator = 'LF'; s.Terminator = obj.COMTerminator;
                    
                    % Open Serial Port
                    if obj.SerialObj.Status == "closed"
                        fopen(obj.SerialObj);
                    end
                    break;
                
                
                % If the argument is a serial object
                elseif (strcmpi(var, 'string') || strcmpi(var, 'char'))...
                        && max(ismember(upper(varargin{i}),upper("serialobj")))
                    s = find(ismember(upper(varargin{i}),upper("serialobj")), 1, 'first');
                    obj.SerialObj = varargin{s+1};
                    break;
                end
                
                if strcmpi(var,'serial')
                    obj.SerialObj = varargin{i};
                    break;
                end
            end
        end
        
        
        function reply = disconnectSerial(obj)
           %disconnectSerial Closes tha serial port.
            fclose(obj.SerialObj);
            serialStatus = obj.SerialObj.Status;
            
            if strcmpi(serialStatus,'closed')
               reply = "SerialPort Closed Successfully";
%                obj.PortConnected = false;
            else
                reply = "SerialPort Failed to Close";
            end
        end
        
        function reply = setSystCtrl(obj, ctrl)
            %setSystCtrl Sets the system control mode to either remote or
            %local to either allow remote programming or local (machine
            %interface) control
            %   'ctrl' is a string value of either 'remote' or 'local'.
            
            if ctrl == "remote"
                cmnd = 'REM';
            elseif ctrl == "local"
                cmnd = 'LOC';
            else
                error('Argument value for "ctrl" is not valid');
            end
            
            reply = set(obj,[], 'SYST', cmnd,[]);
            
        end
        
        function ID = WhoAmI(obj)
            fprintf(obj.SerialObj, '*IDN?');
            ID = fgetl(obj.SerialObj);
        end
        
        function [alarmState, alarm] = getAlarmCode(obj)
            %getAlarmCode Checks for Triggered Alarms in PSU
            
            % Check for Alarms
            fprintf(obj.SerialObj, 'ASWRS?');
            dataStr = fgetl(obj.SerialObj);
            alarmState = true;
            
            switch dataStr
                case '1'
                    alarm = "OVP";
                case '2'
                    alarm = "OCP";
                case '3'
                    alarm = "OPP";
                case '4'
                    alarm = "CV2CC";
                case '5'
                    alarm = "CC2CV";
                case '6'
                    alarm = "SLAVE OUT LINE";
                case '7'
                    alarm = "CURRCOUNT_NOTREADY";
                case '8'
                    alarm = "CURRCOUNT_FAILTEST";
                case '9'
                    alarm = "OVP";
                case 'A'
                    alarm = "SC";
                case 'B'
                    alarm = "FAN_FAULT";
                case 'C'
                    alarm = "OVT";
                case 'D'
                    alarm = "NTC_FAIL";
                case 'E'
                    alarm = "PRIMARY_FAIL";
                otherwise
                    alarmState = false;
                    alarm = "NO_ALARM";
            end
        end
        
        function reply = ClearAlarmCode(obj)
            fprintf(obj.SerialObj, 'ASWRC 0');
            wait(0.003);
            [alarmState, alarm] = getAlarmCode(obj);
            if alarmState == false
                reply = "Alarm Cleared";
            else
                reply = "Alarm Remains: " + alarm;
            end
        end
        
        function reply = setVolt(obj,varargin)
            %setVolt Sets the voltage level
            %   Writes the command - VOLT{<voltage>}[CR] - to the serial
            %   port. set value is precise to 4 decimal places.
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 60.0
                    setVal = varargin{1};
                    set(obj, [], [], 'VOLT', varargin{1});
                else
                    warning('Value can not be greater than 80.0V. Setting MAX curr (80 V) instead.')
                end
                    
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 80.0;
                    set(obj, [], [], 'VOLT', setVal);
                elseif strcmpi(varargin{1}, 'min')
                    setVal = 3.3;
                    set(obj, [], [], 'VOLT', setVal);
                end
            end
%             toc
% %             flushinput(obj.SerialObj)
            
            data = getVolt(obj);
            if abs(data - setVal) <= 0.05
                reply = "Value Set";
            else
                [alarmCode, alarm] = getAlarmCode(obj);
                if alarmCode == 0
                    reply = "Value NOT set correctly.";
                else
                    reply = "Value NOT set. Alarm triggered: " + alarm +...
                        ". " + newline + "Reset Alarm with [ClearAlarmCode()].";
                end
            end
        end
        
        function data = getVolt(obj)
            %getVolt Gets the voltage setting values from the power supply.
            data  = str2double(get(obj, [], [], 'VOLT', []));
        end
        
        function reply = setCurr(obj,varargin)
            %setCurr Sets the Current level
            %   Writes the command - CURR{<current>}[CR] - to the serial
            %   port. Set value is precise to 4 decimal places.
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 60.0
                    setVal = varargin{1};
                    set(obj, [], [], 'CURR', setVal);
                else
                    warning('Value can not be greater than 61.0A. Setting curr to 1A instead.')
                    setVal = 1.0;
                    set(obj, [], [], 'CURR', setVal);
                end
                    
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 60.0;
                    set(obj, [], [], 'CURR', setVal);
                elseif strcmpi(varargin{1}, 'min')
                    setVal = 0.5;
                    set(obj, [], [], 'CURR', setVal);
                end
            end
            
%             wait(0.01)
            data = getCurr(obj);
            if abs(data - setVal) <= 0.05
                reply = "Value Set";
            else
                [alarmCode, alarm] = getAlarmCode(obj);
                if alarmCode == 0
                    reply = "Value NOT set correctly.";
                else
                    reply = "Value NOT set. Alarm triggered: " + alarm +...
                        ". " + newline + "Reset Alarm with [ClearAlarmCode()].";
                end
            end
        end
        
        function data = getCurr(obj)
            %getVolt Gets the voltage setting values from the power supply.
            data  = str2double(get(obj, [], [], 'CURR', []));
        end
        
        function setVoltCurr(obj, volt, curr)
            %setVoltCurr Sets the voltage and current setting values to
            %the power supply.
            
            setVolt(obj, volt);
            setCurr(obj, curr);
        end
        
        function data = getVoltCurr(obj)
            %getVoltCurr Gets the voltage and current setting values from
            %the power supply.
            %
            %  data is a vector of Voltage and Current.
            
            data = [0.0, 0.0];
            data(1) = getVolt(obj);
            data(2) = getCurr(obj);
        end
        
        function reply = connect(obj)
            %Connect Turn on the output. Connects PSU to the circuit.
            %   Writes - SOUT1 - to the PSU.
            
            fprintf(obj.SerialObj, 'OUTP 1');
            
            wait(0.01)
            data = isConnected(obj);
            
            if data == true
                reply = "Terminal Connected";
            else
                reply = "Terminal NOT Connected";
            end
        end%End of ConnectPSU
        
        function reply = disconnect(obj)
            %Disconnect Turn off the output. Disconnects PSU from the circuit.
            %   Writes - SOUT0 - to the PSU.
            
            fprintf(obj.SerialObj, 'OUTP 0');            
            
            wait(0.01)
            data = isConnected(obj);
            
            if data == false
                reply = "Terminal Disconnected";
            else
                reply = "Terminal NOT Disconnected";
            end
        end %End of DisconnectPSU
        
        function data = isConnected(obj)
            %isConnected Gets the state of the PSU Terminals
            
            data = get(obj,[], [], 'OUTP', []);
            data = str2double(data);
            if data == 0
                data = false;
            elseif data == 1
                data = true;
            end
        end
        
        %% Measure Section
        
        function data = measureCurr(obj)
            %measureCurr Gets the measured value of output current.
            %i.e Current at the terminals
            
            if nargin == 1
                data = get(obj, [], 'MEAS','CURR', []);
                data = str2double(data);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        function data = measureVolt(obj)
            %measureVolt Gets the measured value of output voltage.
            %i.e Voltage at the terminals
            
            if nargin == 1
                data= get(obj, [], 'MEAS','VOLT', []);
                data = str2double(data);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        function data = measurePow(obj)
            %measurePow Gets the measured value of input power.
            %i.e Power at the terminals
            
            if nargin == 1
                data = get(obj, [], [],'POWER', []);
                data = str2double(data);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        function data = measureVoltCurr(obj)
            %measureVoltCurr Gets the measured Voltage and current.
            %i.e Voltage and Current at the terminals
            
            if nargin == 1
                data = [0.0, 0.0];
                data(1) = measureVolt(obj);
                data(2) = measureCurr(obj);
                
            else
                error("Too many entries. No arguments are required.");
            end
        end
        
        function data = measureDVM(obj)
            %measureDVM Gets the measured value of digital voltmeter.
            %i.e Voltage at the DVM terminals
            
            if nargin == 1
                data = get(obj, [], 'MEAS','DVM', []);
                data = str2double(data);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        %% PSU Maximums and Minimums
        
        function reply = setMaxPSUVolt(obj, varargin)
            %setMaxPSUVolt Sets the Maximum allowable voltage for the PSU
            
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 81.0
                    setVal = varargin{1};
                    set(obj, 'SETT','VOLT', 'MAX', setVal);
                else
                    warning('Value can not be greater than 81.0V. Setting MAX volt (81 A) instead.')
                    setVal = 81.0;
                    set(obj, 'SETT','VOLT', 'MAX', setVal);
                end
                    
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 81.0;
                    set(obj, 'SETT','VOLT', 'MAX', setVal);
                end
            end
            
%             wait(0.01)
            data = getMaxPSUVolt(obj);
            if abs(data - setVal) <= 0.05
                reply = "Value Set";
            else
                [alarmCode, alarm] = getAlarmCode(obj);
                if alarmCode == 0
                    reply = "Value NOT set correctly.";
                else
                    reply = "Value NOT set. Alarm triggered: " + alarm +...
                        ". " + newline + "Reset Alarm with [ClearAlarmCode()].";
                end
            end
        end
        
        function reply = setMinPSUVolt(obj, varargin)
            %setMinPSUVolt Sets the Minimum allowable voltage for the PSU
            
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 81.0
                    setVal = varargin{1};
                    set(obj, 'SETT','VOLT', 'MIN', setVal);
                else
                    warning('Value can not be greater than 81.0V. Setting MIN volt (0 V) instead.')
                    setVal = 0.0;
                    set(obj, 'SETT','VOLT', 'MIN', setVal);
                end
                    
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'MIN')
                    setVal = 0.0;
                    set(obj, 'SETT','VOLT', 'MIN', setVal);
                end
            end
            
%             wait(0.01)
            data = getMinPSUVolt(obj);
            if abs(str2double(data) - setVal) <= 0.05
                reply = "Value Set";
            else
                [alarmCode, alarm] = getAlarmCode(obj);
                if alarmCode == 0
                    reply = "Value NOT set correctly.";
                else
                    reply = "Value NOT set. Alarm triggered: " + alarm +...
                        ". " + newline + "Reset Alarm with [ClearAlarmCode()].";
                end
            end
        end
        
        function reply = setMaxPSUCurr(obj, varargin)
            %setMaxPSUCurr Sets the Maximum allowable current for the PSU
            
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 61.0
                    setVal = varargin{1};
                    set(obj, 'SETT','CURR', 'MAX', setVal);
                else
                    warning('Value can not be greater than 61.0A. Setting MAX curr (61 A) instead.')
                    setVal = 61.0;
                    set(obj, 'SETT','CURR', 'MAX', setVal);
                end
                    
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 61.0;
                    set(obj, 'SETT','CURR', 'MAX', setVal);
                end
            end
            
%             wait(0.01)
            data = getMaxPSUCurr(obj);
            if abs(str2double(data) - setVal) <= 0.05
                reply = "Value Set";
            else
                [alarmCode, alarm] = getAlarmCode(obj);
                if alarmCode == 0
                    reply = "Value NOT set correctly.";
                else
                    reply = "Value NOT set. Alarm triggered: " + alarm +...
                        ". " + newline + "Reset Alarm with [ClearAlarmCode()].";
                end
            end
        end
        
         function reply = setMinPSUCurr(obj, varargin)
            %setMinPSUCurr Sets the Minimum allowable current for the PSU
            
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 61.0
                    setVal = varargin{1};
                    set(obj, 'SETT','CURR', 'MIN', setVal);
                else
                    warning('Value can not be greater than 60.0A. Setting MIN curr (0 A) instead.')
                    setVal = 0.0;
                    set(obj, 'SETT','CURR', 'MIN', setVal);
                end
                    
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
               if strcmpi(varargin{1}, 'min')
                    setVal = 0.0;
                    set(obj, 'SETT','CURR', 'MIN', setVal);
                end
            end
            
%             wait(0.01)
            data = getMinPSUCurr(obj);
            if abs(str2double(data) - setVal) <= 0.05
                reply = "Value Set";
            else
                [alarmCode, alarm] = getAlarmCode(obj);
                if alarmCode == 0
                    reply = "Value NOT set correctly.";
                else
                    reply = "Value NOT set. Alarm triggered: " + alarm +...
                        ". " + newline + "Reset Alarm with [ClearAlarmCode()].";
                end
            end
            
        end
        
        function data = getMaxPSUVolt(obj)
            %getMaxPSUVolt Gets the maximum Voltage allowed by the PSU
            data  = str2double(get(obj, [], [], 'VOLT', 'MAX'));
        end
        
        function data = getMinPSUVolt(obj)
            %getMinPSUVolt Gets the minimum voltage allowed by the PSU
            data  = str2double(get(obj, [], [], 'VOLT', 'MIN'));
        end
        
        function data = getMaxPSUCurr(obj)
            %getMaxPSUCurr Gets the maximum Current allowed by the PSU
            data  = str2double(get(obj, [], [], 'CURR', 'MAX'));
        end
        
        function data = getMinPSUCurr(obj)
            %getMinPSUCurr Gets the minimum Current allowed by the PSU
            data  = str2double(get(obj, [], [], 'CURR', 'MIN'));
        end
        
         function [data, reply] = getVoltCurrM(obj)
            %getVoltCurrM Gets the Maximum Voltage and Current values
            %the PSU can output.
            %   Writes the command - GMAX[CR] - to the serial port and
            %   receives the data and the reply "OK"
            %
            %   [data, reply] -> data is the max Voltage and Current of
            %   the PSU. Reply returns the success of the operation "OK"
            
            
            [result, reply] = receive(obj, 'GMAX');
            
            data = result;
        end % End of getVoltCurrM
        
        %% Protections
        function enableOVP(obj)
            %enableOVP Enables Over Voltage Protection (OVP)
            set(obj, [],'PORT', 'OVP', 1);
        end
        
        function disableOVP(obj)
            %disableOVP Disables Over Voltage Protection (OVP)
            set(obj, [],'PORT', 'OVP', 0);
        end

        function reply = setOVP(obj,varargin)
            %setOVP Sets the upper voltage limit of power supply
            %Over-voltage Protection
            
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 81.0
                    setVal = varargin{1};
                    set(obj, 'PORT','OVP', 'VOLT', setVal);
                else
                    warning('Value can not be greater than 81.0V. Setting MAX volt (81 A) instead.')
                    setVal = 81.0;
                    set(obj, 'PORT','OVP', 'VOLT', setVal);
                end
                    
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 81.0;
                    set(obj, 'PORT','OVP', 'VOLT', setVal);
                end
            end
            
%             wait(0.01)
            data = getOVP(obj);
            if abs(data - setVal) <= 0.05
                reply = "Value Set";
            else
                [alarmCode, alarm] = getAlarmCode(obj);
                if alarmCode == 0
                    reply = "Value NOT set correctly.";
                else
                    reply = "Value NOT set. Alarm triggered: " + alarm +...
                        ". " + newline + "Reset Alarm with [ClearAlarmCode()].";
                end
            end
        end %End of setOVP
        
        function data = getOVP(obj)
            %getOVP Gets the Over-voltage protection (OVP) value from
            %the power supply.
            data  = str2double(get(obj, 'PORT', 'OVP', 'VOLT', []));
        end % End of getOVP
        
        function enableOCP(obj)
            %enableOCP Enables Over Current Protection (OCP)
            set(obj, [],'PORT', 'OCP', 1);
        end
        
        function disableOCP(obj)
            %disableOCP Disables Over Current Protection (OCP)
            set(obj, [],'PORT', 'OCP', 0);
        end
        
        function reply = setOCP(obj,varargin)
            %setOCP Sets the Over-current Protection of power supply.

            
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 61.0
                    setVal = varargin{1};
                    set(obj, 'PORT','OCP', 'CURR', setVal);
                else
                    warning('Value can not be greater than 61.0A. Setting MAX curr (61 A) instead.')
                    setVal = 61.0;
                    set(obj, 'PORT','OCP', 'CURR', setVal);
                end
                    
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 61.0;
                    set(obj, 'PORT','OCP', 'CURR', setVal);
                else
                    warning("Argument not allowed. Try again with values between 0 and 61, or 'max'.")
                    return
                end
            end
            
%             wait(0.01)
            data = getOCP(obj);
            if abs(str2double(data) - setVal) <= 0.05
                reply = "Value Set";
            else
                [alarmCode, alarm] = getAlarmCode(obj);
                if alarmCode == 0
                    reply = "Value NOT set correctly.";
                else
                    reply = "Value NOT set. Alarm triggered: " + alarm +...
                        ". " + newline + "Reset Alarm with [ClearAlarmCode()].";
                end
            end
        end %End of setOCP
        
        function data = getOCP(obj)
            %getOCP Gets the Over-current protection (OCP) value from
            %the power supply.
            data  = str2double(get(obj, 'PORT', 'OCP', 'CURR', []));
        end % End of getOCP
        
         function enableOPP(obj)
            %enableOPP Enables Over Power Protection (OPP)
            set(obj, [],'PORT', 'OPP', 1);
        end
        
        function disableOPP(obj)
            %disableOCP Disables Over Power Protection (OPP)
            set(obj, [],'PORT', 'OPP', 0);
        end
        
        function reply = setOPP(obj,varargin)
            %setOPP Sets the Over Power Protection of power supply.
            
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 1121.0
                    setVal = varargin{1};
                    set(obj, 'PORT','OPP', 'POWR', setVal);
                else
                    warning('Value can not be greater than 1121.0W. Setting MAX Power (1121 W) instead.')
                    setVal = 1121.0;
                    set(obj, 'PORT','OPP', 'POWR', setVal);
                end
                    
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 1121.0;
                    set(obj, 'PORT','OPP', 'POWR', setVal);
                else
                    warning("Argument not allowed. Try again with values between 0 and 1121, or 'max'.")
                    return
                end
            end
            
%             wait(0.01)
            data = getOPP(obj);
            if abs(str2double(data) - setVal) <= 0.05
                reply = "Value Set";
            else
                [alarmCode, alarm] = getAlarmCode(obj);
                if alarmCode == 0
                    reply = "Value NOT set correctly.";
                else
                    reply = "Value NOT set. Alarm triggered: " + alarm +...
                        ". " + newline + "Reset Alarm with [ClearAlarmCode()].";
                end
            end
        end %End of setOCP
        
        function data = getOPP(obj)
            %getOCP Gets the Over-current protection (OCP) value from
            %the power supply.
            data  = str2double(get(obj, 'PORT', 'OPP', 'POWR', []));
        end % End of getOCP
        
        function enableCCCV(obj)
            %enableCCCV Enables Constant Current to Constant Voltage
            %Protection (CCCV)
            set(obj, [],'PORT', 'CCCV', 1);
        end
        
        function disableCCCV(obj)
            %disableCCCV Disables Constant Current to Constant Voltage
            %Protection (CCCV)
            set(obj, [],'PORT', 'CCCV', 0);
        end
        
        function enableCVCC(obj)
            %enableCVCC Enables Constant Voltage to Constant Current
            %Protection (CVCC)
            set(obj, [],'PORT', 'CVCC', 1);
        end
        
        function disableCVCC(obj)
            %disableCVCC Disables Constant Voltage to Constant Current
            %Protection (CVCC)
            set(obj, [],'PORT', 'CVCC', 0);
        end
        
        function stateCode = checkProtStates(obj)
           %checkProtStates Queries the state of protection settings.
           % Unfortunately, the manual doesn't specify in detail what the codes refer to. 
           stateCode = get(obj, [], [], 'STATE', []);
        end
        
    end %End of METHODS (Public)
    
    
end