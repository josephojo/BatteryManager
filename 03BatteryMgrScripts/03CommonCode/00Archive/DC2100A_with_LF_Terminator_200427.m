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
        SYSTEM_TIMER_TICKS_OVERFLOW = bitshift(1, 32, 'uint32');     % the value at which the timestamps overflow
        
        
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
        
        NUCLEO_BOARD_NUM = 0; % It makes a lot of things simpler if the board with the PIC always has the same address.
        
        ERROR_DATA_SIZE = 12;
        
        % For scaling data gotten from eeprom data
        SOC_CAP_SCALE_FACTOR = 128;
        CURRENT_SCALE_FACTOR = 256;
        
        READ_TIMEOUT = 100;
                
        % Equivalent for Enums in C or C#
        EEPROM_Item_Type = struct...
            (...
            'Cap', 0,    ...
            'Current', 1 ...
            );
        
        FW_ERROR_CODE = struct...
            (...
            'NONE'                     , 0, ...   % No Error is present in DC2100A System.
            'TEST'                     , 1, ...   % Test Code for sending ERROR_DATA_SIZE raw bytes to the DC2100A GUI.
            'LTC6804_FAILED_CFG_WRITE' , 2, ...   % Errata in early LTC6804 silicon was detected, where configuration registers do not write successfully.
            'LTC6804_CRC'              , 3, ...   % An LTC6804 response had an incorrect CRC.
            'LTC3300_CRC'              , 4, ...   % An LTC3300 response had an incorrect CRC.
            'LTC6804_ADC_CLEAR'        , 5, ...   % An LTC6804 ADC conversion returned clear, indicating that the command to start the conversion was not received.
            'LTC3300_FAILED_CMD_WRITE' , 6  ...   % An LTC3300 Balancer Command Read did not match the last value written.
            );
        
        SYSTEM_STATE_TYPE = struct ...
            (...
            'Off'                , 0, ...
            'NUCLEO_Board_Init'     , 1, ...
            'System_Init'  		 , 2, ...
            'Awake'              , 3, ...
            'Sleep'              , 4, ...
            'Num_States'         , 5  ...
            );
        
        % *** Voltage Display
        VOLTAGE_RESOLUTION = 1/10000; % V per bit
        VOLTAGE_MAX = bitshift(1, 16) - 1; % 16 bit voltage
        VOLTAGE_MAX_DEFAULT = 4.5;
        VOLTAGE_MIN_DEFAULT = 2.5;
        
        % *** Temperature Display
        TEMPERATURE_RESOLUTION = 1; % °C per bit
        TEMPERATURE_MAX = 160; % °C per bit
        TEMPERATURE_MIN = -56; % °C per bit
        
        
    end
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % PUBLIC PROPERTIES
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    properties
        errLog
        
        serial
        baudRate
        port
        byteOrder
        terminator
        dataBits
        stopbits
        
        
        system_state
        
        numBoards = 0;
        selectedBoard = 0;

        board_address_table = zeros(1, DC2100A.LTC6804_MAX_BOARDS);
        
        Board_ID_Data = repmat(struct...
            (...
            'Model', DC2100A.DC2100A_MODEL_NUM_DEFAULT,...
            'Serial_Number', DC2100A.DC2100A_SERIAL_NUM_DEFAULT,...
            'Cap_Demo', false,...
            'Average_Charge_Current_12Cell', 0,...
            'Average_Discharge_Current_12Cell', 0,...
            'Average_Charge_Current_6Cell', 0,...
            'Average_Discharge_Current_6Cell', 0,...
            'FW_Rev', DC2100A.APP_FW_STRING_DEFAULT...
            ), DC2100A.MAX_BOARDS, 1);
        
        
        EEPROM_Data = repmat(...
            struct('Model', zeros(DC2100A.MAX_CELLS, 1),...
            'Charge_Currents', zeros(DC2100A.MAX_CELLS, 1),...
            'Discharge_Currents', zeros(DC2100A.MAX_CELLS, 1)...
            ), DC2100A.MAX_BOARDS, 1);
        
        
        % *** Timestamps for Voltage and Temperature
        voltage_timestamp = repmat(...
            struct(...
            'timestamp_last' , 0, ...
            'time' , -1, ...
            'time_difference' , 0, ...
            'is_balancing' , false  ...
            ), DC2100A.MAX_BOARDS, 1);
        temperature_timestamp
        max_time_difference = 0;
        num_times_over_4sec = 0;
        
        
        %  *** Summary of Board and System Voltages and Temperatures Display
        Stack_Summary_Data = struct...
            (...
            'Num_Cells' , 0, ...
            'Volt_Sum' , 0, ...
            'Volt_Average' , 0, ...
            'Volt_Max' , DC2100A.VOLTAGE_MAX, ...
            'Volt_Min' , 0, ...
            'Temp_Max' , DC2100A.TEMPERATURE_MIN, ...
            'Temp_Min' , DC2100A.TEMPERATURE_MAX, ...
            'Volt_Max_Cell' , 0, ...
            'Volt_Min_Cell' , 0, ...
            'Temp_Max_Cell' , 0, ...
            'Temp_Min_Cell' , 0  ...
            );
        Board_Summary_Data
        
        
        cellPresent
        Voltages = zeros(DC2100A.MAX_BOARDS, DC2100A.MAX_CELLS);
        Temperatures = zeros(DC2100A.MAX_BOARDS, DC2100A.MAX_CELLS);
        OV_Flags = zeros(1,DC2100A.MAX_BOARDS);
        UV_Flags = zeros(1,DC2100A.MAX_BOARDS);
        vMax
        vMin
        
        
        % *** Balancer Controls
        LTC3300s
        Timed_Balancers = repmat(struct('bal_action', 0, 'bal_timer', 0),...
            DC2100A.MAX_BOARDS, DC2100A.MAX_CELLS);
        Passive_Balancers = zeros(1, DC2100A.MAX_BOARDS);
        Min_Balance_Time_Value = 0;
        Min_Balance_Time_Board = 0;
        Max_Balance_Time_Value = 0;
        Max_Balance_Time_Board = 0;
        isBalancing = false;
        isTimedBalancing = false;
        
        % Variables to control rate at which commands are sent and responses are received
        USB_Comm_Can_Send = true;   % TRUE if allowed to send data to pipe
        
        % Variables to contain responses from before they are parsed
        USB_Parser_Buffer_In                           % Buffer for accumulating responses from USB
        USB_Parser_Buffer_Dropped                      % Buffer for accumulating characters dropped from USB
        
        USB_Comm_Cycle_Counter = 0;
        USB_Comm_Cycle_Counter_Period = DC2100A.USB_COMM_CYCLE_PERIOD_DEFAULT;
        
        % Variables to contain commands that are sent to the boards
        % todo - some kind of timeout between sending commands and getting responses would be great, but the underlying system doesn't account for this easily.
        USB_Comm_List_Out_Count_This_Cycle = 0;            % Variable to track how many commands were sent in this comm cycle
        USB_Comm_List_Out_Count_Per_Cycle_Max = 0;         % Variable to track the maximum number of commands sent in a comm cycle
        
        autoRead = true;
        Temperature_ADC_Test = false;
        
        USB_Parser_Response_DataSize = containers.Map;
        USBPool
        USBPoolSize = 1;
        USBPool_FOut % = parallel.FevalFuture;
        
        USB_Async_Flag = false;
        
        USBTimer
        
    end
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % PRIVATE PROPERTIES
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    properties (SetAccess  = private)
        % USB Data buffers (User Level)
        buf_out = javaObject('java.util.LinkedList'); % List for accumulating responses to USB
        buf_in = javaObject('java.util.LinkedList'); % Buffer for accumulating responses from USB
        
        pDQ = parallel.pool.DataQueue;
        
        
        
    end
    
    methods (Static)
        function res = REMOVE_LEN(buf, len)
            %REMOVE_LEN Removes and returns multiple elements from top of linkedlist
            %   Inputs:
            %       buf     : Java LinkedList
            %       len     : Number of elements to remove from linkedlist
            %
            %   Outputs:
            %       res     : Array of elements removed from linkedlist in
            %                   order
            res = char(zeros(1, len(end)));
            for i = 1:len
                res(i) = buf.remove();
            end
        end
        
        function label_text = SET_POPUP_TEXT(action_string, condition_string,...
                board_num, balHasStarted)
            
            label_text = action_string;
            
            if balHasStarted == true
                label_text = label_text + " has been suspended because";
            else
                label_text = label_text + " cannot be started because";
            end
            
            label_text = label_text +  newline;
            label_text = label_text +  "an " + condition_string ...
                + " has been detected on board " + num2str(board_num + 1)...
                + ".";
            label_text = label_text +  newline + newline;
            label_text = label_text +  "For more information, view the Event Log.";
        end
        
        
    end
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % PRIVATE METHODS
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    methods (Access  = private)
        
        function obj = System_Init(obj, attached)
            try
                obj.LTC3300s = repmat(...
                    LTC3300(0, obj.errLog),...
                    DC2100A.MAX_BOARDS, DC2100A.NUM_LTC3300); % Array of the LTC3300 Class
                
                for board_num = 0 : DC2100A.MAX_BOARDS -1
                    for ic_num = 0 : DC2100A.NUM_LTC3300 -1
                        % Group together the IC level status bits for this LTC3300
                        obj.LTC3300s(board_num +1, ic_num +1).ic_num = ic_num;
                    end
                end

                
                % Init Tree View
                if (attached == false)
                    obj.system_state = DC2100A.SYSTEM_STATE_TYPE.Off;
                else
                    obj.system_state = DC2100A.SYSTEM_STATE_TYPE.NUCLEO_Board_Init;
                end
                
                
                % Init DC2100A USB Communication
                obj.USB_Comm_Cycle_Counter = 0;
                obj.USB_Comm_Can_Send = true;
                
                obj.USB_Comm_List_Out_Count_This_Cycle = 0;
                obj.USB_Comm_List_Out_Count_Per_Cycle_Max = 0;
                
                obj.USB_Parser_Buffer_In = "";
                obj.USB_Parser_Buffer_Dropped = "";
                
                obj.autoRead = attached;
                
                % Init Voltages
                for board_num = 0 : DC2100A.MAX_BOARDS -1
                    for cell_num = 0 : DC2100A.MAX_CELLS -1
                        obj.cellPresent(board_num +1, cell_num +1) = attached;
                    end
                    if attached == true
                        obj.Board_Summary_Data(board_num +1).Num_Cells = DC2100A.MAX_CELLS;
                    else
                        obj.Board_Summary_Data(board_num +1).Num_Cells = 0;
                    end
                end
                
                % Init Over Voltage and Under Voltage Settings
                obj.vMax = DC2100A.VOLTAGE_MAX_DEFAULT;
                obj.vMin = DC2100A.VOLTAGE_MIN_DEFAULT;
                
                obj.temperature_timestamp = obj.voltage_timestamp;
                
                obj.Board_Summary_Data = repmat(obj.Stack_Summary_Data,...
                    DC2100A.MAX_BOARDS, 1);
                
            catch MEX
                Handle_Exception(obj, MEX);
            end
            
        end
        
        function [status] = writeData(cmd, data)
            
        end
        
        function [status, data] = readData(obj, cmd, dataLen)
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
            
            try
                % Turn USB Callback off so it doesn't activate while receiving
                % data synchronously
                configureCallback(obj.serial, "off");
                flush(obj.serial, "input"); 
                data = "";
                write(obj.serial,cmd,"char");
                tim1 = toc;
                while(obj.serial.NumBytesAvailable < dataLen)
                    if (toc - tim1 > DC2100A.READ_TIMEOUT/1000)
                        status = ErrorCode.COMM_TIMEOUT;
                        return;
                    end
                end
                data = read(obj.serial, dataLen ,"char");
                status = ErrorCode.NO_ERROR;
                
                % Turn USB Callback on again
                configureCallback(obj.serial, "terminator" ,@obj.USBDataIn_Callback)
                
            catch MEX
                Handle_Exception(obj, MEX);
                status = ErrorCode.UNKNOWN_ERROR;
            end
        end
        
        
        function setUSBDataSizes(obj)
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_MFG_COMMAND)...
                = 1 + (1 * 2) + strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT) ...
                + 1 + strlength(DC2100A.DC2100A_SERIAL_NUM_DEFAULT) ...
                + (4 * 2 * 2) + strlength(DC2100A.APP_FW_STRING_DEFAULT);
            
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_SYSTEM_COMMAND)...
                = 1 + (1 * 2) + (DC2100A.LTC6804_MAX_BOARDS * 1 * 2) + (2 * 2) ...
                + (2 * 2) + (1 * 2);
            
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_VOLTAGE_COMMAND)...
                = 1 + (1 * 2) + (4 * 2) ...
                + (DC2100A.MAX_CELLS * 2 * 2) + (1 * 2);
            
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_TEMPERATURE_COMMAND)...
                = 1 + (1 * 2) + (4 * 2) ...
                + (DC2100A.MAX_CELLS * 2 * 2) + (1 * 2);
            
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_TEMP_ADC_COMMAND) ...
                = 1 + (1 * 2) + (DC2100A.MAX_CELLS * 2 * 2);
            
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_PASSIVE_BALANCE_COMMAND)...
                = 1 + (1 * 2) + (2 * 2);
            
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_CELL_PRESENT_COMMAND) ...
                = 1 + (1 * 2) + (2 * 2);
            
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_TIMED_BALANCE_COMMAND)...
                = 1 + (1 * 2) + (DC2100A.MAX_CELLS * 2 * 2) + (2 * (2 + 1) * 2);
            
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_UVOV_COMMAND) ...
                = 1 + (1 * 2) + (2 * 3);
            
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_ERROR_COMMAND) ...
                = 1 + (1 * 2) + (2 * DC2100A.ERROR_DATA_SIZE);
            
            % These commands are variable length
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_LTC3300_COMMAND) ...
                = 1 + (1 * 2) + 1 + (1 * 2);
            
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_EEPROM_COMMAND) ...
                = 1 + (1 * 2) + 1;
            
            % These are random strings sent out without an identifier) = so don%t make any commands that use the same first letter as these random strings
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_HELLO_COMMAND)...
                = strlength(DC2100A.HELLOSTRING);
            
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_IDSTRING_COMMAND)...
                = strlength(DC2100A.DC2100A_IDSTRING);
            
            obj.USB_Parser_Response_DataSize(DC2100A.USB_PARSER_DEFAULT_COMMAND) ...
                = strlength(DC2100A.USB_PARSER_DEFAULT_STRING);
        end
        
        
        function USBDataOut_Timer_Callback(obj, varargin)
                        
            dataString = "";
            % If we're able to send more commands, send them.
            % Don't send if we are expecting the DC2100A to enter the bootloader, however, or if we're in the middle of asking if they want to enter the bootloader.
            if (obj.USB_Comm_Can_Send == true)
                
                if obj.system_state ~= DC2100A.SYSTEM_STATE_TYPE.Awake
                    % If the number of boards is still 0, then continue polling system data
                    if obj.USB_Comm_Cycle_Counter == 0
                        dataString = DC2100A.USB_PARSER_SYSTEM_COMMAND;
                    end
                else
                    if (obj.USB_Comm_Cycle_Counter == (floor((0 * DC2100A.USB_COMM_CYCLE_PERIOD_DEFAULT) / DC2100A.USB_COMM_TIMER_INTERVAL) * DC2100A.USB_COMM_TIMER_INTERVAL))
                        if (obj.autoRead == true)
                            dataString = DC2100A.USB_PARSER_VOLTAGE_COMMAND;
                        end
                    elseif (obj.USB_Comm_Cycle_Counter == (floor((0.2 * DC2100A.USB_COMM_CYCLE_PERIOD_DEFAULT) / DC2100A.USB_COMM_TIMER_INTERVAL) * DC2100A.USB_COMM_TIMER_INTERVAL))
                        if (obj.autoRead == true)
                            dataString = DC2100A.USB_PARSER_TEMPERATURE_COMMAND;
                        end
                    elseif (obj.USB_Comm_Cycle_Counter == (floor((0.4 * DC2100A.USB_COMM_CYCLE_PERIOD_DEFAULT) / DC2100A.USB_COMM_TIMER_INTERVAL) * DC2100A.USB_COMM_TIMER_INTERVAL))
                        if (obj.autoRead == true)
                            if (obj.Temperature_ADC_Test == true)
                                dataString = DC2100A.USB_PARSER_TEMP_ADC_COMMAND + dec2hex(obj.selectedBoard, 2);
                            end
                        end
                    elseif (obj.USB_Comm_Cycle_Counter == (floor((0.6 * DC2100A.USB_COMM_CYCLE_PERIOD_DEFAULT) / DC2100A.USB_COMM_TIMER_INTERVAL) * DC2100A.USB_COMM_TIMER_INTERVAL))
                        if obj.isTimedBalancing == true
                            dataString = DC2100A.USB_PARSER_TIMED_BALANCE_COMMAND + "R" + dec2hex(obj.selectedBoard, 2);
                        end
                    elseif obj.USB_Comm_Cycle_Counter == (floor((0.8 * DC2100A.USB_COMM_CYCLE_PERIOD_DEFAULT) / DC2100A.USB_COMM_TIMER_INTERVAL) * DC2100A.USB_COMM_TIMER_INTERVAL)
                        % Note that this is the only polled command that wouldn't be simple to turn into something the FW can stream on its own.
                        if obj.isBalancing == true
                            dataString = LTC3300_Raw_Read(obj, obj.selectedBoard, LTC3300.Command.Read_Balance) + LTC3300_Raw_Read(obj, obj.selectedBoard, LTC3300.Command.Read_Status);
                        end
                    end
                end
                
                % if no periodic commands are being sent, send the special commands accumulated from elsewhere in the code.
                if strcmp(dataString, "")
                    % Send up to USB_MAX_PACKET_SIZE characters
                    while (obj.buf_out.size > 0) && (strlength(obj.buf_out.peek()) < (DC2100A.USB_MAX_PACKET_SIZE - strlength(dataString)))
                        obj.USB_Comm_List_Out_Count_This_Cycle = obj.USB_Comm_List_Out_Count_This_Cycle + strlength(obj.buf_out.peek());
                        dataString = dataString + obj.buf_out.remove();
                    end
                end
                
                % if any commands need to be sent, send them.
                if ~strcmp(dataString, "")
                    % Clear flag to prevent any new commands from being sent
                    obj.USB_Comm_Can_Send = false;
                    % Copy data where hidden screen displays it in a field and then sends via USB
                    % txtBulkDataWrite.Text = dataString
                    if obj.USB_Async_Flag == true
%                         if WritePipe_BackgroundWorker.IsBusy == false
%                             WritePipe_BackGroundWorker_Monitor.ThreadLaunchedTime = DateTime.Now
%                              obj.USBPool_F ...
%                                  = parfeval(@obj.Write2Serial_Start, 1, dataString); % Pass the string to write
%                             afterAll()
%                         end
                    else
                        write(obj.serial, dataString); % Pass the string to write
                        obj.USB_Comm_Can_Send = true;
                    end
                        
                end
                
                % Increment the timer for sending commands and reset once over the interval
                obj.USB_Comm_Cycle_Counter = obj.USB_Comm_Cycle_Counter + DC2100A.USB_COMM_TIMER_INTERVAL;
                if (obj.USB_Comm_Cycle_Counter >= obj.USB_Comm_Cycle_Counter_Period)
                    % Track the number of commands sent this comm cycle
                    if (obj.USB_Comm_List_Out_Count_This_Cycle > obj.USB_Comm_List_Out_Count_Per_Cycle_Max)
                        obj.USB_Comm_List_Out_Count_Per_Cycle_Max = obj.USB_Comm_List_Out_Count_This_Cycle;
                    end
                    
                    % Clear variables to start next cycle
                    obj.USB_Comm_Cycle_Counter = 0;
                    obj.USB_Comm_List_Out_Count_This_Cycle = 0;
                end
            end
            
        end
        
        
        % The inputs are required by the configureCallback function
        function USBDataIn_Callback(obj, s, ~)
            %USBDataIn_Callback Callback when data available in serial
            %buffer is available
            disp("Bytes = " + num2str(s.NumBytesAvailable));
            % Blocking Code
            for i=1:s.NumBytesAvailable
                obj.buf_in.add(read(s, 1, "char"));
            end
            USBDataIn_Parser(obj);
            
            %             dataStr = read(s, s.NumBytesAvailable, "char");
            %             USBDataIn_Parser(obj, dataStr);
            
            %{
                % Async Method
                ind = 1;
                count = 1;
                while ind < s.NumBytesAvailable
                    key = read(s, 1,"char");

                    if(isKey(obj.USB_Parser_Response_DataSize, key))
                        num_bytes = obj.USB_Parser_Response_DataSize(key);
                        dataStr = key + read(s, num_bytes - 1, "char");
                        ind = ind + num_bytes;
                        disp(ind)
                    else

                    end

                     obj.USBPool_F = parfeval(obj.USBPool, @obj.USBDataIn_Parser, ...
                        1, dataStr);
                    count = count + 1;
                end

                disp("before");
                afterAll(obj.USBPool_F, @helloResp, 1);
                disp("After AfterAll");
            %}
        end
        
        
        function USBDataIn_Parser(obj)
            %USBDataIn_Parser Parses String data input from serial buffer
            %to workable values
            
            while obj.buf_in.size >= 1
                key = obj.buf_in.peek(); % Looks in the top of the LinkedList without removing it
%                 disp(DC2100A.REMOVE_LEN(obj.buf_in, obj.buf_in.size));
                if(isKey(obj.USB_Parser_Response_DataSize, key))
                    num_bytes = obj.USB_Parser_Response_DataSize(key);
                    [status, obj] = USB_Process_Response(obj, num_bytes);
                else
                    % Error Catcher to catch if the key is not available
                    obj.errLog.Add(ErrorCode.USB_PARSER_UNKNOWN_COMMAND, ...
                        "Unrecognized Command. Key '" + key + "' Not Found");
                    warning("Unrecognized Command. Key '" + key + "' Not Found");
                end
                
                
            end
            
        end
        
        
        function [status, obj] = USB_Process_Response(obj, length)
            %USB_Process_Response Converts String to the required data
            %based on the initial command to the string
            switch (obj.buf_in.peek())
                case DC2100A.USB_PARSER_HELLO_COMMAND
                    helloStr = DC2100A.REMOVE_LEN(obj.buf_in, length);
                    helloStr = helloStr(1:end-1); % remove the newline character
                    charHelloStr = char(DC2100A.HELLOSTRING);
                    if(strcmp(helloStr, charHelloStr(1:length-1)))
                        status = ErrorCode.NO_ERROR;
                    else
                        obj.errLog.Add(ErrorCode.COMMTEST_DATA_MISMATCH,...
                            "Did not receive Hello String from MCU.");
                        status = ErrorCode.COMMTEST_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_IDSTRING_COMMAND
                    obj.buf_in.remove; % Remove the command or first character
                    string1 = DC2100A.REMOVE_LEN(obj.buf_in,...
                        strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT));
                    string2 = DC2100A.DC2100A_IDSTRING(1:...
                        strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT));
                    if (strcmp1(string1, string2))
                        obj.errLog.Add(ErrorCode.USB_PARSER_UNKNOWN_DFLT_STRING,...
                            "Unknown ID String received by MCU.");
                        status = ErrorCode.USB_PARSER_UNKNOWN_IDSTRING;
                    end
                    
                    string1 = DC2100A.REMOVE_LEN(obj.buf_in,...
                        length - strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT));
                    string2 = DC2100A.DC2100A_IDSTRING(...
                        strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT):...
                        length - strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT));
                    
                    if (strcmp1(string1, string2))
                        obj.errLog.Add(ErrorCode.USB_PARSER_UNKNOWN_DFLT_STRING,...
                            "Unknown ID String received by MCU.");
                        status = ErrorCode.USB_PARSER_UNKNOWN_IDSTRING;
                    end
                    
                case DC2100A.USB_PARSER_DEFAULT_COMMAND
                    obj.buf_in.remove; % Remove the command or first character
                    if (DC2100A.REMOVE_LEN(obj.buf_in, length) ...
                            ~= DC2100A.USB_PARSER_DEFAULT_STRING)
                        obj.errLog.Add(ErrorCode.USB_PARSER_UNKNOWN_DFLT_STRING,...
                            "Unknown command received by MCU.");
                        status = ErrorCode.USB_PARSER_UNKNOWN_DFLT_STRING;
                    end
                    
                case DC2100A.USB_PARSER_BOOT_MODE_COMMAND % #Scrapping - Not Needed
                    
                case DC2100A.USB_PARSER_ERROR_COMMAND
                    try
                        temp_error_data = zeros(1, DC2100A.ERROR_DATA_SIZE);
                        
                        % get the error number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        temp_error_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        
                        num_bytes = 2;
                        for byte_num = 1:DC2100A.ERROR_DATA_SIZE
                            temp_error_data(byte_num) ...
                                = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                        end
                        
                        % *** If we got here, all data conversion were successful
                        
                        % Create error log entry
                        switch(temp_error_num)
                            case DC2100A.FW_ERROR_CODE.LTC6804_CRC
                                error_string = ...
                                    "Board " + num2str(temp_error_data(1) + 1)...
                                    + ", Command: " + dec2hex(bitshift(temp_error_data(2), 8) + temp_error_data(3), 4)...
                                    + ", Bytes: ";
                                for byte_num = 4:DC2100A.ERROR_DATA_SIZE
                                    error_string = error_string ...
                                        + dec2hex(temp_error_data(byte_num), 2) + ", ";
                                end
                                obj.errLog.Add(ErrorCode.LTC6804_CRC, error_string, num2str(obj.Board_Summary_Data(temp_error_data(1)).Volt_Sum, 5)); % 5 here ensures 5 sig figs
                                
                            case DC2100A.FW_ERROR_CODE.LTC3300_CRC
                                error_string = ...
                                    "Board " + num2str(temp_error_data(1) + 1)...
                                    + ", IC: " + num2str(temp_error_data(2))...
                                    + ", Command: " + dec2hex(temp_error_data(3), 2)...
                                    + ", Bytes: ";
                                for byte_num = 4:DC2100A.ERROR_DATA_SIZE
                                    error_string = error_string ...
                                        + dec2hex(temp_error_data(byte_num), 2) + ", ";
                                end
                                obj.errLog.Add(ErrorCode.LTC3300_CRC, error_string,...
                                    num2str(obj.Board_Summary_Data(temp_error_data(1) +1).Volt_Sum, 5)); % 5 here ensures 5 sig figs
                                
                            case DC2100A.FW_ERROR_CODE.LTC6804_FAILED_CFG_WRITE
                                error_string = ...
                                    "Board " + num2str(temp_error_data(1) + 1)...
                                    + ", Test_Value_VUV: " + num2str(bitshift(temp_error_data(2), 8) + temp_error_data(3))...
                                    + " : " + num2str(bitshift(temp_error_data(4), 8) + temp_error_data(5))...
                                    + ", Test_Value_VOV: " + num2str(bitshift(temp_error_data(6), 8) + temp_error_data(7))...
                                    + " : " + num2str(bitshift(temp_error_data(8), 8) + temp_error_data(9));
                                
                                obj.errLog.Add(ErrorCode.LTC6804_Failed_CFG_Write, error_string);
                                
                            case DC2100A.FW_ERROR_CODE.LTC6804_ADC_CLEAR
                                error_string = ...
                                    "Board " + num2str(temp_error_data(1) + 1)...
                                    + " failed to start ADC conversion.";
                                fail_timestamp = bitshift(temp_error_data(2), 24) + bitshift(temp_error_data(3), 16) + bitshift(temp_error_data(4), 8) + temp_error_data(5);
                                
                                obj.errLog.Add(ErrorCode.LTC6804_ADC_CLEAR, error_string, fail_timestamp);
                                
                            case DC2100A.FW_ERROR_CODE.LTC3300_FAILED_CMD_WRITE
                                error_string = ...
                                    "Board " + num2str(temp_error_data(1) + 1)...
                                    + " failed to write balance command."...
                                    + ", write value:" + dec2hex(bitshift(temp_error_data(2), 16) + bitshift(temp_error_data(3), 8) + temp_error_data(4) , 4)...
                                    + ", read value:" + dec2hex(bitshift(temp_error_data(5), 16) + bitshift(temp_error_data(6), 8) + temp_error_data(7) , 4);
                                
                                obj.errLog.Add(ErrorCode.LTC3300_FAILED_CMD_WRITE, error_string, num2str(obj.Board_Summary_Data(temp_error_data(1)).Volt_Sum, 5)); % 5 here ensures 5 sig figs
                                
                            otherwise
                                error_string = "Bytes: ";
                                for byte_num = 1:DC2100A.ERROR_DATA_SIZE
                                    error_string = error_string ...
                                        + num2str(temp_error_data(byte_num)) + ", ";
                                end
                                obj.errLog.Add(ErrorCode.LTC3300_CRC, error_string);
                        end
                        status = ErrorCode.NO_ERROR;
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_UVOV_COMMAND
                    try
                        action_string = "";
                        
                        % save last OV and UV condition, so that we can pop-up a message if it changes.
                        [system_ov_last, ~] = Get_SystemOV(obj);
                        [system_uv_last, ~] = Get_SystemUV(obj);
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            % If this is a board we don't know, then this is a failed response
                            obj.errLog.Add(Error_Code.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCodes.USB_PARSER_UNKNOWN_BOARD;
                        else
                            % get the ov flags
                            num_bytes = 3;
                            temp_ov_flags = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                            
                            % get the uv flags
                            num_bytes = 3;
                            temp_uv_flags = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                            
                            % If we got here, all data conversion were successful
                            
                            % If flags haven't actually changed, nothing needs to be done
                            if (obj.UV_Flags(board_num +1) ~= temp_uv_flags) ...
                                    || (obj.OV_Flags(board_num +1) ~= temp_ov_flags)
                                
                                obj.UV_Flags(board_num +1) = temp_uv_flags;
                                obj.OV_Flags(board_num +1) = temp_ov_flags;
                                
                                % When an Overvoltage or Undervoltage condition occurs, always create an error log entry, but
                                % only pop up messages Pop up message if an action is being cancelled due to a new OV/UV condition.
                                condition_string = Get_OVUV_Condition_String(obj, board_num);
                                
                                % Figure out if an action is being taken due to the new OV/UV condition.
                                if (((system_ov_last == false) && (obj.Get_SystemOV(board_num) == true)) || ...
                                        ((system_uv_last == false) && (obj.Get_SystemUV(board_num) == true)))
                                    
                                    % Stop balancing.
                                    if obj.isBalancing == true
                                        obj.Timed_Balance_Stop(false);
                                        if ~strcmp(action_string, "")
                                            action_string = action_string + "/";
                                        end
                                        action_string = action_string + "Balancing";
                                    end
                                    
                                    %  Display information about OV/UV condition and actions taken due to it.
                                    if ~strcmp(action_string, "")
                                        warning(action_string ...
                                            + " suspended due to " ...
                                            + condition_string + ".");
                                    end
                                    
                                    
                                    % Pop up message if action is being cancelled due to OV/UV condition.
                                    if ~strcmp(action_string, "")
                                        popupStr = DC2100A.SET_POPUP_TEXT(action_string, ...
                                            condition_string, board_num, true);
                                        errordlg(popupStr, "OV or UV Error");
                                    end
                                    
                                    % Create error log entry
                                    if ~strcmp(condition_string, "")
                                        obj.errLog.Add(ErrorCode.OVUV,...
                                            "Board " + num2str(board_num + 1)...
                                            + " " + condition_string + ". Flags = "...
                                            + dec2hex(temp_ov_flags, 3) + dec2hex(temp_uv_flags, 3));
                                    else
                                        obj.errLog.Add(ErrorCode.OVUV,...
                                            "Board " + num2str(board_num + 1)...
                                            + " returned from OV/UV" + ". Flags = "...
                                            + dec2hex(temp_ov_flags, 3) + dec2hex(temp_uv_flags, 3));
                                    end
                                end
                            end
                        end
                        status = ErrorCode.NO_ERROR;
                        
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_SYSTEM_COMMAND
                    % Process the system configuration information
                    try
                        temp_board_address_table ...
                            = 16 * ones(1, DC2100A.LTC6804_MAX_BOARDS);
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        num_boards_next = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        
                        % get the board addresses
                        num_bytes = 2;
                        for board_num = 0 : DC2100A.LTC6804_MAX_BOARDS - 1
                            temp_board_address_table(board_num +1) ...
                                = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                        end
                        
                        % get the undervoltage and overvoltage thresholds
                        num_bytes = 4;
                        temp_vmin = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in,...
                            num_bytes)) * DC2100A.VOLTAGE_RESOLUTION;
                        index = index + num_bytes;
                        temp_vmax = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in,...
                            num_bytes)) * DC2100A.VOLTAGE_RESOLUTION;
                        index = index + num_bytes;
                        
                        
                        % get the cap demo bitmap
                        num_bytes = 2;
                        temp_cap_demo_bitmap = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        
                        %{
                        % #NeededNow?? #Scrapping - Don't think we'll need
                        % this. It is for the Cap Demo which we do not have
                        % *************************************************
                        %if bitand(temp_cap_demo_bitmap, 0x7) == 0x3
                        %    temp_charge = true;
                        %    temp_discharge = false;
                        %elseif bitand(temp_cap_demo_bitmap, 0x7)== 0x5
                        %    temp_charge = false;
                        %    temp_discharge = true;
                        %else
                        %    temp_charge = false;
                        %    temp_discharge = false;
                        %end
                        %}
                        
                        % *** If we got here, all of the data conversion was successful!
                        for board_num = 0 : DC2100A.LTC6804_MAX_BOARDS - 1
                            obj.board_address_table(board_num)...
                                = temp_board_address_table(board_num);
                        end
                        obj.vMin = temp_vmin;
                        obj.vMax = temp_vmax;
                        %{
                        % #NeededNow?? #Scrapping - Don't think we'll need
                        % this. It is for the Cap Demo which we do not have
                        % *************************************************
                        % is_charging = temp_charge
                        % is_discharging = temp_discharge
                        %}
                        
                        % If we're receiving responses to the "s" command then we must have a board attached.
                        % It just must not have its cells powered up.
                        if num_boards_next == 0
                            num_boards_next = 1;
                            
                            % Give a special message when the DC2100A is connected,
                            % but unable to communicate with its LTC6804 due to the cells being unpowered.
                            if obj.numBoards == 0
                                warning("DC2100A has connected, " ...
                                    + "but its cells are not charged.");
                            end
                        else
                            
                            % If this is the special case where the NUCLEO board
                            % was connected and is now powered, request its
                            % data so that the EEPROM and LTC3300 data is updated.
                            % todo - this is so gross
                            if (num_boards_next == 1) ...
                                    && (obj.system_state ~= DC2100A.SYSTEM_STATE_TYPE.Awake)
                                
                                obj.buf_out.Add(DC2100A.USB_PARSER_MFG_COMMAND...
                                    + "R" + dec2hex(DC2100A.NUCLEO_BOARD_NUM, 2));
                                
                                obj.buf_out.Add(DC2100A.USB_PARSER_EEPROM_COMMAND...
                                    + "R" + dec2hex(DC2100A.NUCLEO_BOARD_NUM, 2) + "0");
                                
                                obj.buf_out.Add(DC2100A.USB_PARSER_EEPROM_COMMAND...
                                    + "R" + dec2hex(DC2100A.NUCLEO_BOARD_NUM, 2) + "1");
                                
                                % Read UV/OV, passive balancer, and ltc3300 register data for selected board
                                obj.buf_out.Add(DC2100A.USB_PARSER_UVOV_COMMAND...
                                    + dec2hex(DC2100A.NUCLEO_BOARD_NUM, 2));
                                
                                obj.buf_out.Add(DC2100A.USB_PARSER_PASSIVE_BALANCE_COMMAND...
                                    + "R" + dec2hex(DC2100A.NUCLEO_BOARD_NUM, 2));
                                
                                obj.buf_out.Add(LTC3300_Raw_Read(obj,...
                                    DC2100A.NUCLEO_BOARD_NUM, LTC3300.Command.Read_Balance));
                                
                                obj.buf_out.Add(LTC3300_Raw_Read(obj,...
                                    DC2100A.NUCLEO_BOARD_NUM, LTC3300.Command.Read_Status));
                                
                                warning("DC2100A has connected, and its cells are charged.");
                            end
                            
                            obj.system_state = DC2100A.SYSTEM_STATE_TYPE.Awake;   % If the number of boards reported by this command is non-zero, then the boards must be powered.
                            
                            if num_boards_next ~= obj.numBoards
                                obj.numBoards = 0;
                                %  Then add all of the new boards
                                for board_num  = 0 : (num_boards_next - 1)
                                    obj.numBoards = obj.numBoards + 1;
                                end
                                
                                %  Boards are detected, start reading data
                                
                                % Read ID and EEPROM data for all boards
                                for board_num = 0 : (obj.numBoards - 1)
                                    obj.buf_out.Add(DC2100A.USB_PARSER_MFG_COMMAND...
                                        + "R" + dec2hex(board_num, 2));
                                    
                                    obj.buf_out.Add(DC2100A.USB_PARSER_EEPROM_COMMAND...
                                        + "R" + dec2hex(board_num, 2) + "0");
                                    
                                    obj.buf_out.Add(DC2100A.USB_PARSER_EEPROM_COMMAND...
                                        + "R" + dec2hex(board_num, 2) + "1");
                                    
                                    % Read UV/OV, passive balancer, and ltc3300 register data for all board
                                    obj.buf_out.Add(DC2100A.USB_PARSER_UVOV_COMMAND...
                                        + dec2hex(board_num, 2));
                                    
                                    obj.buf_out.Add(DC2100A.USB_PARSER_PASSIVE_BALANCE_COMMAND...
                                        + "R" + dec2hex(board_num, 2));
                                    
                                    obj.buf_out.Add(LTC3300_Raw_Read(obj,...
                                        board_num, LTC3300.Command.Read_Balance));
                                    
                                    obj.buf_out.Add(LTC3300_Raw_Read(obj,...
                                        board_num, LTC3300.Command.Read_Status));
                                end
                                
                                
                                
                                %  Adjust the polling interval to account for more boards
                                obj.USB_Comm_Cycle_Counter_Period ...
                                    = DC2100A.USB_COMM_CYCLE_PERIOD_DEFAULT...
                                    + (obj.numBoards - 1) ...
                                    * DC2100A.USB_COMM_TIMER_INTERVAL ...
                                    * DC2100A.USB_COMM_TIMER_INTERVALS_PER_BOARD;
                                
                                % Restart the counter so that the voltage will be the first value read
                                obj.USB_Comm_Cycle_Counter = 0;
                            end
                        end
                        status = ErrorCode.NO_ERROR;
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_MFG_COMMAND
                    % Process the Manufacturing Data
                    
                    try
                        temp_board_id_data = repmat(struct...
                            (...
                            'Model', DC2100A.DC2100A_MODEL_NUM_DEFAULT,...
                            'Serial_Number', DC2100A.DC2100A_SERIAL_NUM_DEFAULT,...
                            'Cap_Demo', false,...
                            'Average_Charge_Current_12Cell', 0,...
                            'Average_Discharge_Current_12Cell', 0,...
                            'Average_Charge_Current_6Cell', 0,...
                            'Average_Discharge_Current_6Cell', 0,...
                            'FW_Rev', DC2100A.APP_FW_STRING_DEFAULT...
                            ), DC2100A.MAX_BOARDS, 1);
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            obj.errLog.Add(Error_Code.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCodes.USB_PARSER_UNKNOWN_BOARD;
                        else
                            %  get the model number
                            num_bytes = strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT);
                            temp_board_id_data.Model ...
                                = DC2100A.REMOVE_LEN(obj.buf_in, num_bytes);
                            index = index + num_bytes;
                            
                            %  get setting for whether this is a cap board demo or not.
                            num_bytes = 1;
                            TempString = DC2100A.REMOVE_LEN(obj.buf_in, num_bytes);
                            index = index + num_bytes;
                            if strcmpi(TempString, "T")
                                temp_board_id_data.Cap_Demo = true;
                            elseif strcmpi(TempString, "F")
                                temp_board_id_data.Cap_Demo = false;
                            else
                                temp_board_id_data.Cap_Demo = false; % Default to false as we don't have the CAP demo system
                            end
                            
                            % get the serial number
                            num_bytes = strlength(DC2100A.DC2100A_SERIAL_NUM_DEFAULT);
                            temp_board_id_data.Serial_Number ...
                                = DC2100A.REMOVE_LEN(obj.buf_in, num_bytes);
                            index = index + num_bytes;
                            
                            % BEGINNING OF PARAMETERS THAT ARE NOT STORED IN EEPROM
                            % get the 12 cell charge current
                            num_bytes = 4;
                            temp_board_id_data.Average_Charge_Current_12Cell...
                                = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes)) / 1000;
                            index = index + num_bytes;
                            
                            % get the 12 cell discharge current
                            num_bytes = 4;
                            temp_board_id_data.Average_Discharge_Current_12Cell...
                                = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes)) / 1000;
                            index = index + num_bytes;
                            
                            % get the 6 cell charge current
                            num_bytes = 4;
                            temp_board_id_data.Average_Charge_Current_6Cell ...
                                = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes)) / 1000;
                            index = index + num_bytes;
                            
                            % get the 6 cell discharge current
                            num_bytes = 4;
                            temp_board_id_data.Average_Discharge_Current_6Cell ...
                                = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes)) / 1000;
                            index = index + num_bytes;
                            
                            % get the firmware revision
                            num_bytes = strlength(DC2100A.APP_FW_STRING_DEFAULT);
                            temp_board_id_data.FW_Rev = DC2100A.REMOVE_LEN(obj.buf_in, num_bytes);
                            index = index + num_bytes;
                            
                            % If we got here, all data conversion were successful
                            
                            %{
                        % #NeededNow?? #Scrapping - Don't think we'll need
                        % this. It is for the Cap Demo which we do not have
                        % *************************************************
                        
                        % Don't Need this
                        % If this is the PIC board, then translate the FW revision from a string into a parsed object
                        %if board_num = DC2100A.DC2100A_PIC_BOARD_NUM Then
                        %    Firmware_Version_Connected.Set_String(temp_board_id_data.FW_Rev)
                        %    temp_board_id_data.FW_Rev = Firmware_Version_Connected.Get_String()
                        %end
                            %}
                            
                            obj.Board_ID_Data(board_num +1) = temp_board_id_data;
                        end
                        status = ErrorCode.NO_ERROR;
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_VOLTAGE_COMMAND
                    try
                        temp_voltages = zeros(1, DC2100A.MAX_CELLS);
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            obj.errLog.Add(Error_Code.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCodes.USB_PARSER_UNKNOWN_BOARD;
                        else
                            % get the timestamp
                            num_bytes = 8;
                            temp_timestamp = uint32(hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes)));
                            index = index + num_bytes;
                            
                            % get the board voltages
                            num_bytes = 4;
                            for temp_num = 0 : DC2100A.MAX_CELLS - 1
                                temp_voltages(temp_num +1) ...
                                    = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                                index = index + num_bytes;
                            end
                            
                            % get the balancestamp
                            num_bytes = 2;
                            temp_balancestamp = uint8(hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes)));
                            index = index + num_bytes;
                            
                            % *** If we got here, all of the data conversion was successful!
                            temp_max = 0;                     % Start max as value that's really low
                            temp_min = DC2100A.VOLTAGE_MAX;           % Start min as value that's really high
                            
                            for temp_num = 0 : DC2100A.MAX_CELLS - 1
                                obj.Voltages(board_num +1, temp_num +1) ...
                                    = temp_voltages(temp_num +1) ...
                                    * DC2100A.VOLTAGE_RESOLUTION;
                                if obj.cellPresent(board_num +1, temp_num +1) == true
                                    if obj.Voltages(board_num +1, temp_num +1) > temp_max
                                        temp_max = obj.Voltages(board_num +1, temp_num +1);
                                        cell_max = temp_num;
                                    end
                                    if obj.Voltages(board_num +1, temp_num +1) < temp_min
                                        temp_min = obj.Voltages(board_num +1, temp_num +1);
                                        cell_min = temp_num;
                                    end
                                    temp_sum = temp_sum + obj.Voltages(board_num +1, temp_num +1);
                                end
                            end
                            obj.Board_Summary_Data(board_num +1).Volt_Max = temp_max;
                            obj.Board_Summary_Data(board_num +1).Volt_Min = temp_min;
                            obj.Board_Summary_Data(board_num +1).Volt_Max_Cell = cell_max;
                            obj.Board_Summary_Data(board_num +1).Volt_Min_Cell = cell_min;
                            obj.Board_Summary_Data(board_num +1).Volt_Sum = temp_sum;
                            obj.Board_Summary_Data(board_num +1).Volt_Average = temp_sum / obj.Board_Summary_Data(board_num +1).Num_Cells;
                            
                            
                            % Set the summary data for system
                            temp_max = 0;                        % Start max as value that's really low
                            temp_min = DC2100A.VOLTAGE_MAX * DC2100A.MAX_CELLS;  % Start min as value that's really high
                            temp_sum = 0;
                            temp_num_cells = 0;
                            for temp_board = 0 : obj.numBoards - 1
                                if obj.Board_Summary_Data(temp_board +1).Volt_Max > temp_max
                                    temp_max = obj.Board_Summary_Data(temp_board +1).Volt_Max;
                                    cell_max = obj.Board_Summary_Data(temp_board +1).Volt_Max_Cell;
                                end
                                if obj.Board_Summary_Data(temp_board +1).Volt_Min < temp_min
                                    temp_min = obj.Board_Summary_Data(temp_board +1).Volt_Min;
                                    cell_min = obj.Board_Summary_Data(temp_board +1).Volt_Min_Cell; % #Changed - Volt_Max_Cell in og code to Volt_Min_Cell
                                end
                                temp_num_cells = temp_num_cells + obj.Board_Summary_Data(temp_board +1).Num_Cells;
                                temp_sum = temp_sum + obj.Board_Summary_Data(temp_board +1).Volt_Sum;
                            end
                            obj.Stack_Summary_Data.Volt_Max = temp_max;
                            obj.Stack_Summary_Data.Volt_Min = temp_min;
                            obj.Stack_Summary_Data.Volt_Max_Cell = cell_max;
                            obj.Stack_Summary_Data.Volt_Min_Cell = cell_min;
                            obj.Stack_Summary_Data.Volt_Sum = temp_sum;
                            obj.Stack_Summary_Data.Volt_Average = temp_sum / temp_num_cells;
                            
                            
                            obj.voltage_timestamp(board_num +1) ...
                                = Update(obj, obj.voltage_timestamp(board_num +1), ...
                                temp_timestamp, temp_balancestamp);
                            
                            try
                                if obj.voltage_timestamp(board_num +1).time_difference > 4
                                    obj.num_times_over_4sec ...
                                        = obj.num_times_over_4sec + 1;
                                    obj.errLog.Add(Error_Code.USB_Delayed,...
                                        num2str(obj.voltage_timestamp(board_num +1)...
                                        .time_difference) + ":" + num2str(obj.num_times_over_4sec)); % #debugString=buffer
                                end
                                
                                if obj.voltage_timestamp(board_num +1).time_difference...
                                        > obj.max_time_difference
                                    obj.max_time_difference ...
                                        = obj.voltage_timestamp(board_num +1).time_difference;
                                end
                                
                            catch MEX
                                Handle_Exception(obj, MEX);
                            end
                        end
                        
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_TEMPERATURE_COMMAND
                    try
                        temp_temperatures = zeros(1, DC2100A.NUM_TEMPS);
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            % If this is a board we don't know, then this is a failed response
                            obj.errLog.Add(Error_Code.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCodes.USB_PARSER_UNKNOWN_BOARD;
                        else
                            % get the timestamp
                            num_bytes = 8;
                            temp_timestamp = uint32(hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes)));
                            index = index + num_bytes;
                            
                            % get the board temperatures
                            num_bytes = 4;
                            for temp_num = 0 : DC2100A.NUM_TEMPS - 1
                                temp_temperatures(temp_num +1) ...
                                    = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                                
                                % todo - this is an ugly way to handle signs
                                if (temp_temperatures(temp_num +1) >= 65536 / 2)
                                    temp_temperatures(temp_num +1) ...
                                        = temp_temperatures(temp_num +1) - 65536;
                                end
                                index = index + num_bytes;
                            end
                            
                            % get the balancestamp
                            num_bytes = 2;
                            temp_balancestamp = uint8(hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes)));
                            index = index + num_bytes;
                            
                            % *** If we got here, all of the data conversion was successful!
                            temp_max = DC2100A.TEMPERATURE_MIN;   % Start max as value that's really low
                            temp_min = DC2100A.TEMPERATURE_MAX;   % Start min as value that's really high
                            
                            for temp_num = 0 : DC2100A.NUM_TEMPS - 1
                                obj.Temperatures(board_num +1, temp_num +1) ...
                                    = temp_temperatures(temp_num +1);
                                if obj.Temperatures(board_num +1, temp_num +1) > temp_max
                                    temp_max = obj.Temperatures(board_num +1, temp_num +1);
                                    cell_max = temp_num;
                                end
                                if obj.Temperatures(board_num +1, temp_num +1) < temp_min
                                    temp_min = obj.Temperatures(board_num +1, temp_num +1);
                                    cell_min = temp_num;
                                end
                            end
                            obj.Board_Summary_Data(board_num +1).Temp_Max = temp_max;
                            obj.Board_Summary_Data(board_num +1).Temp_Min = temp_min;
                            obj.Board_Summary_Data(board_num +1).Temp_Max_Cell = cell_max;
                            obj.Board_Summary_Data(board_num +1).Temp_Min_Cell = cell_min;
                            
                            
                            % Set the summary data for system
                            temp_max = DC2100A.TEMPERATURE_MIN;  % Start max as value that's really low
                            temp_min = DC2100A.TEMPERATURE_MAX;  % Start min as value that's really high
                            for temp_board = 0 : obj.numBoards - 1
                                if obj.Board_Summary_Data(temp_board +1).Temp_Max > temp_max
                                    temp_max = obj.Board_Summary_Data(temp_board +1).Temp_Max;
                                    cell_max = obj.Board_Summary_Data(temp_board +1).Temp_Max_Cell;
                                end
                                if obj.Board_Summary_Data(temp_board +1).Temp_Min < temp_min
                                    temp_min = obj.Board_Summary_Data(temp_board +1).Temp_Min;
                                    cell_min = obj.Board_Summary_Data(temp_board +1).Temp_Min_Cell;
                                end
                                temp_num_cells = temp_num_cells + obj.Board_Summary_Data(temp_board +1).Num_Cells;
                                temp_sum = temp_sum + obj.Board_Summary_Data(temp_board +1).Volt_Sum;
                            end
                            obj.Stack_Summary_Data.Temp_Max = temp_max;
                            obj.Stack_Summary_Data.Temp_Min = temp_min;
                            obj.Stack_Summary_Data.Temp_Max_Cell = cell_max;
                            obj.Stack_Summary_Data.Temp_Min_Cell = cell_min;
                            
                            
                            obj.temperature_timestamp(board_num +1) ...
                                = Update(obj, obj.temperature_timestamp(board_num +1), ...
                                temp_timestamp, temp_balancestamp);
                            
                            try
                                if obj.temperature_timestamp(board_num +1).time_difference > 4
                                    obj.num_times_over_4sec ...
                                        = obj.num_times_over_4sec + 1;
                                    obj.errLog.Add(Error_Code.USB_Delayed,...
                                        num2str(obj.temperature_timestamp(board_num +1)...
                                        .time_difference) + ":" + num2str(obj.num_times_over_4sec)); % #debugString=buffer
                                end
                                
                                if obj.temperature_timestamp(board_num +1).time_difference...
                                        > obj.max_time_difference
                                    obj.max_time_difference ...
                                        = obj.temperature_timestamp(board_num +1).time_difference;
                                end
                                
                            catch MEX
                                Handle_Exception(obj, MEX);
                            end
                        end
                        
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_PASSIVE_BALANCE_COMMAND
                    % Process the passive balancer data for one board
                    try
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            % If this is a board we don't know, then this is a failed response
                            obj.errLog.Add(Error_Code.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCodes.USB_PARSER_UNKNOWN_BOARD;
                        else
                            % get the passive balancer values
                            num_bytes = 4;
                            passive_balancer_bitmap = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                            
                            % *** If we got here, all of the data conversion was successful!  Copy from temporary to GUI variables
                            obj.Passive_Balancers(board_num +1) = passive_balancer_bitmap;
                        end
                        
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_CELL_PRESENT_COMMAND
                    try
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            % If this is a board we don't know, then this is a failed response
                            obj.errLog.Add(Error_Code.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCodes.USB_PARSER_UNKNOWN_BOARD;
                        else
                            % get the cell present values
                            num_bytes = 4;
                            cell_present_bitmap ...
                                = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                            
                            % If we got here, all data conversion were successful
                            for temp_num = 0:DC2100A.MAX_CELLS -1
                                if (cell_present_bitmap && 1) == 0
                                    obj.cellPresent(board_num +1, temp_num +1) = false;
                                else
                                    obj.cellPresent(board_num +1, temp_num +1) = true;
                                end
                            end
                        end
                        
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_TEMP_ADC_COMMAND
                    % Process the thermistor adc data for one board
                    % Looks like this command is just for displaying on the
                    % Mfg's GUI and isn't actually needed for functionality
                    % #ComeBack - Might need to come back here incase it is
                    % actually needed.
                    
                    try
                        adc_values = zeros(1, DC2100A.NUM_TEMPS);
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            % If this is a board we don't know, then this is a failed response
                            obj.errLog.Add(Error_Code.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCodes.USB_PARSER_UNKNOWN_BOARD;
                        else
                            % get the board temperature adc values
                            num_bytes = 4;
                            for temp_num = 0 : DC2100A.NUM_TEMPS - 1
                                adc_values(temp_num +1) = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                                index = index + num_bytes;
                            end
                            
                        end
                        
                        
                        
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_LTC3300_COMMAND
                    try
                        register = zeros(1, DC2100A.NUM_LTC3300);
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            obj.errLog.Add(Error_Code.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCodes.USB_PARSER_UNKNOWN_BOARD;
                        else
                            % get the number of bytes read
                            num_bytes = 1;
                            bytes_read = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                            
                            % get the command
                            num_bytes = 2;
                            command = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                            
                            if (command ~= LTC3300.Command.Read_Balance) ...
                                    && (command ~= LTC3300.Command.Read_Status)
                                % If this is some invalid LTC3300 command, then this is a failed response
                                status = USB_PARSER_UNSUCCESSFUL;
                            else
                                
                                % Add to the length to wait the number of data bytes actually in this response.
                                length = length + (bytes_read - 1) * 2;      % subtract the command byte, to add 2 ascii characters per register byte
                                ics_read = floor((bytes_read - 1) / 2);   % each ic requires 4 ascii bytes per register
                                
                                if (obj.buf_in.size < length)
                                    % If the full response has not been received, exit and wait for it without deleting anything from the buffer
                                    status = ErrorCode.USB_PARSER_NOTDONE;
                                else
                                    % Read bytes returned, if they're for 1 or 2 ICs
                                    for ic_num = 0 : ics_read - 1
                                        num_bytes = 4;
                                        register(ic_num +1) = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                                        index = index + num_bytes;
                                    end
                                end
                            end
                        end
                        
                        % *** If we got here, all of the data conversion was successful!
                        for ic_num = 0 : ics_read - 1
                            obj.LTC3300s(board_num +1, ic_num +1)...
                                .Set_Read_Register(command, register(ic_num +1));
                            if (obj.LTC3300s(board_num +1, ic_num +1).Get_Error == true)
                                % Output LTC3300 Error bits to log file
                                obj.errLog.Add(ErrorCode.LTC3300_Status, ...
                                    "Board: " + num2str(board_num) + ", IC: "...
                                    + num2str(ic_num) + ", Register " ...
                                    + dec2hex(register(ic_num), 4)); % #debugString=buffer
                            end
                        end
                        
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_TIMED_BALANCE_COMMAND
                    % Process the timed balance data for one board
                    try
                        balance_action = zeros(1, DC2100A.MAX_CELLS);
                        balance_timer = zeros(1, DC2100A.MAX_CELLS);
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            % If this is a board we don't know, then this is a failed response
                            obj.errLog.Add(Error_Code.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCodes.USB_PARSER_UNKNOWN_BOARD;
                        else
                            % get the board balance states
                            num_bytes = 4;
                            for cell_num = 0 : DC2100A.MAX_CELLS - 1
                                balancer_state = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                                
                                if balancer_state == 0
                                    balance_action(cell_num +1) ...
                                        = LTC3300.Cell_Balancer.BALANCE_ACTION.None;
                                elseif ((balancer_state && 0x8000) == 0)
                                    balance_action(cell_num +1) ...
                                        = LTC3300.Cell_Balancer.BALANCE_ACTION.Charge;
                                else
                                    balance_action(cell_num +1) ...
                                        = LTC3300.Cell_Balancer.BALANCE_ACTION.Discharge;
                                end
                                balance_timer(cell_num +1) ...
                                    = bitand(balancer_state, 0x7FFF) ...
                                    * LTC3300.Cell_Balancer.BALANCE_TIME_RESOLUTION;
                                index = index + num_bytes;
                            end
                            
                            % get the max balance time
                            num_bytes = 4;
                            max_time = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes))...
                                * LTC3300.Cell_Balancer.BALANCE_TIME_RESOLUTION;
                            index = index + num_bytes;
                            
                            % get the board with the max balance time
                            num_bytes = 2;
                            max_board = uint8(hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes)));
                            index = index + num_bytes;
                            
                            % get the min balance time
                            num_bytes = 4;
                            min_time = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes))...
                                * LTC3300.Cell_Balancer.BALANCE_TIME_RESOLUTION;
                            index = index + num_bytes;
                            
                            % get the board with the min balance time
                            num_bytes = 2;
                            min_board = uint8(hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes)));
                            index = index + num_bytes;
                            
                            % *** If we got here, all of the data conversion was successful!
                            for cell_num = 0 : DC2100A.MAX_CELLS -1
                                obj.Timed_Balancers(board_num +1, cell_num +1)...
                                    .bal_action = balance_action(cell_num +1);
                                
                                obj.Timed_Balancers(board_num +1, cell_num +1)...
                                    .bal_timer = balance_timer(cell_num +1);
                            end
                            obj.Min_Balance_Time_Value = min_time;
                            obj.Min_Balance_Time_Board = min_board;
                            obj.Max_Balance_Time_Value = max_time;
                            obj.Max_Balance_Time_Board = max_board;
                            
                        end
                        
                        % When balancing is complete, make it known throughout the GUI
                        % If voltage matching, let voltage matching algorithm end the balancing
                        if (obj.Max_Balance_Time_Value == 0)...
                                && (obj.isTimedBalancing == true)
                            Timed_Balance_Stop(obj, false, board_num);
                        end
                        
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_EEPROM_COMMAND
                    try
                        temp_eeprom_data = ...
                            struct('Capacity', zeros(DC2100A.MAX_CELLS, 1),...
                            'Charge_Currents', zeros(DC2100A.MAX_CELLS, 1),...
                            'Discharge_Currents', zeros(DC2100A.MAX_CELLS, 1));
                        
                        % get the board number
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        
                        if board_num < DC2100A.MAX_BOARDS
                            % get the eeprom item number
                            num_bytes = 1;
                            item_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                            
                            if item_num == DC2100A.EEPROM_Item_Type.Cap
                                length = length + (4 * DC2100A.MAX_CELLS);
                                if (obj.buf_in.size < length)
                                    status = ErrorCodes.USB_PARSER_NOTDONE;
                                else
                                    for temp_num = 0:DC2100A.MAX_CELLS -1
                                        num_bytes = 4;
                                        
                                        % Get Capacity
                                        temp_eeprom_data.Capacity(temp_num +1)...
                                            = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes))...
                                            / DC2100A.SOC_CAP_SCALE_FACTOR;
                                        index = index + num_bytes;
                                    end
                                end
                                
                            elseif item_num == DC2100A.EEPROM_Item_Type.Current
                                length = length + (4 * DC2100A.MAX_CELLS);
                                if (obj.buf_in.size < length)
                                    status = ErrorCodes.USB_PARSER_NOTDONE;
                                else
                                    for temp_num = 0:DC2100A.MAX_CELLS -1
                                        num_bytes = 2;
                                        
                                        % Get Charge Current Scale Factor
                                        cal_factor ...
                                            = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                                        current = obj.Board_ID_Data(board_num +1).Average_Charge_Current_6Cell ...
                                            + obj.Board_ID_Data(board_num +1).Average_Charge_Current_6Cell ...
                                            * cal_factor / DC2100A.CURRENT_SCALE_FACTOR;
                                        temp_eeprom_data.Charge_Currents(temp_num +1) = current;
                                        index = index + num_bytes;
                                        
                                        % Get Discharge Current Scale Factor
                                        cal_factor ...
                                            = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                                        current = obj.Board_ID_Data(board_num +1).Average_Discharge_Current_6Cell...
                                            + obj.Board_ID_Data(board_num +1).Average_Discharge_Current_6Cell...
                                            * cal_factor / DC2100A.CURRENT_SCALE_FACTOR;
                                        temp_eeprom_data.Discharge_Currents(temp_num +1) = current;
                                        index = index + num_bytes;
                                    end
                                end
                            end
                            
                            % If we got here, all data conversion were
                            % successful
                            if item_num == DC2100A.EEPROM_Item_Type.Cap
                                for temp_num = 0:DC2100A.MAX_CELLS -1
                                    
                                end
                            elseif item_num == DC2100A.EEPROM_Item_Type.Current
                                obj.EEPROM_Data(board_num).Capacity(temp_num +1)...
                                    = temp_eeprom_data.Capacity(temp_num +1);
                            else
                                status = ErrorCodes.USB_PARSER_UNKNOWN_EEPROM_ITEM;
                            end
                            
                        else
                            status =  ErrorCodes.USB_PARSER_UNKNOWN_BOARD;
                        end
                        status =  ErrorCodes.NO_ERROR;
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
            end
            
        end
        
        
        function [status, board_num] = Get_SystemOV(obj)
            for board_num = 0 : obj.numBoards -1
                if (obj.OV_Flags(board_num +1) ~= 0)
                    status = true;
                    return;
                end
            end
            status = false;
        end
        
        
        function [status, board_num] = Get_SystemUV(obj)
            for board_num = 0 : obj.numBoards -1
                if (obj.UV_Flags(board_num +1) ~= 0) || (obj.system_state ~= DC2100A.SYSTEM_STATE_TYPE.Awake)
                    status = true;
                    return;
                end
            end
            status = false;
        end
        
        
        function condition_string = Get_OVUV_Condition_String(obj, board_num)
            
            condition_string = "";
            
            % Figure out if it is an OV condition, an UV condition, or both.
            if (obj.OV_Flags(board_num +1) ~= 0)
                if ~strcmp(condition_string, "")
                    condition_string = condition_string + "/";
                end
                condition_string = condition_string + "OV";
            end
            
            if (obj.UV_Flags(board_num +1) ~= 0) ...
                    || (obj.system_state ~= DC2100A.SYSTEM_STATE_TYPE.Awake)
                if ~strcmp(condition_string, "")
                    condition_string = condition_string + "/";
                end
                condition_string = condition_string + "UV";
            end
        end
        
        
        function Timed_Balance_Stop(obj, reset, board_num)
            %  Flag that timed balancing is stopped
            obj.isTimedBalancing = false;
            obj.isBalancing = false;
            
            % Either reset or suspend the balancing operation
            if reset == false
                % Send the command for the selected DC2100A
                % Note that the whole system will suspend balancing.  The selected board is the only one that will reply with its balancing data for display, however.
                obj.buf_out.Add(DC2100A.USB_PARSER_TIMED_BALANCE_COMMAND + "S" + dec2hex(board_num, 2))
            else
                
                % Send the command for the selected DC2100A
                % Note that the whole system will end balancing.  The selected board is the only one that will reply with its balancing data for display, however.
                obj.buf_out.Add(DC2100A.USB_PARSER_TIMED_BALANCE_COMMAND + "E" + dec2hex(board_num, 2))
            end
            
            % todo - do we need to refresh data here or will the timed call be fine for it?
            ReadAllData(obj);
            
        end
        
        
        function ReadAllData(obj)
            % get strings to read the LTC3300 registers for the selected board
            for board_num = 0 : obj.numBoards -1
                obj.buf_out.Add(LTC3300_Raw_Read(obj, board_num, LTC3300.Command.Read_Balance));
                obj.buf_out.Add(LTC3300_Raw_Read(obj, board_num, LTC3300.Command.Read_Status));
            end
            
            % todo - the autoread stuff will need to change when FW is in control of streaming the data
            if obj.autoRead == false
                obj.buf_out.Add(DC2100A.USB_PARSER_VOLTAGE_COMMAND);
                obj.buf_out.Add(DC2100A.USB_PARSER_TEMPERATURE_COMMAND);
                %                 Temperature_Update_Flag = true; % #NeededNow???
                %                 Voltage_Update_Flag = true;
            end
            
        end
        
        
        function dataString = LTC3300_Raw_Write(obj, board_num, command, varargin)
            %LTC3300_Raw_Write  Returns the USB command to write to the LTC3300s on the selected board
            %   Input:
            %       obj         : DC2100A object. Can otherwise add it behind
            %                       function i.e. obj.LTC3300_Raw_Write(cmd, board_num)
            %       board_num   : board # from 0 to MAX Num of boards - 1 (9)
            %       command     : General LTC3300 Command value from the LTC3300 Class
            %       varargin    : Balancer Actions based on
            %                       LTC3300.Cell_Balancer.BALANCE_ACTION
            %                       in a vector ranging from
            %                       1 to (LTC3300.NUM_CELLS * DC2100A.NUM_LTC3300).
            %                       This input is only valid when command =
            %                       LTC3300.Command.Write_Balance.
            %                       Specify as a vector value only or a
            %                       name-value pair, where name is 'Actions'
            %                       or 'Bal_Actions'.
            %
            %   Output:
            %       dataString  : Command String written to the board containing
            %                       data to the LTC3300 Balancers on board.
            
            dataString = DC2100A.USB_PARSER_LTC3300_COMMAND + "W";
            
            % Send the board requested
            if (command == LTC3300.Command.Write_Balance)
                dataString = dataString + dec2hex(board_num, 2);
            elseif (command == LTC3300.Command.Execute) || (command == LTC3300.Command.Suspend)
                dataString = dataString + dec2hex(DC2100A.LTC6804_BROADCAST ,2);
            end
            
            
            %  Send number of bytes
            num_bytes = 1;
            if (command == LTC3300.Command.Write_Balance)
                for ic_num = 0 : DC2100A.NUM_LTC3300 -1
                    if obj.LTC3300s(board_num +1, ic_num +1).Enabled == true
                        num_bytes = num_bytes + 2;
                    end
                end
            end
            dataString = dataString + dec2hex(num_bytes, 1);
            
            % Send Command Byte
            dataString = dataString + command;
            
            % Send Balance Command
            if (command == LTC3300.Command.Write_Balance)
                if isarray(varargin{4})
                    bal_actions = varargin{4};
                elseif strcmpi(varargin{4}, "Actions") || strcmpi(varargin{4}, "Bal_Actions")
                    bal_actions = varargin{5};
                end
                
                for ic_num = (DC2100A.NUM_LTC3300 - 1) : -1 : 0
                    if obj.LTC3300s(board_num +1, ic_num +1).Enabled == true
                        dataString = dataString ...
                            + obj.LTC3300s(board_num +1, ic_num +1) ...
                            .Get_Write_Command(bal_actions(...
                            (ic_num* LTC3300.NUM_CELLS)+1 ...
                            : (ic_num +1)* LTC3300.NUM_CELLS));
                    end % End of if
                end
            end
            
        end
        
        
        function dataString = LTC3300_Raw_Read(obj, board_num, command)
            %LTC3300_Raw_Read  Returns the USB command to read from the LTC3300s on the selected board
            %   Input:
            %       obj         : DC2100A object. Can otherwise add it behind
            %                       function i.e. obj.LTC3300_Raw_Read(cmd, board_num)
            %       board_num   : board # from 0 to MAX Num of boards - 1 (9)
            %       command     : General LTC3300 Command value from the LTC3300 Class
            %
            
            dataString = DC2100A.USB_PARSER_LTC3300_COMMAND + "R";
            
            %  This is ugly, but if if the board isn't powered up the LTC3300 can not communicate so no point in trying
            if obj.system_state ~= DC2100A.SYSTEM_STATE_TYPE.Awake
                dataString = "";
                return
            end
            
            % Send the board requested
            dataString = dataString + dec2hex(board_num, 2);
            
            %  Send number of bytes
            num_bytes = 1;
            for ic_num = 0 : DC2100A.NUM_LTC3300 -1
                if obj.LTC3300s(board_num +1, ic_num +1).Enabled == true
                    num_bytes = num_bytes + 2;
                end
            end
            dataString = dataString + dec2hex(num_bytes, 1);
            
            % Send Command Byte
            dataString = dataString + command;
            
        end
        
        
        function timeVar = UpdateTimestamp(obj, timeVar, timestamp_new, is_balancing_new)
            %UpdateTimestamp Updates the voltage and temperature timers
            %based on new timestamps from DC2100A board
            %   Inputs:
            %       obj             : DC2100A object. Can otherwise add it behind
            %                           function i.e. obj.LTC3300_Raw_Read(cmd, board_num)
            %       timeVar         : timestamp struct for Voltage or
            %                           Temperature
            %       timestamp_new   : new timestamp from DC2100A in ms
            %       is_balancing_new: indication for balancer status (true
            %                           or false)
            
            if timeVar.time < 0
                % If this is first update, start at zero
                timeVar.timestamp_last = timestamp_new;
                timeVar.time = timestamp_new / DC2100A.MS_PER_SEC;
            else
                % Calculate the amount of time passed since last update, and add to counter
                if (timestamp_new >= timeVar.timestamp_last)
                    timestamp_difference = timestamp_new - timeVar.timestamp_last;
                else
                    timestamp_difference = DC2100A.SYSTEM_TIMER_TICKS_OVERFLOW + timestamp_new - timeVar.timestamp_last;
                end
                timeVar.time_difference = timestamp_difference / DC2100A.MS_PER_SEC;
                timeVar.time = timeVar.time + timestamp_difference / DC2100A.MS_PER_SEC;
            end
            
            timeVar.timestamp_last = timestamp_new;
            if is_balancing_new ~= 0
                timeVar.is_balancing = true;
            else
                timeVar.is_balancing = false;
            end
        end
        
        
        function timeVar = ResetTimestamp(obj, timeVar)
            %ResetTimestamp Resets the voltage and temperature timers
            %
            %   Inputs:
            %       obj             : DC2100A object. Can otherwise add it behind
            %                           function i.e. obj.LTC3300_Raw_Read(cmd, board_num)
            %       timeVar         : timestamp struct for Voltage or
            %                           Temperature
            
            timeVar.timestamp_last = 0;
            timeVar.time = -1;
            timeVar.is_balancing = false;
            
        end
        
        
        function timerStopped(obj, varargin)
           disp("USBTimer has stopped"); 
        end
        
        
        function Handle_Exception(obj, MEX, varargin)
            %Handle_Exception Used to catch and display exceptions on the
            %Error Log app
            %   Inputs:
            %       obj         : DC2100A object. Can otherwise add it behind
            %                       function i.e. obj.Handle_Exception(MEX, varargin)
            %       MEX         : If the function is being called anywhere 
            %                       in the program, this input will be a
            %                       Matlab EXception. Otherwise, if it is
            %                       being called by the USBTimer object,
            %                       then it is the Timer object.
            %       varargin    : If the USBTimer object is calling this
            %                       function, a struct of exceptions will
            %                       be recieved through varargin{1}.
            %
            
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
                timerObj = MEX; % Receive the USBTimer object since it is not a MEX
                MEXstruct = varargin{1};
                MEX = MEXstruct.Data; % Receive the actaul MEX data from varargin
                
                mexStr = newline + string(char(9)) + string(MEX.message) + newline;
                mexStr = mexStr + char(9) ...
                    + sprintf("Error while evaluating %s for timer '%s'", MEXstruct.Type, timerObj.Name);
                mexStr = mexStr + newline + char(9); % char(9) = \tab
            end
            
            obj.errLog.Add(ErrorCode.EXCEPTION, mexStr); % Show the exception on the Error Logger app
        end
        
    end
    
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % PUBLIC METHODS
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    methods
        
        function obj = DC2100A(COMport, errLogApp, varargin)
            %DC2100A Initiates an instance of DC2100A class that takes
            %the COM port or serial object as an argument.
            %   This Constructor creates a generic serial object with
            %   Baudrate = 115200, DataBits = 8, Parity = 'none',
            %   StopBits = 1, and Terminator = 'LF'.
            %   port = 'COM#' (String)
            %
            %   Inputs:
            %       COMport         : Serial COMM Port e.g 'COM4' or 'COM6'
            %       errLogApp       : ErrorLog App object. This should be 
            %                           activated outside this class by 
            %                           running "app = ErrorLog;" and
            %                           passing "app" as errLogApp.
            %       varargin        : Name-Value pairs of input consisting
            %                           of only the following:
            %                           - 'USB_ASYNC' ,true / [false]
            %                           
            
            % Varargin Evaluation
            % Code to implement user defined values
            param = struct(...
                'USB_ASYNC',        false);
            
            % read the acceptable names
            paramNames = fieldnames(param);
            
            % Ensure variable entries are pairs
            nArgs = length(varargin);
            if round(nArgs/2)~=nArgs/2
                error('DC2100A Class needs propertyName/propertyValue pairs')
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
            
            
            tic;
            
            obj.USB_Async_Flag = param.USB_ASYNC;
            
            if obj.USB_Async_Flag == true 
                if isempty(gcp('nocreate'))
                    obj.USBPool = parpool(obj.USBPoolSize);
                else
                    obj.USBPool = gcp('nocreate');
                end
            end
            
            serialAvail = serialportlist("available"); % Get all serial ports currently available
            if ~(ismember(COMport, serialAvail))
                warning(COMport + " is not available. Ensure MCU is"...
                    + " connected or confirm COM port." + newline + ...
                    "Available COM ports are: ");
                disp(serialAvail)
                
                list = serialAvail;
                [indx,~] = listdlg('ListString',list,...
                    'PromptString','Select a COM Port:', ...
                    'SelectionMode','single', ...
                    'OKString','Apply', ...
                    'ListSize',[200,250]);
                if isempty(indx)
                    return;
                end
                obj.port = ports(indx);
            end
            
            obj.errLog = errLogApp;
            
            setUSBDataSizes(obj);
            
            obj.baudRate = 115200;
            obj.port = COMport;
            obj.byteOrder = "big-endian";
            obj.terminator = "LF";
            obj.stopbits = 1;
                        
            
            obj.serial = serialport(obj.port, obj.baudRate);
            obj.serial.ByteOrder = obj.byteOrder;
%             flush(obj.serial); % Remove any random data in the serial buffer
            %             pause(DC2100A.READ_TIMEOUT/1000);
            %             configureCallback(obj.serial, "byte", 1 ,@obj.USBDataIn_Callback)
            configureCallback(obj.serial, "terminator" ,@obj.USBDataIn_Callback)
            obj.USBTimer = timer;

            
            % Check to see that the MCU has the correct FW
            [status, helloStr] = getHelloStr(obj);
            if status == ErrorCode.COMMTEST_DATA_MISMATCH
                error("There has been a data mismatch when testing communication with FW.");
            elseif status == ErrorCode.UNKNOWN_ERROR
                error("MCU doesn't seem to be loaded with the correct FW.");
            elseif status == ErrorCode.COMM_TIMEOUT
                error("There has been a COMM Timeout error. Perhaps FW on MCU is not correct or running?");
            else
                disp("MCU FW Confirmed. Test String = '" + helloStr + "'");
            end
            
            % Check to see if the DC2100A board is connected
            [status, ModelNum] = getModelNum(obj);
            if status == ErrorCode.COMMTEST_DATA_MISMATCH
                error("There has been a data mismatch when testing communication with FW.");
            elseif status == ErrorCode.COMM_DC2100A_NOT_DETECTED
                error("The **DC2100A BOARD** is either not connected or not communicating.");
            else
                disp("Model Num Confirmed. Test String = '" + ModelNum + "'");
                obj = System_Init(obj, true);
            
%                 obj.USBTimer.ExecutionMode = 'fixedRate';
%                 obj.USBTimer.Period = DC2100A.USB_COMM_TIMER_INTERVAL / DC2100A.MS_PER_SEC;
%                 obj.USBTimer.StartDelay = 2;
%                 obj.USBTimer.TasksToExecute = 2;
%                 obj.USBTimer.StopFcn = @obj.timerStopped;
%                 obj.USBTimer.TimerFcn = @obj.USBDataOut_Timer_Callback;
%                 obj.USBTimer.ErrorFcn = {@obj.Handle_Exception, []};
%                 
%                 start(obj.USBTimer);
            end
        end
        
        
        function obj = selectBoard(obj, board_num)
            %selectBoard Selects board in the case where there is more
            %than 1 board.
            %   This functions allows the user to set the selectedBoard variable
            if(board_num < obj.numBoards - 1)
                obj.selectedBoard = board_num;
            else
                obj.errLog.Add(Error_Code.USB_PARSER_UNKNOWN_BOARD,...
                    "Board: " + num2str(board_num),...
                    ". The selected board is not available or invalid.");
            end
        end
        
        
        function sendHelloCmd(obj)
            write(obj.serial,DC2100A.USB_PARSER_HELLO_COMMAND,"char");
        end
        
        
        function [status, helloStr] = getHelloStr(obj)
            %getHelloStr Gets a test string: "Hello" from DC2100A FW on MCU
            helloStr = "";
            index = 1;
            num_bytes = 6;
            [status, data] = readData(obj, DC2100A.USB_PARSER_HELLO_COMMAND, num_bytes);
            if (status == ErrorCode.UNKNOWN_ERROR || status == ErrorCode.COMM_TIMEOUT)
                return; end
            
            helloStr = data(index:num_bytes-1); % remove the newline character
            charHelloStr = char(DC2100A.HELLOSTRING);
            if(strcmp(helloStr, charHelloStr(index:num_bytes-1)))
                status = ErrorCode.NO_ERROR;
            else
                status = ErrorCode.COMMTEST_DATA_MISMATCH;
            end
        end
        
        function [status, ModelNum] = getModelNum(obj)
            %getModelNum Gets the MFG Data from the board
            ModelNum = "";
            key = DC2100A.USB_PARSER_MFG_COMMAND; 
            if(isKey(obj.USB_Parser_Response_DataSize, key))
                num_bytes = obj.USB_Parser_Response_DataSize(key);
            else
                error("Unrecognized Command. Key '" + key + "' Not Found");
            end
            
            [status, data] = readData(obj,...
                DC2100A.USB_PARSER_MFG_COMMAND + "R"...
                + dec2hex(DC2100A.NUCLEO_BOARD_NUM, 2), num_bytes+1); % +1 is for the newline sent after message
            if (status == ErrorCode.UNKNOWN_ERROR) || status == ErrorCode.COMM_TIMEOUT
                return; end
            
            index = 4;
            num_bytes = strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT);
            
            ModelNum = data(index:index + num_bytes-1); % remove the newline character
            charModelNum = char(DC2100A.DC2100A_MODEL_NUM_DEFAULT);
            
            % Compare the last characters on sent and saved model number,
            % if they are similar (i.e: "?") DC2100A is not connected or
            % communicating
            if(strcmp(ModelNum(end-1:end), charModelNum(end-1: end)))
                status = ErrorCode.COMM_DC2100A_NOT_DETECTED;
            else
                status = ErrorCode.NO_ERROR;
            end
        end
        
        
        function [status, OV, UV] = get_OVUV(obj, boardNum)
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
            [status, data] = readData(obj, cmd, numBytes2Read);
            if (status == false)
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
            s = inputname(1);
            if strcmpi(obj.USBTimer.Running, 'on')
                stop(obj.USBTimer);
            end
            disp("NumBytesAvail = " + obj.serial.NumBytesAvailable)
          	delete(obj.USBTimer);
            flush(obj.serial);
            evalin('base', [['clear '], s ,';']);
        end
        
    end
    
    
end


