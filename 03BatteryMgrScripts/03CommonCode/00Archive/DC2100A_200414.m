classdef DC2100A
    %DC2100A class handles control and data recording for the DC2100A
    %12-cell demo balancing board (BAL) from Analog Devices.
    %   This class uses the SPI protocol to send commands and
    %   receive data from the BAL. For successful communication, the device
    %   needs to convert USB to SPI using a MCP2210 converter.
    %
    %Change Log
    %   CHANGE                                      REVISION	DATE-YYMMDD
    
    properties (Constant)
        % *** Debug variables, always have DEBUG set to FALSE for customer software
        DEBUG = false;
        DEBUG_ERRORS = false;
        DEBUG_LED = true;
        
        % *** Generally useful constants
        MS_PER_SEC = 1000;
        MV_PER_V = 1000;
        SEC_PER_MIN = 60;
        MIN_PER_HR = 60;
        SEC_PER_HR = (DC2100A.SEC_PER_MIN * DC2100A.MIN_PER_HR);
        HR_PER_DAY = 24;
        SEC_PER_DAY = (DC2100A.SEC_PER_MIN * DC2100A.MIN_PER_HR * DC2100A.HR_PER_DAY);
        DAY_PER_WK = 7;
        SEC_PER_WK = (DC2100A.SEC_PER_MIN * DC2100A.MIN_PER_HR * DC2100A.HR_PER_DAY * DC2100A.DAY_PER_WK);
        
        % *** Constants to configure DC2100A GUI
        filePath = "";
        PRODUCT_STRING = "DC2100A";
        LTC6804_MAX_BOARDS = 16;                 % The maximum number of addresses available to the LTC6804-2
        LTC6804_BROADCAST = DC2100A.LTC6804_MAX_BOARDS;  % Code for application code to indicate an LTC6804 command is to be broadcast to all boards
        MAX_BOARDS = 10;                         % The maximum number of boards that can be in a DC2100A system (note that LTC6804_MAX_BOARDS <> MAX_BOARDS due to RAM limitations in the PIC)
        MAX_CELLS = 12;
        MIN_CELLS = 4;
        NUM_TEMPS = 12;
        NUM_LTC3300 = 2;
        ALL_BOARDS = DC2100A.MAX_BOARDS;
        ALL_CELLS = DC2100A.MAX_CELLS;
        ALL_ICS = DC2100A.NUM_LTC3300;
        
        % *** DC2100A USB Communication
        
        % Variables to control rate at which commands are sent and responses are received
        USB_COMM_TIMER_INTERVAL = 20;            % in ms
        USB_COMM_CYCLE_PERIOD_DEFAULT = 360;     % in ms
        USB_COMM_TIMER_INTERVALS_PER_BOARD = 5;  % in ms
        
        % Variables to contain responses from before they are parsed
        % USB_Parser_Buffer_In                           % Buffer for accumulating responses from USB
        % USB_Parser_Buffer_Dropped                      % Buffer for accumulating characters dropped from USB
        USB_MAX_PACKET_SIZE = 64;
        
        % Defined USB Commands and Responses
        USB_PARSER_MFG_COMMAND = "O";             % Read/Write Board Manufacturing Data
        USB_PARSER_SYSTEM_COMMAND = "s";          % Read System Data
        USB_PARSER_VOLTAGE_COMMAND = "v";         % Read Board Voltage Data
        USB_PARSER_TEMPERATURE_COMMAND = "t";     % Read Board Temperature Data
        USB_PARSER_TEMP_ADC_COMMAND = "l";        % Read Board Temperature Adc Values
        USB_PARSER_PASSIVE_BALANCE_COMMAND = "M"; % Board Passive Balancers
        USB_PARSER_CELL_PRESENT_COMMAND = "n";    % Board Cell Present
        USB_PARSER_TIMED_BALANCE_COMMAND = "m";   % Board Timed Balance
        USB_PARSER_UVOV_COMMAND = "V";            % Read Board Over-Voltage and Under-Voltage Conditions
        USB_PARSER_ERROR_COMMAND = "o";           % Read System Error Data
        USB_PARSER_LTC3300_COMMAND = "k";         % LTC3300 Raw Write via LTC6804
        USB_PARSER_EEPROM_COMMAND = "g";          % Read/Write/Default EEPROM
        USB_PARSER_ALGORITHM_COMMAND = "j";       % timed balance incorporating algorithm
        USB_PARSER_UVOV_THRESHOLDS_COMMAND = "L"; % Write Over and Under Voltage Thresholds
        USB_PARSER_CAP_DEMO_COMMAND = "p";        % charge the cap board
        USB_PARSER_HELLO_COMMAND = "H";           % Reply with Hello String.  Mostly useful for testing.
        USB_PARSER_IDSTRING_COMMAND = "D";        % Read controller ID and firmware rev, this supports legacy functions
        USB_PARSER_DEFAULT_COMMAND = "N";         % By default anything not specified is a no-op
        USB_PARSER_BOOT_MODE_COMMAND = "r";       % Enter Bootload Mode
        
        % Dictionary used to wait for the proper number of characters before attempting to process the communication, without just throwing it away.
        DC2100A_MODEL_NUM_DEFAULT = "DC2100A-?";
        DC2100A_SERIAL_NUM_DEFAULT = "None             ";
        APP_FW_STRING_DEFAULT = "N/A        ";
        HELLOSTRING = "Hello ";
        DC2100A_IDSTRING = "DC2100A-A,LTC3300-1 demonstration board";
        USB_PARSER_DEFAULT_STRING = "Not a recognized command!";
        
        READ_TIMEOUT = 50;
    end
    
    properties
        serial
        baudRate
        port
        byteOrder
        terminator
        dataBits
        stopbits
        
        q = javaObject('java.util.LinkedList');
        
    end
    
    
    properties (SetAccess  = private)
        
    end
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % PRIVATE METHODS 
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    methods (Access  = private)
        function [success] = writeData(cmd, data)
            
        end
        
        function [success, data] = readData(obj, cmd, dataLen)
            write(obj.serial,cmd,"char");
            tim1 = toc;
            while(obj.serial.NumBytesAvailable < dataLen)
                if (toc - tim1 > DC2100A.READ_TIMEOUT)
                    success = false;
                    return;
                end
            end
            data = read(obj.serial, dataLen ,"char");
            success = true;
        end
    end
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % PUBLIC METHODS 
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    methods
        
        function obj = DC2100A(COMport, varargin)
            %DC2100A Initiates an instance of DC2100A class that takes
            %the COM port or serial object as an argument.
            %   This Constructor creates a generic serial object with
            %   Baudrate = 115200, DataBits = 8, Parity = 'none',
            %   StopBits = 1, and Terminator = 'LF'.
            %   port = 'COM#' (String)
            tic;
            
            obj.baudRate = 115200;
            obj.port = COMport;
            obj.byteOrder = "big-endian";
            obj.terminator = "LF";
            obj.stopbits = 1;
            
            
            obj.serial = serialport(obj.port, obj.baudRate);
            obj.serial.ByteOrder = obj.byteOrder; % obj.byteOrder;
            flush(obj.serial);
            pause(DC2100A.READ_TIMEOUT/1000);
            configureCallback(obj.serial, "byte", 1 ,@obj.callbackFcn)

        end
        
        function callbackFcn(obj, s, b)
%             nargin
%             varargin{:}
%             disp("There's been" + newline);
            data = read(s,1,"char");
            obj.q.add(data);
%             flush(s)
        end
        
        function [success, helloStr] = getHelloStr(obj)
            %getHelloStr Gets a test string: "Hello"
            index = 1; 
            num_bytes = 6;
            [success, data] = readData(obj, DC2100A.USB_PARSER_HELLO_COMMAND, num_bytes);
            if (success == false) 
                return; end
            helloStr = data(index:num_bytes-1); % remove the newline character
            charHelloStr = char(DC2100A.HELLOSTRING);
            if(strcmp(helloStr, charHelloStr(index:num_bytes-1)))
                success = true;
            end
        end
        
        function [success, helloStr] = getHelloStr2(obj)
            %getHelloStr Gets a test string: "Hello"
            helloStr = "";
            write(obj.serial,DC2100A.USB_PARSER_HELLO_COMMAND,"char");
            while(obj.q.size ~= 0)
               res = obj.q.remove;
               helloStr = helloStr + res;
            end
            success = true;
        end
        
        function [success, OV, UV] = get_OVUV(obj, boardNum)
            index = 2; % Index is 2 here since the USB_PARSER_UVOV_COMMAND is sent back
            numBytes2Read = 9;
            
            if(boardNum < 10)
                prefix = "0";
            elseif (boardNum >= 10 && boardNum < DC2100A.MAX_BOARDS)
                prefix = "";
            elseif (boardNum > DC2100A.MAX_BOARDS)
                error("boardNum cannot be greater than " + ...
                    num2str(DC2100A.MAX_BOARDS - 1) + "." + newline + ...
                    "Max num of boards is " + ...
                    num2str(DC2100A.MAX_BOARDS) + ".");
            end
            
            cmd = DC2100A.USB_PARSER_UVOV_COMMAND + prefix + num2str(boardNum);
            [success, data] = readData(obj, cmd, numBytes2Read);
            if (success == false) 
                return; end
            
            % get board number
            num_bytes = 2;
            board_num = hex2dec(data(index, num_bytes));
            index = index + num_bytes;
            
            % get the ov flags
            num_bytes = 3;
            OV = hex2dec(data(index, num_bytes));
            index = index + num_bytes;
            
            % get the uv flags
            num_bytes = 3;
            UV = hex2dec(data(index, num_bytes));
%             index = index + num_bytes;
            
        end
        
        
        function disconnect(obj)
            clear('obj.serial');
            clear obj;
        end
    end
end

