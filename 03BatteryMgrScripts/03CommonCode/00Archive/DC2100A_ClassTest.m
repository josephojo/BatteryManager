classdef myclassTest < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        prop = 0;
        serial
        baudRate
        port
        byteOrder
        terminator
        stopbits
        f  = parallel.FevalFuture;
        tim
        buf_in = javaObject('java.util.LinkedList'); % Buffer for accumulating responses from USB
        buf_dropped = ''; 
        errLog
        
        Stack_Summary_Data = struct...
            (...
            'Num_Cells' , 0, ...
            'Volt_Sum' , 0, ...
            'Volt_Average' , 0, ...
            'Volt_Max' , 0, ...
            'Volt_Min' , 0, ...
            'Temp_Max' , 0, ...
            'Temp_Min' , 0, ...
            'Volt_Max_Cell' , 0, ...
            'Volt_Min_Cell' , 0, ...
            'Temp_Max_Cell' , 0, ...
            'Temp_Min_Cell' , 0  ...
            );
        
        USB_Parser_Response_DataLengths = containers.Map;
        USB_Parser_Buffer_Dropped = "";
    end
    
    methods
        function obj = myclassTest(COMport, app)
            %UNTITLED2 Construct an instance of this class
            %   Detailed explanation goes here
%             obj.baudRate = 115200;
%             obj.port = COMport;
%             obj.byteOrder = "big-endian";
%             obj.terminator = "LF";
%             obj.stopbits = 1;
%             
%             obj.Stack_Summary_Data.Num_Cells = 10;
%             
            obj.errLog = app;
% %             p = gcp;
% %             [ val, data, status] = obj.readData('H', 6)
%             obj.serial = serialport(obj.port, obj.baudRate);
%             obj.serial.ByteOrder = obj.byteOrder;
%             flush(obj.serial); % Remove any random data in the serial buffer
%             
%             configureCallback(obj.serial, "terminator" ,@obj.USBDataIn_Callback)
%             x = 1;
%             obj.tim = timer;
% %             obj.tim.ExecutionMode = 'fixedRate';
%             obj.tim.Period = 1; %DC2100A.USB_COMM_TIMER_INTERVAL;
%             obj.tim.StartDelay = 2;
%             obj.tim.StopFcn = @obj.timerStopped;
%             obj.tim.TimerFcn = @obj.sendCmd;
%             obj.tim.ErrorFcn = {@obj.Handle_Exception, []};
% 
%             start(obj.tim);
            setUSBDataSizes(obj);
        end
        
        function chgProp(obj,val)
%              obj.prop = val;
             val.remove()
            val.remove()
        end
        
        function obj = chgProp2(obj,val)
            
%             obj.prop = val;
        end
        
        
        function setUSBDataSizes(obj)
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_MFG_COMMAND)...
                = 1 + (1 * 2) + strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT) ...
                + 1 + strlength(DC2100A.DC2100A_SERIAL_NUM_DEFAULT) ...
                + (4 * 2 * 2) + strlength(DC2100A.APP_FW_STRING_DEFAULT);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_SYSTEM_COMMAND)...
                = 1 + (1 * 2) + (DC2100A.LTC6804_MAX_BOARDS * 1 * 2) + (2 * 2) ...
                + (2 * 2) + (1 * 2);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_VOLTAGE_COMMAND)...
                = 1 + (1 * 2) + (4 * 2) ...
                + (DC2100A.MAX_CELLS * 2 * 2) + (1 * 2);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_TEMPERATURE_COMMAND)...
                = 1 + (1 * 2) + (4 * 2) ...
                + (DC2100A.MAX_CELLS * 2 * 2) + (1 * 2);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_TEMP_ADC_COMMAND) ...
                = 1 + (1 * 2) + (DC2100A.MAX_CELLS * 2 * 2);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_PASSIVE_BALANCE_COMMAND)...
                = 1 + (1 * 2) + (2 * 2);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_CELL_PRESENT_COMMAND) ...
                = 1 + (1 * 2) + (2 * 2);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_TIMED_BALANCE_COMMAND)...
                = 1 + (1 * 2) + (DC2100A.MAX_CELLS * 2 * 2) + (2 * (2 + 1) * 2);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_UVOV_COMMAND) ...
                = 1 + (1 * 2) + (2 * 3);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_ERROR_COMMAND) ...
                = 1 + (1 * 2) + (2 * DC2100A.ERROR_DATA_SIZE);
            
            % These commands are variable length
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_LTC3300_COMMAND) ...
                = 1 + (1 * 2) + 1 + (1 * 2);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_EEPROM_COMMAND) ...
                = 1 + (1 * 2) + 1;
            
            % These are random strings sent out without an identifier) = so don%t make any commands that use the same first letter as these random strings
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_HELLO_COMMAND)...
                = strlength(DC2100A.HELLOSTRING);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_IDSTRING_COMMAND)...
                = strlength(DC2100A.DC2100A_IDSTRING);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_DEFAULT_COMMAND) ...
                = strlength(DC2100A.USB_PARSER_DEFAULT_STRING);
        end
        
        
        function [status, data, val] = readData(obj, cmd, dataLen)
            %readData Synchorously sends commands and receives data.
            %   This function when called blocks the current thread
            %
            %   Inputs:
            %       obj     : Class object
            %       cmd     : Command to request data from DC2100A
            %       dataLen : Length of data to receive for the command in
            %                 bytes
            %
            %   Ouputs:
            %       status : Returns true
            
            
            % Turn USB Callback off so it doesn't activate while receiving
            % data synchronously
%             configureCallback(obj.serial, "off");
%             t = tic;
%             write(obj.serial,cmd,"char");
%             toc(t)
%             disp("HH11")

            
            val = 0;
            tic
            s = serialport(obj.port, obj.baudRate);
            s.ByteOrder = obj.byteOrder;
            flush(s); % Remove any random data in the serial buffer
    
            
            write(s,cmd,"char");
            
            tim1 = toc;
            while(s.NumBytesAvailable < dataLen)
%                 val = s.NumBytesAvailable;
                if (toc - tim1 > DC2100A.READ_TIMEOUT/1000)
                    status = ErrorCode.COMM_TIMEOUT;
                    data = "";
                    return;
                end
            end
            data = read(s, dataLen ,"char");
            status = ErrorCode.NO_ERROR;
            % Turn USB Callback on again
%             configureCallback(obj.serial, "terminator" ,@obj.USBDataIn_Callback)

            clear s;
            val = toc;
        end
        
        
        % The inputs are required by the configureCallback function
        function USBDataIn_Callback(obj, s, ~)
            %USBDataIn_Callback Callback when data available in serial
            %buffer is available
            
            obj.buf_in.add(read(s, s.NumBytesAvailable, "string"));
            
        end
        
        
        function USBDataIn_Parser(obj, new_data)
            %USBDataIn_Parser Parses String data input from serial buffer
            %to workable values
            %   Inputs: 
            %       obj             : 
            %       new_data        : 
            %
            
            % Make sure data is an array of characters and not a string
            if strcmpi(class(new_data), 'string') && length(new_data)>1
                s = strjoin(new_data, '');
                new_data = char(s);
                disp("str length > 1")
            elseif strcmpi(class(new_data), 'string')
                new_data = char(new_data);
                disp("Just String")
            end
            
            % Add new Data to linked list
            DC2100A.ADD_RANGE(obj.buf_in, new_data, 1, length(new_data))
                        
            ind = 1;
            while ind <= length(new_data)
                key = obj.buf_in.peek();
                
                if(isKey(obj.USB_Parser_Response_DataLengths, key))
                    response_length = obj.USB_Parser_Response_DataLengths(key);
                    
                    % if the remaining data in "new_data" equal or more in
                    % length than we expect, then we can take from it
                    % expect
                    if obj.buf_in.size >= response_length
%                         [status, response_length] = USB_Process_Response(obj, response_length);
                        ind = ind + response_length;
                        
%                         % Check the status for errors
%                         if status == ErrorCode.NO_ERROR
%                         elseif status == ErrorCode.USB_PARSER_NOTDONE
%                             obj.errLog.Add(ErrorCode.USB_PARSER_NOTDONE,...
%                                 "Parser could not finish while parsing '" + key + "'");
%                         end
                    else
                        % Or else, store the remaining data so we can use
                        % it next time this function is called.
%                         obj.buf_dropped = new_data(ind : length(new_data));
                        ind = ind + (length(new_data) - ind);
                    end
                else
                    % Save the characters that were dropped, and write them into the Error log at the next good transaction.
                    obj.USB_Parser_Buffer_Dropped = obj.USB_Parser_Buffer_Dropped + obj.buf_in.remove;
                    if strlength(obj.USB_Parser_Buffer_Dropped) > DC2100A.USB_MAX_PACKET_SIZE
                        obj.errLog.Add(ErrorCode.USB_DROPPED, obj.USB_Parser_Buffer_Dropped);
                        obj.USB_Parser_Buffer_Dropped = "";
                    end
                    ind = ind + 1;
                end
                ind
            end
        end
        
 
        function sendCmd(obj, varargin)
            write(obj.serial, 'H'); %, 'char');
        end
        
        function errFcn(obj, varargin)
            timerObj = varargin{1}; 
            MEX = varargin{2}.Data;
            
            mexStr = newline + string(char(9)) + string(MEX.message) + newline;
            mexStr = mexStr + char(9) ...
                + sprintf("Error while evaluating TimerFcn for %s", timerObj.Name);
            mexStr = mexStr + newline + char(9); % char(9) = \tab
            obj.errLog.Add(ErrorCode.EXCEPTION, mexStr);
            MEX
        end
        
        function Handle_Exception(obj, MEX, varargin)
            %Handle_Exception Used to catch and display exceptions on the
            %Error Log app
            %   Inputs:
            %       obj         :
            %       MEX         :
            %       varargin    : 
            %
            MEX
            varargin{:}
            if nargin <= 2
                stk = MEX.stack;
                mexStr = newline + string(char(9)) + string(MEX.message) + newline;
                for i=1:length(stk)
                    mexStr = mexStr + char(9) ...
                        + sprintf("Error in %s (line %d)",...
                        strrep(stk(i).name,'.','/'), stk(i).line);
                    %                 if i ~= length(stk)
                    mexStr = mexStr + newline + char(9); % char(9) = \tab
                    %                 end
                end
                
            else
                timerObj = MEX;
                MEX = varargin{1}.Data;
                
                mexStr = newline + string(char(9)) + string(MEX.message) + newline;
                mexStr = mexStr + char(9) ...
                    + sprintf("Error while evaluating TimerFcn for %s", timerObj.Name);
                mexStr = mexStr + newline + char(9); % char(9) = \tab
            end
            
            obj.errLog.Add(ErrorCode.EXCEPTION, mexStr);
        end
        
        
        
        function timerStopped(obj, varargin)
           disp("Timer Stopped")
%            varargin{:};
        end
        
        function disconnect(obj)
            s = inputname(1);
            stop(obj.tim);
            disp("NumBytesWritten = " + obj.serial.NumBytesWritten)
            disp("NumBytesAvail = " + obj.serial.NumBytesAvailable)
          	delete(obj.tim);
            flush(obj.serial);
            evalin('base', [['clear '], s ,';']);
        end

        
        function [status, data, val] = test2(obj, s, cmd)
           tic;
            val = 0;
            t = tic;
            write(s,cmd,"char");
            toc(t);
            
            tim1 = toc;
            while(s.NumBytesAvailable < 6*length(cmd))
                if (toc - tim1 > DC2100A.READ_TIMEOUT)
                    status = ErrorCode.COMM_TIMEOUT;
                    data = "";
                    return;
                end
            end
            whileTime = toc - tim1
            t2 = tic;
            data = read(s, s.NumBytesAvailable ,"char");
            status = ErrorCode.NO_ERROR;
            val = toc(t2)

        end
        
    end
end

