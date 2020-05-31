classdef Array_ELoad < handle
    %Array_ELoad class handles control and data recording primarily for the
    %Array 3721A Electronic Load(ELoad). Other ELoads might also be
    %compatible, you would need to confirm this yourself.
    %   This class uses the serial (RS232) protocol to send commands and
    %   receive data from the ELoad.
    %
    %   The following Subsystems have not been implemented:
    %       - CC Protection functions
    %       - List Subsystem and Functions
    %       - Status Subsystem and Functions
    %
    %
    %Change Log
    %   CHANGE                                      REVISION	DATE-YYMMDD
    %   Initial Revision                            00          181128
    %   Replaced global variable 's' with           01          181201
    %       class property SerialObj
    %   Removed automatic serial port open and      02          190107
    %       close with functions. User will be
    %       required to close ports manually
    
    properties (SetAccess = private)        
        SerialObj % Returns the serial object used by the device
    end %End of PROPERTIES (Private)
    
    properties

        COMPort % The COM Port of the device e.g 'COM2'
        baudRate % The Baudrate of the device COM Port e.g 19200
        byteOrder % The ByteOrder of the device COM Port e.g big-endian or little-endian
        dataBits % The Databits of the device COM Port e.g 8
        stopBits % The Stopbits of the device COM Port e.g 1
        terminator % The Terminator of the Port e.g 'LF'(Works better)
        timeout     % Allowed time in seconds to complete read and write operations
        Connected % Property for verifying whether or not the machine is connected
    end %End of PROPERTIES (Public)
    
    methods (Access = private)
        
        function reply = Set(obj, header1, header2, cmnd, value)
            %Set Makes most write commands to the ELoad
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
                
            elseif (isempty(value) == 0 && isa(value, 'char'))
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
            writeline(obj.SerialObj, command);
            wait(0.01)
            
            
            
            % Check for Errors
           [alarmState, alarm]  = getAlarmCode(obj);
            
            if alarmState == false
                reply = "Success";
            else
                reply = alarm;
            end
            
        end %End of Set
        
        %-----------------------------------------------------------------
        
        function [data, reply] = Get(obj, header1, header2, comnd, value)
            %Get Makes most read commands from  the ELoad
            %   Writes the command - header:comnd?[LF] - and receives the
            %   reponse from the serialport including the reply 'Success'
            %   or Failed - {Error}.
            
            if (isempty(value) == 0 && isa(value, 'char'))
                % If both headers are empty
                if isempty(header1) && isempty(header2)
                    command = strcat(comnd,"? ", value);
                elseif isempty(header1)== 0 && isempty(header2)
                    command = strcat(header1, ':', comnd,"? ", value);
                elseif isempty(header1) && isempty(header2)== 0
                    command = strcat(header2, ':', comnd,"? ", value);
                else
                    command = strcat(header1,':',header2,':',comnd,"? ",value);
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
            writeline(obj.SerialObj, command);
            
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
            data = extractBefore(data, strlength(data));
            
            % Check for Errors
           [alarmState, alarm]  = getAlarmCode(obj);
            
            if alarmState == false
                reply = "Success";
            else
                reply = alarm;
            end
        end %End of Get ###################################
        
        
    end %End of METHODS (Private)
    
    methods
        
        %% General Section
        
        function obj = Array_ELoad(port, varargin)
            %Array_ELoad Initiates an instance of Array_ELoad that takes
            %the COM port or serial object as an argument.
            %   This Constructor creates a generic serial object with
            %   Baudrate = 9600, DataBits = 8, Parity = 'none',
            %   StopBits = 1, and Terminator = 'LF'. These settings are
            %   adjustable for and on the Array 3721A ELoad.
            %   port = 'COM#' (String)
            
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
        
        function reply = connectSerial(obj, port, varargin)
            %connect2Serial Connects to a serial port
            if isempty(obj.SerialObj)
                
                % Varargin Evaluation
                % Code to implement user defined values
                param = struct(...
                    'baudRate',       38400, ...
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
                    error('Array_ELoad Class needs propertyName/propertyValue pairs')
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
                
                reply = "Connected";
                
            else
                reply = "Already Connected";
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
        
        function reply = SetSystCtrl(obj, ctrl)
            %SetSystCtrl Sets the system control mode to either remote or
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
            
            reply = Set(obj,[], 'SYST', cmnd,[]);
            
             if strcmpi(reply, "Success")
                reply = ctrl + " control has been set.";
            else
                reply = "Control could not be set.";
            end
            
        end
        
        function reply = SetMode(obj, mode)
            %SetMode Sets the operating mode of the ELoad.
            %   The modes supported are as follows:
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            %   CV  - Constant Voltage Mode (0-80V)
            %   CRL - Constant Resistance Low Mode (0.02~2?)
            %   CRM - Constant Resistance Medium Mode (2~20?)
            %   CRH - Constnat Resistance High Mode (20~2000?)
            %   CPV - Constant Power, Voltage Mode (0~400W)
            %   CPC - Constant Power, Current Mode (0~400W)
            
            reply = Set(obj,[],[], 'MODE', mode);
        end
        
        function [data, reply] = GetMode(obj)
            %GetMode Gets the operating mode of the ELoad.
            %   The modes supported are as follows:
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            %   CV  - Constant Voltage Mode (0-80V)
            %   CRL - Constant Resistance Low Mode (0.02~2?)
            %   CRM - Constant Resistance Medium Mode (2~20?)
            %   CRH - Constnat Resistance High Mode (20~2000?)
            %   CPV - Constant Power, Voltage Mode (0~400W)
            %   CPC - Constant Power, Current Mode (0~400W)
            
            [data, reply] = Get(obj,[], [], 'MODE', []);
            
        end % End of GetMode
        
        %% Constant Current Section
        
        function reply = SetLev_CC(obj, ccLev)
            %SetLev_CC This command sets the immediate current level for CC
            %Mode.
            %   INPUT [ccVal] : Decimal Value (0 ~ 40A)
            %                   or char array ('MAX' or 'MIN')
            %   Function changes the mode (CCL or CCH) based on the
            %   decimal ccVal provided.
            %
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            %
            %   Inputting 'MAX' sets 40A (if CCH) or 4A(if CCL)as the value
            %   Inputting 'MIN' sets 0A as the value.
            
            if isa(ccLev, 'double')
                if ccLev <= 4.0
                    SetMode(obj, 'CCL');
                elseif ccLev > 4.0 && ccLev <= 40.0
                    SetMode(obj, 'CCH');
                else
                    error('Current Value cannot be greater than 40.000 A');
                end
                reply = Set(obj, [], [], 'CURR', upper(ccLev));
            else
                if strcmpi(ccLev, "MAX") || strcmpi(ccLev, "MIN")
                    reply = Set(obj, [], [], 'CURR', upper(ccLev));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
            
        end
        
        function [data,mode, reply] = GetLev_CC(obj, varargin)
            %GetLev_CC This command gets the immediate current level for CC
            %Mode.
            %   Inputs: 0 to 2 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the current setting for
            %   the current mode
            %   - Inputting one argument ('max' or 'MAX') gets the max
            %   current setting for the current mode.
            %
            %   - Inputting one argument ('min' or 'MIN') gets the min
            %   current setting for the current mode.
            %
            %   - Inputting two arguments 'MIN' or 'MAX' and mode :'CCL or
            %   'CCH' gets the min or max values for the mode specified.
            %
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            
            if nargin == 1
                [data, reply] = Get(obj, [], [], 'CURR', []);
                data = str2double(data);
                mode = GetMode(obj);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], [], 'CURR',...
                        upper(varargin{1}));
                    mode = GetMode(obj);
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            elseif nargin == 3
                dataTemp = GetLev_CC(obj);
                
                % If the second optional argument is CCL or CCH, use that
                % to provide the result
                if strcmpi(varargin{2},"CCL")||strcmpi(varargin{2},"CCH")
                    SetMode(obj, upper(varargin{2}));
                    [data, reply] = Get(obj, [], [], 'CURR',...
                        upper(varargin{1}));
                    mode = upper(varargin{2});
                    data = str2double(data);
                    
                    SetLev_CC(obj, dataTemp);
                else
                    errMessage = ['Invalid Specifier. Try using "CCL" '...
                        'or "CCH" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 2'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetTranLoLev_CC(obj, loLev)
            %SetTranLoLev_CC Sets the Low Current Level for transient
            %CC mode Operation.
            %   Input: "loLev" is the low level current value in transient
            %   mode.
            %
            %   In the transient operation, the input current switches
            %   between the high and the low level, in the method of
            %   continuous, pulsed or toggled transient operations.
            
            %   INPUT [loLev] : Decimal Value (0 ~ 40A) and less than hiLev
            %                   or char array ('MAX' or 'MIN')
            %   Function uses the CCH mode because of the wider range.
            %
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            
            if isa(loLev, 'double')
                SetMode(obj, 'CCH');
                reply = Set(obj, [], 'CURR','LOW', upper(loLev));
            else
                loLev = upper(loLev);
                if strcmp(loLev, "MAX") || strcmp(loLev, "MIN")
                    reply = Set(obj, [], 'CURR','LOW', upper(loLev));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data,mode, reply] = GetTranLoLev_CC(obj, varargin)
            %GetTranLoLev_CC This command gets the Low level current for
            %transient CC mode Operation.
            %   In the transient operation, the input current switches
            %   between the high and the low level, in the method of
            %   continuous, pulsed or toggled transient operations.
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the current setting and
            %   mode
            %   - Inputting 'max' or 'MAX' gets the max current setting in
            %   CCH mode.
            %   - Inputting 'min' or 'MIN' gets the min current setting in
            %   CCH mode.
            %
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            
            SetMode(obj, 'CCH');
            mode = "CCH";
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'CURR','LOW', []);
                data = str2double(data);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'CURR','LOW',...
                        upper(varargin{1}));
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetTranHiLev_CC(obj, hiLev)
            %SetTranHiLev_CC Sets the High Current Level for transient
            %CC mode Operation.
            %   Input: "hiLev" is the High level current value in transient
            %   mode.
            %
            %   In the transient operation, the input current switches
            %   between the high and the low level, in the method of
            %   continuous, pulsed or toggled transient operations.
            
            %   INPUT [hiLev] : Decimal Value (0 ~ 40A) and less than hiLev
            %                   or char array ('MAX' or 'MIN')
            %   Function uses the CCH mode because of the wider range.
            %
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            
            if isa(hiLev, 'double')
                SetMode(obj, 'CCH');
                reply = Set(obj, [], 'CURR','HIGH', upper(hiLev));
            else
                if strcmpi(hiLev, "MAX") || strcmpi(hiLev, "MIN")
                    reply = Set(obj, [], 'CURR','HIGH', upper(hiLev));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data,mode, reply] = GetTranHiLev_CC(obj, varargin)
            %GetTranHiLev_CC This command gets the High level current for
            %transient CC mode Operation.
            %   In the transient operation, the input current switches
            %   between the high and the low level, in the method of
            %   continuous, pulsed or toggled transient operations.
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the current setting and
            %   mode
            %   - Inputting 'max' or 'MAX' gets the max current setting in
            %   CCH mode.
            %   - Inputting 'min' or 'MIN' gets the min current setting in
            %   CCH mode.
            %
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            
            SetMode(obj, 'CCH');
            mode = "CCH";
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'CURR','HIGH', []);
                data = str2double(data);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'CURR','HIGH',...
                        upper(varargin{1}));
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetTrigLev_CC(obj, trigLev)
            %SetTrigLev_CC Sets the triggered current level.
            %
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            
            if isa(trigLev, 'double')
                if trigLev <= 4.0
                    SetMode(obj, 'CCL');
                elseif trigLev > 4.0 && trigLev <= 40.0
                    SetMode(obj, 'CCH');
                else
                    error('Current Value cannot be greater than 40.000 A');
                end
                reply = Set(obj, [], 'CURR', 'TRIG', upper(trigLev));
            else
                if strcmpi(trigLev, "MAX") || strcmpi(trigLev, "MIN")
                    reply = Set(obj, [], 'CURR', 'TRIG', upper(trigLev));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data,mode, reply] = GetTrigLev_CC(obj, varargin)
            %GetTrigLev_CC This command gets the immediate trigger current
            %level for CC Mode.
            %   Inputs: 0 to 2 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the current setting for
            %   the current mode
            %   - Inputting one argument ('max' or 'MAX') gets the max
            %   trig current setting for the current mode.
            %
            %   - Inputting one argument ('min' or 'MIN') gets the min
            %   trig current setting for the current mode.
            %
            %   - Inputting two arguments 'MIN' or 'MAX' and mode :'CCL or
            %   'CCH' gets the min or max values for the mode specified.
            %
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'CURR', 'TRIG', []);
                data = str2double(data);
                mode = GetMode(obj);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'CURR', 'TRIG',...
                        upper(varargin{1}));
                    mode = GetMode(obj);
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            elseif nargin == 3
                dataTemp = GetTrigLev_CC(obj);
                
                % If the second optional argument is CCL or CCH, use that
                % to provide the result
                if strcmpi(varargin{2},"CCL")||strcmpi(varargin{2},"CCH")
                    SetMode(obj, upper(varargin{2}));
                    [data, reply] = Get(obj, [],'CURR', 'TRIG',...
                        upper(varargin{1}));
                    mode = upper(varargin{2});
                    data = str2double(data);
                    
                    SetTrigLev_CC(obj, dataTemp);
                else
                    errMessage = ['Invalid Specifier. Try using "CCL" '...
                        'or "CCH" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 2'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetRiseRate_CC(obj, rate)
            %SetRiseRate_CC Sets current rise rate in CC mode.
            %
            %   INPUT [rate] : Decimal Value (0.001 ~ 4A/us)
            %                   or char array ('MAX' or 'MIN')
            %   The RiseRate range is the same for both CCL and CCH. The
            %   only difference is that in CCL the riserate is one-tenth of
            %   the set value.
            %
            %   Inputting 'MAX' sets 4A/us (Array 3721A) as the value.
            %   Inputting 'MIN' sets 0.001A/us (Array 3721A) as the value.
            %
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            
            if isa(rate, 'double')
                reply = Set(obj, 'CURR', 'RISE','RATE', upper(rate));
            else
                if strcmpi(rate, "MAX") || strcmpi(rate, "MIN")
                    reply = Set(obj, 'CURR', 'RISE','RATE', upper(rate));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data,mode, reply] = GetRiseRate_CC(obj, varargin)
            %GetRiseRate_CC Sets current rise rate in CC mode.
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the current setting and
            %   current mode
            %   - Inputting 'max' or 'MAX' gets the max RiseRate setting
            %   the current mode.
            %
            %   - Inputting 'min' or 'MIN' gets the min RiseRate setting in
            %   the current mode.
            %
            %   - Inputting two arguments 'MIN' or 'MAX' and mode :'CCL or
            %   'CCH' gets the min or max RiseRates for the mode specified.
            %
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            
            if nargin == 1
                [data, reply] = Get(obj, 'CURR', 'RISE','RATE', []);
                data = str2double(data);
                mode = GetMode(obj);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, 'CURR', 'RISE','RATE',...
                        upper(varargin{1}));
                    mode = GetMode(obj);
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            elseif nargin == 3
                %                 % Gets and temporarily stores the current machine value
                %                 [dataTemp, modeTemp] = GetRiseRate_CC(obj);
                
                % If the second optional argument is CCL or CCH, use that
                % to provide the result
                if strcmpi(varargin{2},"CCL")||strcmpi(varargin{2},"CCH")
                    SetMode(obj, upper(varargin{2}));
                    [data, reply] = Get(obj, 'CURR', 'RISE','RATE',...
                        upper(varargin{1}));
                    mode = upper(varargin{2});
                    data = str2double(data);
                    
                    %                     SetMode(obj, modeTemp);
                    %                     SetRiseRate_CC(obj, dataTemp);
                else
                    errMessage = ['Invalid Specifier. Try using "CCL" '...
                        'or "CCH" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 2'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetFallRate_CC(obj, rate)
            %SetFallRate_CC Sets current fall rate in CC mode.
            %
            %   INPUT [rate] : Decimal Value (0.001 ~ 4A/us)
            %                   or char array ('MAX' or 'MIN')
            %   The FallRate range is the same for both CCL and CCH. The
            %   only difference is that in CCL the FallRate is one-tenth of
            %   the set value.
            %
            %   Inputting 'MAX' sets 4A/us (Array 3721A) as the value.
            %   Inputting 'MIN' sets 0.001A/us (Array 3721A) as the value.
            %
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            
            if isa(rate, 'double')
                reply = Set(obj, 'CURR', 'FALL','RATE', upper(rate));
            else
                if strcmpi(rate, "MAX") || strcmpi(rate, "MIN")
                    reply = Set(obj, 'CURR', 'FALL','RATE', upper(rate));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data,mode, reply] = GetFallRate_CC(obj, varargin)
            %GetFallRate_CC Sets current rise rate in CC mode.
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the current setting and
            %   current mode
            %   - Inputting 'max' or 'MAX' gets the max FallRate setting
            %   the current mode.
            %
            %   - Inputting 'min' or 'MIN' gets the min FallRate setting in
            %   the current mode.
            %
            %   - Inputting two arguments 'MIN' or 'MAX' and mode :'CCL or
            %   'CCH' gets the min or max FallRates for the mode specified.
            %
            %   CCL - Constant Current Low Mode (0-4A)
            %   CCH - Constant Current High Mode (0-40A)
            
            if nargin == 1
                [data, reply] = Get(obj, 'CURR', 'FALL','RATE', []);
                data = str2double(data);
                mode = GetMode(obj);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, 'CURR', 'FALL','RATE',...
                        upper(varargin{1}));
                    mode = GetMode(obj);
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            elseif nargin == 3
                %                 % Gets and temporarily stores the current machine value
                %                 [dataTemp, modeTemp] = GetFallRate_CC(obj);
                
                % If the second optional argument is CCL or CCH, use that
                % to provide the result
                if strcmpi(varargin{2},"CCL")||strcmpi(varargin{2},"CCH")
                    SetMode(obj, upper(varargin{2}));
                    [data, reply] = Get(obj, 'CURR', 'FALL','RATE',...
                        upper(varargin{1}));
                    mode = upper(varargin{2});
                    data = str2double(data);
                    
                    %                     SetMode(obj, modeTemp);
                    %                     SetFallRate_CC(obj, dataTemp);
                else
                    errMessage = ['Invalid Specifier. Try using "CCL" '...
                        'or "CCH" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 2'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetProtLev_CC(obj, protLev)
            %SetProtLev_CC Sets current limit at which
            %protection occurs in CC mode.
            %   This function is not yet implemented!
        end
        
        function reply = SetProtStat_CC(obj, protStat)
            %SetProtStat_CC Enable/Disable protection function.
            %   This function is not yet impelemented!
        end
        
        function reply = SetProtDel_CC(obj, protDel)
            %SetProtDel_CC Set the delay before the current protection is
            %activated.
            %   This function is not yet impelemented!
            
        end
        
        %% Constant Voltage Section
        
        function reply = SetLev_CV(obj, cvLev)
            %SetLev_CV This command sets the immediate voltage level for CV
            %Mode.
            %   INPUT [ccVal] : Decimal Value (0 ~ 80V)
            %                   or char array ('MAX' or 'MIN')
            %   Function changes the mode (CCL or CCH) based on the
            %   decimal ccVal provided.
            %
            %   Inputting 'MAX' sets the value to 80V.
            %   Inputting 'MIN' sets  the value to 0V.
            
            if isa(cvLev, 'double')
                SetMode(obj, 'CV');
                reply = Set(obj, [], [], 'VOLT', upper(cvLev));
            else
                if strcmpi(cvLev, "MAX") || strcmpi(cvLev, "MIN")
                    reply = Set(obj, [], [], 'VOLT', upper(cvLev));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
            
        end
        
        function [data,mode, reply] = GetLev_CV(obj, varargin)
            %GetLev_CV This command gets the immediate voltage level for CV
            %Mode.
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the voltage setting for
            %   the current mode
            %   - Inputting one argument ('max' or 'MAX') gets the max
            %   voltage setting for the current mode.
            %
            %   - Inputting one argument ('min' or 'MIN') gets the min
            %   voltage setting for the current mode.
            
            if nargin == 1
                [data, reply] = Get(obj, [], [], 'VOLT', []);
                data = str2double(data);
                mode = 'CV';
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], [], 'VOLT',...
                        upper(varargin{1}));
                    mode = 'CV';
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetCurrLim_CV(obj, cLim)
            %SetCurrLim_CV This command sets the current limit in CV mode.
            %
            %   INPUT [cLim]  : Decimal Value (0 ~ 40A)
            %                   or char array ('MAX' or 'MIN')
            %
            %   Inputting 'MAX' sets the value to 40.00A.
            %   Inputting 'MIN' sets  the value to 0.00A.
            
            if isa(cLim, 'double')
                reply = Set(obj, 'INP', 'LIM', 'CURR', upper(cLim));
            else
                if strcmpi(cLim, "MAX") || strcmpi(cLim, "MIN")
                    reply = Set(obj, 'INP', 'LIM', 'CURR', upper(cLim));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
            
        end
        
        function [data,mode, reply] = GetCurrLim_CV(obj, varargin)
            %GetCurrLim_CV This command gets the current limit in CV Mode.
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the voltage setting for
            %   the current mode
            %   - Inputting one argument ('max' or 'MAX') gets the max
            %   current limit setting in the CV mode.
            %
            %   - Inputting one argument ('min' or 'MIN') gets the min
            %   current limit setting in the CV mode.
            
            if nargin == 1
                [data, reply] = Get(obj, 'INP', 'LIM', 'CURR', []);
                data = str2double(data);
                mode = 'CV';
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, 'INP', 'LIM', 'CURR',...
                        upper(varargin{1}));
                    mode = 'CV';
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetTranLoLev_CV(obj, loLev)
            %SetTranLoLev_CV Sets the Low voltage Level for transient
            %CV mode Operation.
            %   Input: "loLev" is the low level voltage value in transient
            %   mode.
            %
            %   In the transient operation, the input voltage switches
            %   between the high and the low level, in the method of
            %   continuous, pulsed or toggled transient operations.
            
            %   INPUT [loLev] : Decimal Value (0 ~ 80V) and less than hiLev
            %                   or char array ('MAX' or 'MIN')
            
            if isa(loLev, 'double')
                SetMode(obj, 'CV');
                reply = Set(obj, [], 'VOLT','LOW', upper(loLev));
            else
                loLev = upper(loLev);
                if strcmp(loLev, "MAX") || strcmp(loLev, "MIN")
                    reply = Set(obj, [], 'VOLT','LOW', upper(loLev));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data,mode, reply] = GetTranLoLev_CV(obj, varargin)
            %GetTranLoLev_CV This command gets the Low level voltage for
            %transient CV mode Operation.
            %   In the transient operation, the input voltage switches
            %   between the high and the low level, in the method of
            %   continuous, pulsed or toggled transient operations.
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the voltage setting and
            %   mode
            %   - Inputting 'max' or 'MAX' gets the max voltage setting in
            %   CV mode.
            %   - Inputting 'min' or 'MIN' gets the min voltage setting in
            %   CV mode.
            
            mode = "CV";
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'VOLT','LOW', []);
                data = str2double(data);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'VOLT','LOW',...
                        upper(varargin{1}));
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetTranHiLev_CV(obj, hiLev)
            %SetTranHiLev_CV Sets the High voltage Level for transient
            %CV mode Operation.
            %   Input: "hiLev" is the High level voltage value in transient
            %   mode.
            %
            %   In the transient operation, the input voltage switches
            %   between the high and the low level, in the method of
            %   continuous, pulsed or toggled transient operations.
            
            %   INPUT [hiLev] : Decimal Value (80V) and less than hiLev
            %                   or char array ('MAX' or 'MIN')
            
            if isa(hiLev, 'double')
                SetMode(obj, 'CV');
                reply = Set(obj, [], 'VOLT','HIGH', upper(hiLev));
            else
                if strcmpi(hiLev, "MAX") || strcmpi(hiLev, "MIN")
                    reply = Set(obj, [], 'VOLT','HIGH', upper(hiLev));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data,mode, reply] = GetTranHiLev_CV(obj, varargin)
            %GetTranHiLev_CV This command gets the High level voltage for
            %transient CV mode Operation.
            %   In the transient operation, the input voltage switches
            %   between the high and the low level, in the method of
            %   continuous, pulsed or toggled transient operations.
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the voltage setting and
            %   mode
            %   - Inputting 'max' or 'MAX' gets the max voltage setting in
            %   CV mode.
            %   - Inputting 'min' or 'MIN' gets the min voltage setting in
            %   CV mode.
            
            SetMode(obj, 'CV');
            mode = "CV";
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'VOLT','HIGH', []);
                data = str2double(data);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'VOLT','HIGH',...
                        upper(varargin{1}));
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetTrigLev_CV(obj, trigLev)
            %SetTrigLev_CV Sets the triggered voltage level.
            
            if isa(trigLev, 'double')
                reply = Set(obj, [], 'VOLT', 'TRIG', upper(trigLev));
            else
                if strcmpi(trigLev, "MAX") || strcmpi(trigLev, "MIN")
                    reply = Set(obj, [], 'VOLT', 'TRIG', upper(trigLev));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data,mode, reply] = GetTrigLev_CV(obj, varargin)
            %GetTrigLev_CV This command gets the immediate trigger voltage
            %level for CV Mode.
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the current setting for
            %   the current mode
            %   - Inputting one argument ('max' or 'MAX') gets the max
            %   trig voltage setting for the current mode.
            %
            %   - Inputting one argument ('min' or 'MIN') gets the min
            %   trig voltage setting for the current mode.
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'VOLT', 'TRIG', []);
                data = str2double(data);
                mode = 'CV';
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'VOLT', 'TRIG',...
                        upper(varargin{1}));
                    mode = 'CV';
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        %% Constant Resistance Section
        
        function reply = SetLev_CR(obj, crLev)
            %SetLev_CR This command sets the immediate resistance level for
            % CR Mode.
            %   INPUT [crVal] : Decimal Value (0.02? ~ 2000?)resistance
            %                   or char array ('MAX' or 'MIN')
            %   Function changes the mode (CRL, CRM or CRH) based on the
            %   decimal crLev provided.
            %
            %   CRL - Constant Resistance Low Mode (0.02~2?)
            %   CRM - Constant Resistance Medium Mode (2~20?)
            %   CRH - Constnat Resistance High Mode (20~2000?)
            %
            %   Inputting 'MAX' sets 2000.00? in CRH mode as the value
            %   Inputting 'MIN' sets 0.0020 ? as the value.
            
            if isa(crLev, 'double')
                if crLev > 0.02 && crLev <= 2.000
                    SetMode(obj, 'CRL');
                elseif crLev > 2.0 && crLev <= 20.0
                    SetMode(obj, 'CRM');
                elseif crLev > 20.0 && crLev <= 2000.00
                    SetMode(obj, 'CRH');
                else
                    error("Resistance Value cannot be greater than 2000.0" +...
                        "or less than 0.02?");
                end
                reply = Set(obj, [], [], 'RES', upper(crLev));
            else
                if strcmpi(crLev, "MAX") || strcmpi(crLev, "MIN")
                    reply = Set(obj, [], [], 'RES', upper(crLev));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
            
        end
        
        function [data,mode, reply] = GetLev_CR(obj, varargin)
            %GetLev_CR This command gets the immediate Resistance level
            %for CC Mode.
            %   Inputs: 0 to 2 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the Resistance setting for
            %   the current mode
            %   - Inputting one argument ('max' or 'MAX') gets the max
            %   Resistance setting for the current mode.
            %
            %   - Inputting one argument ('min' or 'MIN') gets the min
            %   Resistance setting for the current mode.
            %
            %   - Inputting two arguments 'MIN' or 'MAX' and mode :'CRL',
            %   'CRM' or 'CCH' gets the min or max values for the mode
            %   specified.
            %
            %   CRL - Constant Resistance Low Mode (0.02~2?)
            %   CRM - Constant Resistance Medium Mode (2~20?)
            %   CRH - Constnat Resistance High Mode (20~2000?)
            
            if nargin == 1
                [data, reply] = Get(obj, [], [], 'RES', []);
                data = str2double(data);
                mode = GetMode(obj);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], [], 'RES',...
                        upper(varargin{1}));
                    mode = GetMode(obj);
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            elseif nargin == 3
                dataTemp = GetLev_CR(obj);
                
                % If the second optional argument is CRL, CRM or CRH, use
                % that to provide the result
                if strcmpi(varargin{2},"CRL")||strcmpi(varargin{2},"CRM")...
                        ||strcmpi(varargin{2},"CRH")
                    SetMode(obj, upper(varargin{2}));
                    [data, reply] = Get(obj, [], [], 'RES',...
                        upper(varargin{1}));
                    mode = upper(varargin{2});
                    data = str2double(data);
                    
                    SetLev_CR(obj, dataTemp);
                else
                    errMessage = ['Invalid Specifier. Try using "CRL" '...
                        '"CRM" or "CRH" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 2'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetTranLevs_CR(obj, loLev, hiLev, varargin)
            %SetTranLevs_CR Sets the Low and High Resistance Levels for
            %transient CR mode Operation.
            %
            %   In the transient operation, the input Resistance switches
            %   between the high and the low level, in the method of
            %   continuous, pulsed or toggled transient operations.
            
            %   INPUT [loLev] : is the low level Resistance value in
            %                   transient mode.
            %                   Decimal Value (0.02? ~ 200.00?) and less
            %                   than hiLev or char array ('MAX' or 'MIN')
            %
            %   INPUT [hiLev] : is the high level Resistance value in
            %                   transient mode.
            %                   Decimal Value (0.02? ~ 200.00?) and less
            %                   than hiLev or char array ('MAX' or 'MIN')
            %
            %   INPUT [varargin]: mode. CRL, CRM, or CRH.
            %
            %   It is impossible to select high and low resistance
            %   values across more than one mode. Therefore, you
            %   either select values within the range as shown below, or
            %   'MAX' and 'MIN' coupled with the mode.
            %
            %   CRL - Constant Resistance Low Mode (0.02~2?)
            %   CRM - Constant Resistance Medium Mode (2~20?)
            %   CRH - Constnat Resistance High Mode (20~2000?)
            
            switch(nargin)
                case 3
                    if isa(loLev, 'double') && isa(hiLev, 'double')
                        if loLev <= 2.00 && hiLev <= 2.00
                            SetMode(obj, 'CRL');
                        elseif (loLev > 2.0 && loLev <= 20.0) && (hiLev > 2.0 && hiLev <= 20.0)
                            SetMode(obj, 'CRM');
                        elseif (loLev > 20.0 && loLev <= 2000.0) && (hiLev > 20.0 && hiLev <= 2000.0)
                            SetMode(obj, 'CRH');
                        else
                            errMessage = ['The values provided are not '...
                                'in the same modes.'...
                                'CRL - Constant Resistance Low Mode (0.02~2?)'...
                                'CRM - Constant Resistance Medium Mode (2~20?)'...
                                'CRH - Constnat Resistance High Mode (20~2000?)'];
                            error(errMessage);
                        end
                        
                        Set(obj, [], 'RES', 'LOW', upper(loLev));
                        reply = Set(obj, [], 'RES', 'HIGH', upper(hiLev));
                        
                    elseif isa(loLev, 'double') && ~isa(hiLev, 'double')
                        if loLev <= 2.00
                            SetMode(obj, 'CRL');
                        elseif (loLev > 2.0 && loLev <= 20.0)
                            SetMode(obj, 'CRM');
                        elseif (loLev > 20.0 && loLev <= 2000.0)
                            SetMode(obj, 'CRH');
                        end
                        Set(obj, [], 'RES', 'LOW', upper(loLev));
                        reply = Set(obj, [], 'RES', 'HIGH', upper(hiLev));
                    elseif ~isa(loLev, 'double') && isa(hiLev, 'double')
                        if  hiLev <= 2.00
                            SetMode(obj, 'CRL');
                        elseif (hiLev > 2.0 && hiLev <= 20.0)
                            SetMode(obj, 'CRM');
                        elseif (hiLev > 20.0 && hiLev <= 2000.0)
                            SetMode(obj, 'CRH');
                        end
                        Set(obj, [], 'RES', 'LOW', upper(loLev));
                        reply = Set(obj, [], 'RES', 'HIGH', upper(hiLev));
                    else
                        error('Please enter another argument for the mode');
                    end
                case 4
                    if ~isa(loLev, 'double') && ~isa(hiLev, 'double')
                        if (strcmpi(loLev, "MAX") || strcmpi(loLev, "MIN")) && (strcmpi(hiLev, "MAX") || strcmpi(hiLev, "MIN"))
                            Set(obj, [], 'RES', 'LOW', upper(loLev));
                            reply = Set(obj, [], 'RES', 'HIGH', upper(hiLev));
                        else
                            errMessage = ['Invalid argument. Argument can ...'
                                'either be of type double or "MAX" or "MIN" '];
                            error(errMessage);
                        end
                    end
                otherwise
                    errMessage = 'Too many Arguments.';
                    error(errMessage);
            end
        end
        
        function [data, mode, reply] = GetTranLoLev_CR(obj, varargin)
            %GetTranLoLev_CR This command gets the Low level Resistance for
            %transient CR mode Operation.
            %   In the transient operation, the input Resistance switches
            %   between the high and the low level, in the method of
            %   continuous, pulsed or toggled transient operations.
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the Resistance setting in
            %   the current mode.
            %   - Inputting 'max' or 'MAX' gets the max Resistance setting in
            %   the current mode.
            %   - Inputting 'min' or 'MIN' gets the min Resistance setting in
            %   the current mode.
            %
            %   - Inputting two arguments 'MIN' or 'MAX' and mode :'CRL',
            %   'CRM' or 'CCH' gets the min or max values for the mode
            %   specified.
            %
            %   CRL - Constant Resistance Low Mode (0.02~2?)
            %   CRM - Constant Resistance Medium Mode (2~20?)
            %   CRH - Constnat Resistance High Mode (20~2000?)
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'RES', 'LOW', []);
                data = str2double(data);
                mode = GetMode(obj);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'RES', 'LOW',...
                        upper(varargin{1}));
                    mode = GetMode(obj);
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            elseif nargin == 3
                dataLo = GetTranLoLev_CR(obj);
                dataHi = GetTranHiLev_CR(obj);
                
                % If the second optional argument is CRL, CRM or CRH, use
                % that to provide the result
                if strcmpi(varargin{2},"CRL")||strcmpi(varargin{2},"CRM")...
                        ||strcmpi(varargin{2},"CRH")
                    SetMode(obj, upper(varargin{2}));
                    [data, reply] = Get(obj, [], 'RES', 'LOW',...
                        upper(varargin{1}));
                    mode = upper(varargin{2});
                    data = str2double(data);
                    
                    SetTranLevs_CR(obj, dataLo, dataHi);
                else
                    errMessage = ['Invalid Specifier. Try using "CRL" '...
                        '"CRM" or "CRH" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 2'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function [data,mode, reply] = GetTranHiLev_CR(obj, varargin)
            %GetTranHiLev_CR This command gets the HIGH level Resistance for
            %transient CR mode Operation.
            %   In the transient operation, the input Resistance switches
            %   between the high and the low level, in the method of
            %   continuous, pulsed or toggled transient operations.
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the Resistance setting in
            %   the current mode.
            %   - Inputting 'max' or 'MAX' gets the max Resistance setting in
            %   the current mode.
            %   - Inputting 'min' or 'MIN' gets the min Resistance setting in
            %   the current mode.
            %
            %   - Inputting two arguments 'MIN' or 'MAX' and mode :'CRL',
            %   'CRM' or 'CCH' gets the min or max values for the mode
            %   specified.
            %
            %   CRL - Constant Resistance Low Mode (0.02~2?)
            %   CRM - Constant Resistance Medium Mode (2~20?)
            %   CRH - Constnat Resistance High Mode (20~2000?)
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'RES', 'HIGH', []);
                data = str2double(data);
                mode = GetMode(obj);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'RES', 'HIGH',...
                        upper(varargin{1}));
                    mode = GetMode(obj);
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            elseif nargin == 3
                dataLo = GetTranLoLev_CR(obj);
                dataHi = GetTranHiLev_CR(obj);
                
                % If the second optional argument is CRL, CRM or CRH, use
                % that to provide the result
                if strcmpi(varargin{2},"CRL")||strcmpi(varargin{2},"CRM")...
                        ||strcmpi(varargin{2},"CRH")
                    SetMode(obj, upper(varargin{2}));
                    [data, reply] = Get(obj, [], 'RES', 'HIGH',...
                        upper(varargin{1}));
                    mode = upper(varargin{2});
                    data = str2double(data);
                    
                    SetTranLevs_CR(obj, dataLo, dataHi);
                else
                    errMessage = ['Invalid Specifier. Try using "CRL" '...
                        '"CRM" or "CRH" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 2'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetTrigLev_CR(obj, trigLev)
            %SetTrigLev_CR Sets the triggered resistance level.
            
            SetMode(obj, mode);
            if isa(trigLev, 'double')
                if crLev > 0.02 && crLev <= 2.000
                    SetMode(obj, 'CRL');
                elseif crLev > 2.0 && crLev <= 20.0
                    SetMode(obj, 'CRM');
                elseif crLev > 20.0 && crLev <= 2000.00
                    SetMode(obj, 'CRH');
                else
                    error("Resistance Value cannot be greater " +...
                        "than 2000.00 or less than 0.02?");
                end
                reply = Set(obj, [], 'RES', 'TRIG', upper(trigLev));
            else
                if strcmpi(trigLev, "MAX") || strcmpi(trigLev, "MIN")
                    reply = Set(obj, [], 'RES', 'TRIG', upper(trigLev));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data,mode, reply] = GetTrigLev_CR(obj, varargin)
            %GetTrigLev_CR This command gets the immediate trigger
            %resistance level for CR Mode.
            %   Inputs: 0 to 2 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the current setting for
            %   the current mode
            %   - Inputting one argument ('max' or 'MAX') gets the max
            %   trig resistance setting for the current mode.
            %
            %   - Inputting one argument ('min' or 'MIN') gets the min
            %   trig resistance setting for the current mode.
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'RES', 'TRIG', []);
                data = str2double(data);
                mode = GetMode(obj);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'RES', 'TRIG',...
                        upper(varargin{1}));
                    mode = GetMode(obj);
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            elseif nargin == 3
                dataTemp = GetTrigLev_CR(obj);
                
                % If the second optional argument is CCL or CCH, use that
                % to provide the result
                if strcmpi(varargin{2},"CRL")||strcmpi(varargin{2},"CRM")...
                        ||strcmpi(varargin{2},"CRH")
                    SetMode(obj, upper(varargin{2}));
                    [data, reply] = Get(obj, [], 'RES', 'TRIG',...
                        upper(varargin{1}));
                    mode = upper(varargin{2});
                    data = str2double(data);
                else
                    errMessage = "Invalid Specifier. Try using 'CRL'"+...
                        "'CRM' or 'CRH' or leaving it blank.";
                    error(errMessage);
                end
                
                SetTrigLev_CR(obj, dataTemp);
            else
                errMessage = ['Too many arguments entered. Only 0 to 2'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        %% Constant Power Section
        
        function reply = SetLev_CP(obj, cpLev, mode)
            %SetLev_CP This command sets the immediate power level for CP
            %Mode.
            %   INPUT [ccVal] : Decimal Value (0 ~ 80V)
            %                   or char array ('MAX' or 'MIN')
            %   Function changes the mode (CCL or CCH) based on the
            %   decimal ccVal provided.
            %
            %   Inputting 'MAX' sets the value to 80V.
            %   Inputting 'MIN' sets  the value to 0V.
            
            if nargin < 3
                errMessage = ['Please enter the following arguments:'...
                    newline 'cpLev - Constant Power Level (0 ~ 400W)'...
                    newline 'mode - Mode. "CPV" or "CPC"'];
                error(errMessage);
            end
            
            SetMode(obj, mode);
            if isa(cpLev, 'double')
                reply = Set(obj, [], [], 'POW', upper(cpLev));
            else
                if strcmpi(cpLev, "MAX") || strcmpi(cpLev, "MIN")
                    reply = Set(obj, [], [], 'POW', upper(cpLev));
                else
                    errMessage = ['Invalid argument. Argument can' ...
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
            
        end
        
        function [data,mode, reply] = GetLev_CP(obj, varargin)
            %GetLev_CP This command gets the immediate power level for CP
            %Mode.
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the power setting for
            %   the current mode
            %   - Inputting one argument ('max' or 'MAX') gets the max
            %   power setting for the current mode.
            %
            %   - Inputting one argument ('min' or 'MIN') gets the min
            %   power setting for the current mode.
            
            if nargin == 1
                [data, reply] = Get(obj, [], [],'POW', []);
                data = str2double(data);
                mode = GetMode(obj);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], [],'POW',...
                        upper(varargin{1}));
                    mode = GetMode(obj);
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            elseif nargin == 3
                % If the second optional argument is CCL or CCH, use that
                % to provide the result
                if strcmpi(varargin{2},"CPV")||strcmpi(varargin{2},"CPC")
                    SetMode(obj, upper(varargin{2}));
                    [data, reply] = Get(obj, [], [],'POW',...
                        upper(varargin{1}));
                    mode = upper(varargin{2});
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "CPV" '...
                        'or "CPC" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 2'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetTrigLev_CP(obj, trigLev, mode)
            %SetTrigLev_CP Sets the triggered power level.
            
            SetMode(obj, mode);
            if isa(trigLev, 'double')
                reply = Set(obj, [], 'POW', 'TRIG', upper(trigLev));
            else
                if strcmpi(trigLev, "MAX") || strcmpi(trigLev, "MIN")
                    reply = Set(obj, [], 'POW', 'TRIG', upper(trigLev));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data,mode, reply] = GetTrigLev_CP(obj, varargin)
            %GetTrigLev_CP This command gets the immediate trigger power
            %level for CP Mode.
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the current setting for
            %   the current mode
            %   - Inputting one argument ('max' or 'MAX') gets the max
            %   trig power setting for the current mode.
            %
            %   - Inputting one argument ('min' or 'MIN') gets the min
            %   trig power setting for the current mode.
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'POW', 'TRIG', []);
                data = str2double(data);
                mode = GetMode(obj);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'POW', 'TRIG',...
                        upper(varargin{1}));
                    mode = GetMode(obj);
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            elseif nargin == 3
                modeTemp = GetMode(obj);
                
                % If the second optional argument is CCL or CCH, use that
                % to provide the result
                if strcmpi(varargin{2},"CPV")||strcmpi(varargin{2},"CPC")
                    SetMode(obj, upper(varargin{2}));
                    [data, reply] = Get(obj, [], 'POW', 'TRIG',...
                        upper(varargin{1}));
                    mode = upper(varargin{2});
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "CPV" '...
                        'or "CPC" or leaving it blank.'];
                    error(errMessage);
                end
                
                SetMode(obj, modeTemp);
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        %% List Subsystem Section
        
        %% Transient Subsystem Section
        
        function reply = SetTranMode(obj, mode)
            %SetTranMode Sets the operating mode for transient operation
            %   The modes supported are as follows:
            %
            %   CONT - Continuous Transient Mode - Load periodically
            %          switches between high/low levels, and this
            %          operation is not affected by the trigger signal.
            %
            %   PULS - Pulsed Transient Mode - Before trigger occurs,
            %          the load remains at the transient low level.
            %          After a trigger occurs, a pulse with three stages,
            %          namely rising edge, transient high level, and
            %          falling edge, will appear, then the load returns to
            %          the transient low level again.
            %
            %   TOGG - Toggled Transient Mode - Before trigger occurs,
            %          the load remains at the transient low level.
            %          When a trigger occurs, there is a switch to the high
            %          level with rising edge rate and when another
            %          trigger occurs, the load returns to
            %          the transient low level again.
            
            reply = Set(obj,[],'TRAN', 'MODE', mode);
        end
        
        function [data, reply] = GetTranMode(obj)
            %GetTranMode Gets the operating mode for transient operation
            %   The modes supported are as follows:
            %
            %   CONT - Continuous Transient Mode - Load periodically
            %          switches between high/low levels, and this
            %          operation is not affected by the trigger signal.
            %
            %   PULS - Pulsed Transient Mode - Before trigger occurs,
            %          the load remains at the transient low level.
            %          After a trigger occurs, a pulse with three stages,
            %          namely rising edge, transient high level, and
            %          falling edge, will appear, then the load returns to
            %          the transient low level again.
            %
            %   TOGG - Toggled Transient Mode - Before trigger occurs,
            %          the load remains at the transient low level.
            %          When a trigger occurs, there is a switch to the high
            %          level with rising edge rate and when another
            %          trigger occurs, the load returns to
            %          the transient low level again.
            
            [data, reply] = Get(obj,[], 'TRAN', 'MODE', []);
            
        end % End of GetTranMode
        
        function reply = SetTranState(obj, state)
            %SetTranState Sets the state of the transient operation
            %   INPUT [state]: Can either be 'ON' or 'OFF'
            
            if strcmpi(state, "ON")
                reply = EnTranState(obj);
            elseif strcmpi(state, "OFF")
                reply = DisTranState(obj);
            else
                error("Invalid Entry. Please try 'ON' or 'OFF'");
            end
        end
        
        function reply = EnTranState(obj)
            %EnTranState Enables the transient state of operation
            %
            %   Equivalent of [SetTranState(obj, 'ON')]
            
            check = GetMode(obj);
            
            if strcmpi(check, "CPV") || strcmpi(check, "CPC")
                error("ELoad cannot function in transient mode" + ...
                    "while in CPV or CPC modes. Change to CR, CC or CV modes");
            else
                reply = Set(obj,[],[], 'TRAN', 'ON');
            end
        end
        
        function reply = DisTranState(obj)
            %DisTranState Disables the transient state of operation
            %
            %   Equivalent of [SetTranState(obj, 'OFF')]
            
            reply = Set(obj,[],[], 'TRAN', 'OFF');
        end
        
        function [data, reply] = GetTranState(obj)
            %GetTranState Gets the current state of the transient operation
            [data, reply] = Get(obj,[], [], 'TRAN', []);
            data = str2double(data);
            if data == 0
                data = "OFF";
            else
                data = "ON";
            end
        end
        
        function reply = SetTranLTim(obj, time)
            %SetTranLTim Sets the duration that current is in the *LOW*
            %level for in continuous transient operation. This command is
            %invalid for pulsed and toggled transient operation.
            %
            %   Unit: millisecond (ms)
            %
            %   INPUT [time] : Decimal Value (0.00s ~ 655.35ms)
            %                   or char array ('MAX' or 'MIN')
            %
            %   Inputting 'MAX' sets 655.35ms (Array 3721A) as the value.
            %   Inputting 'MIN' sets 0.00ms (Array 3721A) as the value.
            
            if isa(time, 'double')
                time = time/1000; % Convert ms to obj.SerialObj
                reply = Set(obj, [], 'TRAN','LTIM', upper(time));
            else
                if strcmpi(time, "MAX") || strcmpi(time, "MIN")
                    reply = Set(obj, [], 'TRAN','LTIM', upper(time));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data, reply] = GetTranLTim(obj, varargin)
            %GetTranLTim Gets the duration that current is in the *LOW*
            %level for in continuous transient operation.
            %
            %   Unit: millisecond (ms)
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the Transient low Level
            %   duration setting
            %
            %   - Inputting 'max' or 'MAX' gets the max Transient low Level
            %   duration setting the current mode.
            %
            %   - Inputting 'min' or 'MIN' gets the min Transient low Level
            %   duration setting
            
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'TRAN','LTIM', []);
                data = str2double(data)* 1000; % Convert obj.SerialObj to ms;
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'TRAN','LTIM',...
                        upper(varargin{1}));
                    data = str2double(data)* 1000; % Convert obj.SerialObj to ms
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetTranHTim(obj, time)
            %SetTranHTim Sets the duration that current is in the *HIGH*
            %level for in continuous transient operation. This command is
            %invalid for pulsed and toggled transient operation.
            %
            %   Unit: millisecond (ms)
            %
            %   INPUT [time] : Decimal Value (0.00s ~ 655.35ms)
            %                   or char array ('MAX' or 'MIN')
            %
            %   Inputting 'MAX' sets 655.35ms (Array 3721A) as the value.
            %   Inputting 'MIN' sets 0.00ms (Array 3721A) as the value.
            
            if isa(time, 'double')
                time = time/1000; % Convert ms to obj.SerialObj
                reply = Set(obj, [], 'TRAN','HTIM', upper(time));
            else
                if strcmpi(time, "MAX") || strcmpi(time, "MIN")
                    reply = Set(obj, [], 'TRAN','HTIM', upper(time));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data, reply] = GetTranHTim(obj, varargin)
            %GetTranHTim Sets the duration that current is in the *HIGH*
            %level for in continuous transient operation.
            %
            %   Unit: millisecond (ms)
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the Transient low Level
            %   duration setting
            %
            %   - Inputting 'max' or 'MAX' gets the max Transient low Level
            %   duration setting the current mode.
            %
            %   - Inputting 'min' or 'MIN' gets the min Transient low Level
            %   duration setting
            
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'TRAN','HTIM', []);
                data = str2double(data)* 1000; % Convert obj.SerialObj to ms;
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'TRAN','HTIM',...
                        upper(varargin{1}));
                    data = str2double(data)* 1000; % Convert obj.SerialObj to ms
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetTranRTim(obj, time)
            %SetTranRTim Sets the duration that current is *RISING*
            %for in continuous transient operation, pulsed and toggled
            %transient operation.
            %
            %   Unit: millisecond (ms)
            %
            %   INPUT [time] : Decimal Value (0.01ms ~ 655.35ms)
            %                   or char array ('MAX' or 'MIN')
            %
            %   Inputting 'MAX' sets 655.35ms (Array 3721A) as the value.
            %   Inputting 'MIN' sets 0.00ms (Array 3721A) as the value.
            
            
            if isa(time, 'double')
                time = time/1000; % Convert ms to obj.SerialObj
                reply = Set(obj, [], 'TRAN','RTIM', upper(time));
            else
                if strcmpi(time, "MAX") || strcmpi(time, "MIN")
                    reply = Set(obj, [], 'TRAN','RTIM', upper(time));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data, reply] = GetTranRTim(obj, varargin)
            %GetTranRTim Sets the duration that current is *RISING*
            %for in continuous transient operation, pulsed and toggled
            %transient operation.
            %
            %   Unit: millisecond (ms)
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the Transient low Level
            %   duration setting
            %
            %   - Inputting 'max' or 'MAX' gets the max Transient low Level
            %   duration setting the current mode.
            %
            %   - Inputting 'min' or 'MIN' gets the min Transient low Level
            %   duration setting
            
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'TRAN','RTIM', []);
                data = str2double(data)* 1000; % Convert obj.SerialObj to ms;
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'TRAN','RTIM',...
                        upper(varargin{1}));
                    data = str2double(data)* 1000; % Convert obj.SerialObj to ms
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetTranFTim(obj, time)
            %SetTranFTim Sets the duration that current is *FALLING*
            %for in continuous transient operation, pulsed and toggled
            %transient operation.
            %
            %   Unit: millisecond (ms)
            %
            %   INPUT [time] : Decimal Value (0.01ms ~ 655.35ms)
            %                   or char array ('MAX' or 'MIN')
            %
            %   Inputting 'MAX' sets 655.35ms (Array 3721A) as the value.
            %   Inputting 'MIN' sets 0.00ms (Array 3721A) as the value.
            
            
            if isa(time, 'double')
                time = time/1000; % Convert ms to obj.SerialObj
                reply = Set(obj, [], 'TRAN','FTIM', upper(time));
            else
                if strcmpi(time, "MAX") || strcmpi(time, "MIN")
                    reply = Set(obj, [], 'TRAN','FTIM', upper(time));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data, reply] = GetTranFTim(obj, varargin)
            %GetTranFTim Sets the duration that current is *FALLING*
            %for in continuous transient operation, pulsed and toggled
            %transient operation.
            %
            %   Unit: millisecond (ms)
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the Transient low Level
            %   duration setting
            %
            %   - Inputting 'max' or 'MAX' gets the max Transient low Level
            %   duration setting the current mode.
            %
            %   - Inputting 'min' or 'MIN' gets the min Transient low Level
            %   duration setting
            
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'TRAN','FTIM', []);
                data = str2double(data)* 1000; % Convert obj.SerialObj to ms;
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'TRAN','FTIM',...
                        upper(varargin{1}));
                    data = str2double(data)* 1000; % Convert S to ms
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        %% Battery Subsystem Section
        
        function reply = SetBattState(obj, state)
            %SetBattState Sets the state of the battery discharge operation
            %   INPUT [state]: Can either be 'ON' or 'OFF'
            
            if strcmpi(state, "ON")
                reply = EnBattDisc(obj);
            elseif strcmpi(state, "OFF")
                reply = DisBattDisc(obj);
            else
                error("Invalid Entry. Please try 'ON' or 'OFF'");
            end
        end
        
        function reply = EnBattDisc(obj)
            %EnBattDisc Enables the battery discharge state of operation
            %
            %   Equivalent of [SetBattState(obj, 'ON')]
            
            reply = Set(obj,[],[], 'BATT', 'ON');
        end
        
        function reply = DisBattDisc(obj)
            %DisBattDisc Disables the battery discharge state of operation
            %
            %   Equivalent of [SetBattState(obj, 'OFF')]
            
            reply = Set(obj,[],[], 'BATT', 'OFF');
        end
        
        function [data, reply] = GetBattState(obj)
            %GetBattState Gets the current state of the battery discharge
            %operation
            
            [data, reply] = Get(obj,[], [], 'BATT', []);
            data = str2double(data);
            if data == 0
                data = "OFF";
            else
                data = "ON";
            end
        end
        
        function reply = SetBattTermVolt(obj, volt)
            %SetBattTermVolt Sets the termination voltage level at which
            %battery dischage should halt.
            %
            %   INPUT [volt] : Decimal Value (0.00V ~ 80V)
            %                   or char array ('MAX' or 'MIN').
            %
            %   Inputting 'MAX' sets 80.00V (Array 3721A) as the value.
            %   Inputting 'MIN' sets 0.00V (Array 3721A) as the value.
            
            if isa(volt, 'double')
                reply = Set(obj, 'BATT', 'TERM','VOLT', upper(volt));
            else
                if strcmpi(volt, "MAX") || strcmpi(volt, "MIN")
                    reply = Set(obj, 'BATT', 'TERM','VOLT', upper(volt));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data, reply] = GetBattTermVolt(obj, varargin)
            %GetBattTermVolt Gets the termination voltage level at which
            %battery dischage should halt.
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the current setting and
            %   current mode
            %   - Inputting 'max' or 'MAX' gets the max termination voltage
            %   level setting.
            %
            %   - Inputting 'min' or 'MIN' gets the min termination voltage
            %   level setting.
            
            if nargin == 1
                [data, reply] = Get(obj, 'BATT', 'TERM','VOLT', []);
                data = str2double(data);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, 'BATT', 'TERM','VOLT',...
                        upper(varargin{1}));
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = SetBattDiscCurr(obj, curr)
            %SetBattDiscCurr Sets the discharge current level at which
            %battery dischages.
            %
            %   INPUT [curr] : Decimal Value (0.00A ~ 40.00A)
            %                   or char array ('MAX' or 'MIN').
            %
            %   Inputting 'MAX' sets 40.00A (Array 3721A) as the value.
            %   Inputting 'MIN' sets 0.000A (Array 3721A) as the value.
            
            if isa(curr, 'double')
                reply = Set(obj, [], 'BATT','CURR', upper(curr));
            else
                if strcmpi(curr, "MAX") || strcmpi(curr, "MIN")
                    reply = Set(obj, [], 'BATT','CURR', upper(curr));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data, reply] = GetBattDiscCurr(obj, varargin)
            %GetBattDiscCurr Gets the discharge current level at which
            %battery dischages.
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the current setting and
            %   current mode
            %   - Inputting 'max' or 'MAX' gets the max discharge current
            %   level setting.
            %
            %   - Inputting 'min' or 'MIN' gets the min discharge current
            %   level setting.
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'BATT','CURR', []);
                data = str2double(data);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, [], 'BATT','CURR',...
                        upper(varargin{1}));
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function [data, reply] = GetBattDiscTime(obj)
            %GetBattDiscTime Gets the total time the battery has been
            %discharging for.
            %
            %   Date format: Hour:Minute:Second
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'BATT','TIME', []);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        function [data, reply] = GetBattDiscCap(obj)
            %GetBattDiscCap Gets the total capacity that has discharged
            %from the battery.
            %
            %   Units in Ah.
            %
            %   Maximum allowed capacity for the 3721A Eload is 4000Ah
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'BATT','CAP', []);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        function reply = ClearBattProp(obj)
            %ClearBattProp Clears the  battery setting properties. Specifically the discharge time and discharge capacity.
            
            if nargin == 1
                reply = Set(obj, 'BATT', 'CAP','CLE', []);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        %% Input Subsystem Section
        
        function reply = SetInputState(obj, state)
            %SetInputState Sets the state of the ELoad Terminals
            %   INPUT [state]: Can either be 'ON' or 'OFF'
            
            if strcmpi(state, "ON")
                reply = Connect(obj);
            elseif strcmpi(state, "OFF")
                reply = Disconnect(obj);
            else
                error("Invalid Entry. Please try 'ON' or 'OFF'");
            end
        end
        
        function reply = Connect(obj)
            %Connect Enables/Connects the ELoad Terminals to the source
            %
            %   Equivalent of [SetInputState(obj, 'ON')]
            
            reply = Set(obj,[],[], 'INP', 'ON');
            obj.Connected = true;
        end
        
        function reply = Disconnect(obj)
            %Disconnect Disables/Disconnects the ELoad Terminals from the source
            %
            %   Equivalent of [SetInputState(obj, 'OFF')]
            
            reply = Set(obj,[],[], 'INP', 'OFF');
            obj.Connected = false;
        end
        
        function [data, reply] = GetInputState(obj)
            %GetInputState Gets the current state of the ELoad Terminals
            
            [data, reply] = Get(obj,[], [], 'INP', []);
            data = str2double(data);
            if data == 0
                data = "OFF";
            else
                data = "ON";
            end
        end
        
        function [data, reply] = IsConnected(obj)
            %GetInputState Gets the current state of the ELoad Terminals
            
            [data, reply] = Get(obj,[], [], 'INP', []);
            data = str2double(data);
            if data == 0
                data = false;
            elseif data == 1
                data = true;
            end
        end
        
        function reply = SetShortState(obj, state)
            %SetShortState Enables or disables short-circuit operation
            %   INPUT [state]: Can either be 'ON' or 'OFF'
            
            if strcmpi(state, "ON")
                reply = EnShortCir(obj);
            elseif strcmpi(state, "OFF")
                reply = DisShortCir(obj);
            else
                error("Invalid Entry. Please try 'ON' or 'OFF'");
            end
        end
        
        function reply = EnShortCir(obj)
            %EnShortCir Enables the short-circuit operation
            %
            %   Equivalent of [SetShortState(obj, 'ON')]
            
            reply = Set(obj,[],'INP', 'SHOR', 'ON');
        end
        
        function reply = DisShortCir(obj)
            %DisShortCir Disables the short-circuit operation
            %
            %   Equivalent of [SetShortState(obj, 'OFF')]
            
            reply = Set(obj,[],'INP', 'SHOR', 'OFF');
        end
        
        function [data, reply] = GetShortState(obj)
            %GetShortState Gets the current state of the Short Circuit
            %Operation
            
            [data, reply] = Get(obj,[], 'INP', 'SHOR', []);
            data = str2double(data);
            if data == 0
                data = "OFF";
            else
                data = "ON";
            end
        end
        
        function reply = SetLatchState(obj, state)
            %SetLatchState Enables or disables the Von Latch function
            %   INPUT [state]: Can either be 'ON' or 'OFF'
            %
            %   Von Latch latches the active status of the load. If the
            %   Von Latch function is disabled and the load receives the
            %   command of turning on the input, once the input voltage
            %   reaches the Von Point, the load starts to work
            %   automatically?and once the input voltage is lower than
            %   the Von Point, the load is turned off automatically. If
            %   the Von Latch function is enabled, once the input voltage
            %   reaches Von Point, the load starts to work and will keep
            %   working no matter how the input voltage changes, even
            %   though the input voltage is less than the Von Point.
            
            if strcmpi(state, "ON")
                reply = EnLatch(obj);
            elseif strcmpi(state, "OFF")
                reply = DisLatch(obj);
            else
                error("Invalid Entry. Please try 'ON' or 'OFF'");
            end
        end
        
        function reply = EnLatch(obj)
            %EnLatch Enables the Von Latch function
            %
            %   Equivalent of [SetLatchState(obj, 'ON')]
            
            reply = Set(obj,[],'INP', 'LATC', 'ON');
        end
        
        function reply = DisLatch(obj)
            %DisLatch Disables the Von Latch function
            %
            %   Equivalent of [SetLatchState(obj, 'OFF')]
            
            reply = Set(obj,[],'INP', 'LATC', 'OFF');
        end
        
        function [data, reply] = GetLatchState(obj)
            %GetLatchState Gets the current state of the Von Latch function
            
            [data, reply] = Get(obj,[], 'INP', 'LATC', []);
            data = str2double(data);
            if data == 0
                data = "OFF";
            else
                data = "ON";
            end
        end
        
        function reply = SetLatchVolt(obj, volt)
            %SetLatchVolt Sets the Von Point volt level where
            %the von latch functions
            %
            %   INPUT [volt] : Decimal Value (0.00V ~ 80.00V)
            %                   or char array ('MAX' or 'MIN').
            %
            %   Inputting 'MAX' sets 80.00V (Array 3721A) as the value.
            %   Inputting 'MIN' sets 0.000V(Array 3721A) as the value.
            
            if isa(volt, 'double')
                reply = Set(obj, 'INP', 'LATC','VOLT', upper(volt));
            else
                if strcmpi(volt, "MAX") || strcmpi(volt, "MIN")
                    reply = Set(obj, 'INP', 'LATC','VOLT', upper(volt));
                else
                    errMessage = ['Invalid argument. Argument can ...'
                        'either be of type double or "MAX" or "MIN" '];
                    error(errMessage);
                end
            end
        end
        
        function [data, reply] = GetLatchVolt(obj, varargin)
            %GetLatchVolt Gets the Von Point volt level where
            %the von latch functions
            %
            %   Inputs: 0 to 1 input besides the ELoad object is allowed.
            %   - Leaving the inputs blank gets the current setting and
            %   current mode
            %   - Inputting 'max' or 'MAX' gets the max Von Point voltage
            %   level setting.
            %
            %   - Inputting 'min' or 'MIN' gets the min Von Point voltage
            %   level setting.
            
            if nargin == 1
                [data, reply] = Get(obj, 'INP', 'LATC','VOLT', []);
                data = str2double(data);
            elseif nargin == 2
                if strcmpi(varargin{1}, "MAX")||strcmpi(varargin{1}, "MIN")
                    [data, reply] = Get(obj, 'INP', 'LATC','VOLT',...
                        upper(varargin{1}));
                    data = str2double(data);
                else
                    errMessage = ['Invalid Specifier. Try using "MAX" '...
                        'or "MIN" or leaving it blank.'];
                    error(errMessage);
                end
            else
                errMessage = ['Too many arguments entered. Only 0 to 1'...
                    'arguments are allowed. '];
                error(errMessage);
            end
        end
        
        function reply = ClearInputProt(obj)
            %ClearInputProt Clears the the protection status for the
            %electronic load: OC, OV, OP, OT and RV.
            
            if nargin == 1
                reply = Set(obj, 'INP', 'PROT','CLE', []);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        %% Measure Section
        
        function [data, reply] = MeasureCurr(obj)
            %MeasureCurr Gets the measured value of input current.
            %i.e Current at the terminals
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'MEAS','CURR', []);
                data = str2double(data);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        function [data, reply] = MeasureVolt(obj)
            %MeasureVolt Gets the measured value of input voltage.
            %i.e Voltage at the terminals
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'MEAS','VOLT', []);
                data = str2double(data);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        function [data, reply] = MeasureRes(obj)
            %MeasureRes Gets the measured value of input resistance.
            %i.e Resistance at the terminals
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'MEAS','RES', []);
                data = str2double(data);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        function [data, reply] = MeasurePow(obj)
            %MeasurePow Gets the measured value of input power.
            %i.e Power at the terminals
            
            if nargin == 1
                [data, reply] = Get(obj, [], 'MEAS','POW', []);
                data = str2double(data);
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        function [data, reply] = MeasureVoltCurr(obj)
            %MeasureVoltCurr Gets the measured Voltage and current.
            %i.e Voltage and Current at the terminals
            
            if nargin == 1
                command = upper('MEAS:VOLT?;CURR?');
                fprintf(obj.SerialObj, command);
                data = fgetl(obj.SerialObj);
                data = data(1:numel(data)-1);
                data = strcat("", data);
                tempData = strsplit(data,';');
                data = str2double(tempData);
                
                % Check for Errors
                fprintf(obj.SerialObj, 'SYST:ERR?');
                dataStr = fgetl(obj.SerialObj);
                dataStr = strcat("", dataStr);
                
                if dataStr == "+0 No error"
                    reply = "Success";
                else
                    reply = strcat("Failed: ", dataStr);
                end
            else
                error("Too many entries. No arguments are allowed.");
            end
        end
        
        %% Trigger Subsystem Section
        
        function reply = Trig(obj)
            %Trig Sets an immediate trigger signal for any trigger
            %source
            
            reply = Set(obj, [], [], 'TRIG', []);
        end
        
        function reply = SetTrigSource(obj, source)
            %SetTrigSource Sets the trigger source.
            %
            %   INPUT[source]: There are 3 options for source:
            %       - 'BUS'  - The trigger source is GPIB <GET> signal,
            %                   or *TRG command.
            %   	- 'EXT'  - External Source (Physical BNC
            %                   connector on the machine.
            %   	- 'HOLD' - Only TRIGger[:IMMediate] command can work
            %                   as the trigger source. All other trigger
            %                   methods including *TRG and GPIB<GET> are
            %                   invalid.
            
            reply = Set(obj, [], 'TRIG', 'SOUR', upper(source));
        end
        
        function [data, reply] = GetTrigSource(obj)
            %GetTrigSource Gets the current trigger source.
            %
            %   INPUT[source]: There are 3 options for source:
            %       - 'BUS'  - The trigger source is GPIB <GET> signal,
            %                   or *TRG command.
            %   	- 'EXT'  - External Source (Physical BNC
            %                   connector on the machine.
            %   	- 'HOLD' - Only TRIGger[:IMMediate] command can work
            %                   as the trigger source. All other trigger
            %                   methods including *TRG and GPIB<GET> are
            %                   invalid.
            
            [data, reply] = Get(obj, [], 'TRIG', 'SOUR', []);
        end
        
        function reply = SetTrigFunc(obj, func)
            %SetTrigFunc Sets the trigger object between List and Tran.
            %
            %   INPUT[func]: There are 2 options for func:
            %       - 'LIST'  - List object
            %   	- 'TRAN'  - Transient object
            
            reply = Set(obj, [], 'TRIG', 'FUNC', upper(func));
        end
        
        function [data, reply] = GetTrigFunc(obj)
            %GetTrigFunc Gets the current trigger function.
            %
            %   INPUT[func]: There are 2 options for func:
            %       - 'LIST'  - List object
            %   	- 'TRAN'  - Transient object
            
            [data, reply] = Get(obj, [], 'TRIG', 'FUNC', []);
        end
        
        function reply = InitTrigOnce(obj)
            %InitTrigOnce This command initializes a trigger operation.
            %Trigger system initialization must be conducted before sending a
            %trigger signal
            
            reply = Set(obj, [], [], 'INIT', []);
        end
        
        function reply = SetContTrigInitState(obj, state)
            %SetContTrigInitState This command turns on/off the continuous
            %initialization function. If this function is enabled, the
            %subsequent trigger operations do not need to initialize the
            %trigger system.
            %   INPUT [state]: Can either be 'ON' or 'OFF'
            
            if strcmpi(state, "ON")
                reply = EnContTrigInit(obj);
            elseif strcmpi(state, "OFF")
                reply = DisContTrigInit(obj);
            else
                error("Invalid Entry. Please try 'ON' or 'OFF'");
            end
        end
        
        function reply = EnContTrigInit(obj)
            %EnContTrigInit Enables the continous trigger initialization
            %function, so that many triggers can be made right after each
            %other without needing to initialize every time.
            %
            %   Equivalent of [SetContTrigInitState(obj, 'ON')]
            
            reply = Set(obj,[],'INIT', 'CONT', 'ON');
        end
        
        function reply = DisContTrigInit(obj)
            %DisContTrigInit Disables the continous trigger initialization
            %function
            %
            %   Equivalent of [SetContTrigInitState(obj, 'OFF')]
            
            reply = Set(obj,[],'INIT', 'CONT', 'OFF');
        end
        
        function [data, reply] = GetContTrigInitState(obj)
            %GetContTrigInitState Gets the current state of the continous
            %trigger initialization function
            
            [data, reply] = Get(obj,[], 'INIT', 'CONT', []);
            data = str2double(data);
            if data == 0
                data = "OFF";
            else
                data = "ON";
            end
        end
        
        %% Status Subsystem Section
        
        function [ID, reply] = WhoAmI(obj)
            reply = "";
            
            writeline(obj.SerialObj, '*IDN?');
            
            % Wait until a variable is available
            tempTimer = tic;
            while obj.SerialObj.NumBytesAvailable == 0
                if(toc(tempTimer) > obj.timeout)
                    reply = "TimeOut";
                    break;
                end
            end
            
            data = "";
            while obj.SerialObj.NumBytesAvailable ~= 0
                data = data + readline(obj.SerialObj);
            end
            data = extractBefore(data, strlength(data));
            ID = data;
        end
        
        function [alarmState, alarm]  = getAlarmCode(obj)
           % Check for Errors
            writeline(obj.SerialObj, 'SYST:ERR?');
            
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
            dataStr = extractBefore(dataStr, strlength(dataStr));

            alarmState = true;
            
            if dataStr == "+0 No error"
                alarm = "Success";
                alarmState = false;
            else
                alarm = strcat("Failed: ", dataStr);
            end 
        end
        
        function reply = ClearAlarmCode(obj)
            writeline(obj.SerialObj, '*CLS');
            
            wait(0.003);
            [alarmState, alarm] = getAlarmCode(obj);
            if alarmState == false
                reply = "Alarm Cleared";
            else
                reply = "Alarm Remains: " + alarm;
            end
        end
        
    end %End of METHODS (Public)
    
    
end