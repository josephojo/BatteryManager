classdef APM_PSU < handle
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
    
    properties (Access = private)
       SerialObj 
    end
    
    properties
        
        COMPort % The COM Port of the device e.g 'COM3'
        baudRate % The Baudrate of the device COM Port e.g 19200
        byteOrder % The ByteOrder of the device COM Port e.g big-endian or little-endian
        dataBits % The Databits of the device COM Port e.g 8
        stopBits % The Stopbits of the device COM Port e.g 1
        terminator % The Terminator of the Port e.g 'LF'(Works better)
        timeout     % Allowed time in seconds to complete read and write operations
        %         PortConnected % Property for verifying whether or not the machine is connected
    end %End of PROPERTIES (Public)
    
    methods (Access = private)
        
        function Set(obj, header1, header2, cmnd, value)
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
            write(obj.SerialObj, command, 'char');
            wait(0.01)
            
            %             % Check for Errors
            %             [~, alarm] = getAlarmCode(obj);
            %             reply = alarm;
            
        end %End of set
        
        %-----------------------------------------------------------------
        
        function data = Get(obj, header1, header2, comnd, value)
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
            write(obj.SerialObj, command, 'char');
            
            % Wait until a variable is available or until timeout
            tempTimer = tic;
            while obj.SerialObj.NumBytesAvailable == 0
                if(toc(tempTimer) > obj.timeout)
                    break;
                end
            end
            
            data = "";
            while obj.SerialObj.NumBytesAvailable ~= 0
                data = data + readline(obj.SerialObj);
            end
            
            %             % Check for Errors
            %             [~, alarm] = getAlarmCode(obj);
            %             reply = alarm;
            
        end %End of get ###################################
        
        
    end %End of METHODS (Private)
    
    methods
        
        function obj = APM_PSU(port, varargin)
            %APM_PSU Initiates an instance of APM_PSU that takes
            %the COM port or serial object as an argument.
            %   This Constructor creates a generic serial object with
            %   Baudrate = 19200, DataBits = 8, Parity = 'none',
            %   StopBits = 1, and Terminator = 'LF', or otherwise specified.
            %   These settings are adjustable for and on the APM SPS80VDC1000W PSU.
            %
            %   Input:
            %       port :          'COM#' (String class) or serialObj (serial class)
            %       varargin :
            
            if strcmpi(class(port),'serial')
                obj.SerialObj = port;
                
                % If the argument is a serial object
           elseif nargin == 2
                if(strcmpi(class(port), 'string') || ischar(port)...
                    && max(ismember(upper(port),upper("serialobj"))))
                    obj.SerialObj = varargin{1};
                end
                
                % if the typical way of passing in a COM-Port is used
            else
                connectSerial(obj, port, varargin{:});
            end
            
        end
        
        function set.baudRate(obj, value)
            obj.baudRate = value;
            obj.SerialObj.BaudRate = value;
        end
        
        function set.dataBits(obj, value)
            obj.dataBits = value;
            obj.SerialObj.DataBits = value;
        end
        
        function set.byteOrder(obj, value)
            obj.byteOrder = value;
            obj.SerialObj.ByteOrder = value;
        end
        
        function set.stopBits(obj, value)
            obj.stopBits = value;
            obj.SerialObj.StopBits = value;
        end
        
        function set.terminator(obj, value)
            obj.terminator = value;
            configureTerminator(obj.SerialObj, value);
        end
        
        function set.timeout(obj, value)
            obj.timeout = value;
            obj.SerialObj.Timeout = value;
        end
        
        
        function connectSerial(obj, port, varargin)
            if isempty(obj.SerialObj)
                
                % Varargin Evaluation
                % Code to implement user defined values
                param = struct(...
                    'baudRate',       115200, ...
                    'dataBits',       8, ...
                    'byteOrder',      'little-endian',...
                    'stopBits',       1, ...
                    'terminator',     'LF', ...
                    'timeout',         10);
                
                % read the acceptable names
                paramNames = fieldnames(param);
                
                % Ensure variable entries are pairs
                nArgs = length(varargin);
                if round(nArgs/2)~=nArgs/2
                    error('APM_PSU Class needs propertyName/propertyValue pairs')
                end
                
                for pair = reshape(varargin,2,[]) %# pair is {propName;propValue}
                    inpName = pair{1}; %# make case insensitive
                    
                    if any(strcmpi(inpName,paramNames))
                        %# overwrite options. If you want you can test for the right class here
                        %# Also, if you find out that there is an option you keep getting wrong,
                        %# you can use "if strcmp(inpName,'problemOption'),testMore,end"-statements
                        param.(inpName) = pair{2};
                    else
                        error('%s is not a recognized parameter name',inpName)
                    end
                end
                
                obj.COMPort = upper(port);
                s = serialport(obj.COMPort, param.baudRate); %Creates a serial port object
                obj.SerialObj = s;

                obj.baudRate    = param.baudRate;
                obj.dataBits    = param.dataBits;
                obj.byteOrder   = param.byteOrder;
                obj.stopBits    = param.stopBits;
                obj.terminator  = param.terminator;
                obj.timeout     = param.timeout;
            end
        end
        
        
        function reply = disconnectSerial(obj)
            %disconnectSerial Closes tha serial port.
            obj.SerialObj = [];
            
            reply = "Disconnected";
        end
        
        
        function response = serialStatus(obj)
            %serialStatus Reports if the serial port is "connected" or
            %"disconnected".
           if isempty(obj.SerialObj)
               response = "Disconnected";
           else
               if isvalid(obj.SerialObj)
                   response = "Connected";
               end
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
            
            Set(obj,[], 'SYST', cmnd,[]);
            
            wait(0.05);
            
            resp = "";
            while obj.SerialObj.NumBytesAvailable ~= 0
                resp = resp + readline(obj.SerialObj);
            end
            
            if strcmpi(resp, "OK")
                reply = ctrl + " control has been set.";
            else
                reply = "Control could not be set.";
            end
        end
        
        function ID = WhoAmI(obj)
            write(obj.SerialObj, '*IDN?', 'char');
            
            % Wait until a variable is available or until timeout
            tempTimer = tic;
            while obj.SerialObj.NumBytesAvailable == 0
                if(toc(tempTimer) > obj.timeout)
                    break;
                end
            end
            
            data = "";
            while obj.SerialObj.NumBytesAvailable ~= 0
                data = data + readline(obj.SerialObj);
            end
            ID = string(data);
        end
        
        function [alarmState, alarm] = getAlarmCode(obj)
            %getAlarmCode Checks for Triggered Alarms in PSU
            
            % Check for Alarms
            write(obj.SerialObj, 'ASWRS?', 'char');
            
            % Wait until a variable is available or until timeout
            tempTimer = tic;
            while obj.SerialObj.NumBytesAvailable == 0
                if(toc(tempTimer) > obj.timeout)
                    break;
                end
            end
            
            dataStr = "";
            while obj.SerialObj.NumBytesAvailable ~= 0
                dataStr = dataStr + readline(obj.SerialObj);
            end
            
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
            write(obj.SerialObj, 'ASWRC 0', 'char');
            
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
                    Set(obj, [], [], 'VOLT', varargin{1});
                else
                    warning('Value can not be greater than 80.0V. Setting MAX curr (80 V) instead.')
                end
                
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 80.0;
                    Set(obj, [], [], 'VOLT', setVal);
                elseif strcmpi(varargin{1}, 'min')
                    setVal = 3.3;
                    Set(obj, [], [], 'VOLT', setVal);
                end
            end
            
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
            data  = str2double(Get(obj, [], [], 'VOLT', []));
        end
        
        function reply = setCurr(obj,varargin)
            %setCurr Sets the Current level
            %   Writes the command - CURR{<current>}[CR] - to the serial
            %   port. Set value is precise to 4 decimal places.
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 60.0
                    setVal = varargin{1};
                    Set(obj, [], [], 'CURR', setVal);
                else
                    warning('Value can not be greater than 61.0A. Setting curr to 1A instead.')
                    setVal = 1.0;
                    Set(obj, [], [], 'CURR', setVal);
                end
                
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 60.0;
                    Set(obj, [], [], 'CURR', setVal);
                elseif strcmpi(varargin{1}, 'min')
                    setVal = 0.5;
                    Set(obj, [], [], 'CURR', setVal);
                end
            end
            
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
            data  = str2double(Get(obj, [], [], 'CURR', []));
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
            
            write(obj.SerialObj, 'OUTP 1', 'char');
            
            wait(0.1)
            data = isConnected(obj);
            
            if data == 1
                reply = "Terminal Connected";
            else
                reply = "Terminal NOT Connected";
            end
        end%End of ConnectPSU
        
        function reply = disconnect(obj)
            %Disconnect Turn off the output. Disconnects PSU from the circuit.
            %   Writes - SOUT0 - to the PSU.
            
            write(obj.SerialObj, 'OUTP 0', 'char');
            
            wait(0.1)
            data = isConnected(obj);
            
            if data == 0
                reply = "Terminal Disconnected";
            else
                reply = "Terminal NOT Disconnected";
            end
        end %End of DisconnectPSU
        
        function data = isConnected(obj)
            %isConnected Gets the state of the PSU Terminals
            
            data = Get(obj,[], [], 'OUTP', []);
            data = str2double(data);
            
        end
        
        %% Measure Section
        
        function data = measureCurr(obj)
            %measureCurr Gets the measured value of output current.
            %i.e Current at the terminals
            
            if nargin == 1
                data = Get(obj, [], 'MEAS','CURR', []);
                data = str2double(data);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        function data = measureVolt(obj)
            %measureVolt Gets the measured value of output voltage.
            %i.e Voltage at the terminals
            
            if nargin == 1
                data= Get(obj, [], 'MEAS','VOLT', []);
                data = str2double(data);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        function data = measurePow(obj)
            %measurePow Gets the measured value of input power.
            %i.e Power at the terminals
            
            if nargin == 1
                data = Get(obj, [], [],'POWER', []);
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
                data = Get(obj, [], 'MEAS','DVM', []);
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
                    Set(obj, 'SETT','VOLT', 'MAX', setVal);
                else
                    warning('Value can not be greater than 81.0V. Setting MAX volt (81 A) instead.')
                    setVal = 81.0;
                    Set(obj, 'SETT','VOLT', 'MAX', setVal);
                end
                
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 81.0;
                    Set(obj, 'SETT','VOLT', 'MAX', setVal);
                end
            end
            
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
                    Set(obj, 'SETT','VOLT', 'MIN', setVal);
                else
                    warning('Value can not be greater than 81.0V. Setting MIN volt (0 V) instead.')
                    setVal = 0.0;
                    Set(obj, 'SETT','VOLT', 'MIN', setVal);
                end
                
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'MIN')
                    setVal = 0.0;
                    Set(obj, 'SETT','VOLT', 'MIN', setVal);
                end
            end
            
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
                    Set(obj, 'SETT','CURR', 'MAX', setVal);
                else
                    warning('Value can not be greater than 61.0A. Setting MAX curr (61 A) instead.')
                    setVal = 61.0;
                    Set(obj, 'SETT','CURR', 'MAX', setVal);
                end
                
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 61.0;
                    Set(obj, 'SETT','CURR', 'MAX', setVal);
                end
            end
            
            
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
                    Set(obj, 'SETT','CURR', 'MIN', setVal);
                else
                    warning('Value can not be greater than 60.0A. Setting MIN curr (0 A) instead.')
                    setVal = 0.0;
                    Set(obj, 'SETT','CURR', 'MIN', setVal);
                end
                
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'min')
                    setVal = 0.0;
                    Set(obj, 'SETT','CURR', 'MIN', setVal);
                end
            end
            
            
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
            data  = str2double(Get(obj, [], [], 'VOLT', 'MAX'));
        end
        
        function data = getMinPSUVolt(obj)
            %getMinPSUVolt Gets the minimum voltage allowed by the PSU
            data  = str2double(Get(obj, [], [], 'VOLT', 'MIN'));
        end
        
        function data = getMaxPSUCurr(obj)
            %getMaxPSUCurr Gets the maximum Current allowed by the PSU
            data  = str2double(Get(obj, [], [], 'CURR', 'MAX'));
        end
        
        function data = getMinPSUCurr(obj)
            %getMinPSUCurr Gets the minimum Current allowed by the PSU
            data  = str2double(Get(obj, [], [], 'CURR', 'MIN'));
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
            Set(obj, [],'PORT', 'OVP', 1);
        end
        
        function disableOVP(obj)
            %disableOVP Disables Over Voltage Protection (OVP)
            Set(obj, [],'PORT', 'OVP', 0);
        end
        
        function reply = setOVP(obj,varargin)
            %setOVP Sets the upper voltage limit of power supply
            %Over-voltage Protection
            
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 81.0
                    setVal = varargin{1};
                    Set(obj, 'PORT','OVP', 'VOLT', setVal);
                else
                    warning('Value can not be greater than 81.0V. Setting MAX volt (81 A) instead.')
                    setVal = 81.0;
                    Set(obj, 'PORT','OVP', 'VOLT', setVal);
                end
                
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 81.0;
                    Set(obj, 'PORT','OVP', 'VOLT', setVal);
                end
            end
            
            
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
            data  = str2double(Get(obj, 'PORT', 'OVP', 'VOLT', []));
        end % End of getOVP
        
        function enableOCP(obj)
            %enableOCP Enables Over Current Protection (OCP)
            Set(obj, [],'PORT', 'OCP', 1);
        end
        
        function disableOCP(obj)
            %disableOCP Disables Over Current Protection (OCP)
            Set(obj, [],'PORT', 'OCP', 0);
        end
        
        function reply = setOCP(obj,varargin)
            %setOCP Sets the Over-current Protection of power supply.
            
            
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 61.0
                    setVal = varargin{1};
                    Set(obj, 'PORT','OCP', 'CURR', setVal);
                else
                    warning('Value can not be greater than 61.0A. Setting MAX curr (61 A) instead.')
                    setVal = 61.0;
                    Set(obj, 'PORT','OCP', 'CURR', setVal);
                end
                
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 61.0;
                    Set(obj, 'PORT','OCP', 'CURR', setVal);
                else
                    warning("Argument not allowed. Try again with values between 0 and 61, or 'max'.")
                    return
                end
            end
            
            
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
            data  = str2double(Get(obj, 'PORT', 'OCP', 'CURR', []));
        end % End of getOCP
        
        function enableOPP(obj)
            %enableOPP Enables Over Power Protection (OPP)
            Set(obj, [],'PORT', 'OPP', 1);
        end
        
        function disableOPP(obj)
            %disableOCP Disables Over Power Protection (OPP)
            Set(obj, [],'PORT', 'OPP', 0);
        end
        
        function reply = setOPP(obj,varargin)
            %setOPP Sets the Over Power Protection of power supply.
            
            if (nargin > 0 && isa(varargin{1}, 'double'))
                if varargin{1} <= 1121.0
                    setVal = varargin{1};
                    Set(obj, 'PORT','OPP', 'POWR', setVal);
                else
                    warning('Value can not be greater than 1121.0W. Setting MAX Power (1121 W) instead.')
                    setVal = 1121.0;
                    Set(obj, 'PORT','OPP', 'POWR', setVal);
                end
                
            elseif (nargin > 0 && (isa(varargin{1}, 'string') || isa(varargin{1}, 'char')))
                if strcmpi(varargin{1}, 'max')
                    setVal = 1121.0;
                    Set(obj, 'PORT','OPP', 'POWR', setVal);
                else
                    warning("Argument not allowed. Try again with values between 0 and 1121, or 'max'.")
                    return
                end
            end
            
            
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
            data  = str2double(Get(obj, 'PORT', 'OPP', 'POWR', []));
        end % End of getOCP
        
        function enableCCCV(obj)
            %enableCCCV Enables Constant Current to Constant Voltage
            %Protection (CCCV)
            Set(obj, [],'PORT', 'CCCV', 1);
        end
        
        function disableCCCV(obj)
            %disableCCCV Disables Constant Current to Constant Voltage
            %Protection (CCCV)
            Set(obj, [],'PORT', 'CCCV', 0);
        end
        
        function enableCVCC(obj)
            %enableCVCC Enables Constant Voltage to Constant Current
            %Protection (CVCC)
            Set(obj, [],'PORT', 'CVCC', 1);
        end
        
        function disableCVCC(obj)
            %disableCVCC Disables Constant Voltage to Constant Current
            %Protection (CVCC)
            Set(obj, [],'PORT', 'CVCC', 0);
        end
        
        function stateCode = checkProtStates(obj)
            %checkProtStates Queries the state of protection settings.
            % Unfortunately, the manual doesn't specify in detail what the codes refer to.
            stateCode = Get(obj, [], [], 'STATE', []);
        end
        
    end %End of METHODS (Public)
    
    
end