classdef DC2100A < handle
    %DC2100A class handles control and data recording for the DC2100A
    %12-cell demo balancing board  from Analog Devices.
    %   This class uses the serial interface (USB) to send commands and
    %   receive data from the DC2100A Board. 
    %   
    %   This class is capable of balancing on multiple boards (NOT TESTED),
    %   read balancing status and commands back from each board, read
    %   measured voltage and temperature data. 
    %
    %   Although the board has passive balancing capabilities, it has not
    %   be implemented in Rev_01 of this file.
    %
    %   As of Rev_01, this file is has the following dependencies:
    %       - "LTC3300.m"       => Contains specific commands and constants 
    %                                for each LTC3300 IC on each board.
    %       - "ErrorCode.m"     => This file is a enumeration class for the
    %                               multiple error possibilities that can 
    %                               occur in this class.
    %       - "ErrorLog.mlapp"  => This is an application that displays/logs
    %                               the errors that occur in the FW or in
    %                               this SW class program. This application
    %                               is needed as an input for creating an
    %                               object of this class. Therefore, it has
    %                               to be started by code and the object
    %                               should be passed while defining the
    %                               class object.
    %                               Start it using the following code:
    %                                >> app = ErrorLog;
    %
    %  Defining an object for the class:
    %       (1) Start the Error Logger in the command window or in another 
    %           script in matlab
    %           >> app = ErrorLog;
    %
    %       (2)Pick a serial COMport. To do so, find it in the device
    %           manager in windows. We'll be using 'COM6' in this case.
    %
    %       (3) Define the class object in the command window or in another 
    %           script in matlab
    %           >> bal = DC2100A('COM6', app);
    %           
    %           If the number of cells on each board is known and connected
    %           according to the procedure documented on the DC2100A
    %           manual, then add them as arguments like so:
    %           
    %           >> bal = DC2100A('COM6', app, 'Num_Cells', 4);
    %           
    %           The above specified 4 cells are connected to ALL boards 
    %           in the chain/stack. 
    %           ** Note that the boards themselves are automatically
    %           detected as long as they're connected correctly. **
    %               
    %           Default value for the 'Num_Cells' input is 4.
    %           
    %           ******** Note that this library has not yet been fully 
    %           ******** implemented for more than 1 board. 
    %
    %
    %           ******** Also Note, when selecting or specifying 
    %           ******** boards or cells, their list of IDs MUST begin 
    %           ******** with 0 (zero) for the first in the group. 
    %           ******** i.e. first/primary board & cell are 
    %           ******** board 0 and cell 0 followed by board 1 and cell 1
    %           ******** and so on.
    %    
    %   To only disconnect and dispose the serial interface run the 
    %   following function in the command window or the matlab script:
    %       >> disconnectSerial(bal);
    %
    %   To disconnect the serial interface and dispose the DC2100A object run the 
    %   following function in the command window or the matlab script:
    %       >> disconnect(bal);
    %   
    %   Note that the moment the object is defined, the code starts
    %   communicating with the MCU connected to the board.
    %
    % ####################       Change Log       #########################
    %----------------------------------------------------------------------
    % REVISION	DATE-YYMMDD  |  CHANGE                                      
    %----------------------------------------------------------------------
    % 00        200501          Initial Release
    % 01        200505          Fixed Bug with unavailable serial port
    %
    
     
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % CONSTANT PROPERTIES
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    properties (Constant)
       
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
        MAX_BOARDS = 8;                         % The maximum number of boards that can be in a DC2100A system (note that LTC6804_MAX_BOARDS <> MAX_BOARDS due to RAM limitations in the PIC) #Changed - Value to 8 from 10 in LTC GUI
        MAX_CELLS = 12;
        MIN_CELLS = 4;
        NUM_TEMPS = 12;
        NUM_LTC3300 = 2;
        ALL_BOARDS = DC2100A.MAX_BOARDS;
        ALL_CELLS = DC2100A.MAX_CELLS;
        ALL_ICS = DC2100A.NUM_LTC3300;
        
        % ########------------------------------------------------
        % DC2100A USB Communication Section
        % ########------------------------------------------------
        
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
        USB_PARSER_EMERGENCY_STOP_COMMAND = 'z'   % Actuate Emergency Stop .
        
        % Dictionary used to wait for the proper number of characters before attempting to process the communication, without just throwing it away.
        DC2100A_MODEL_NUM_DEFAULT = "DC2100A-?";
        DC2100A_SERIAL_NUM_DEFAULT = "None             ";
        APP_FW_STRING_DEFAULT = "N/A        ";
        HELLOSTRING = "Hello ";
        DC2100A_IDSTRING = "DC2100A-A,LTC3300-1 demonstration board";
        USB_PARSER_DEFAULT_STRING = "Not a recognized command!";
        
        NUCLEO_BOARD_NUM = 0; % It makes a lot of things simpler if the board connected to the MCU always has the same address.
        
        ERROR_DATA_SIZE = 12;
        
        % For scaling data gotten from eeprom data
        SOC_CAP_SCALE_FACTOR = 128;
        CURRENT_SCALE_FACTOR = 256;
        
        READ_TIMEOUT = 100; % USB Read Timeout
             
        % End of DC2100A USB Communication Section
        % ########------------------------------------------------
        
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
            'NUCLEO_Board_Init'  , 1, ...
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
        VOLTAGE_MAX_LIMIT = 4.7;
        VOLTAGE_MIN_LIMIT = 2.2;
        
        % *** Temperature Display
        TEMPERATURE_RESOLUTION = 1; % °C per bit
        TEMPERATURE_MAX = 160; % °C per bit
        TEMPERATURE_MIN = -56; % °C per bit
        
        % Balance Algorithm Constants
        MA_PER_A = 1000; % Convert Amps to mAmps
        
    end
      
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % PRIVATE PROPERTIES
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    properties (SetAccess  = private)
        % USB Data buffers (User Level)
        buf_out = javaObject('java.util.LinkedList'); % List for accumulating responses to USB
        buf_in = javaObject('java.util.LinkedList'); % Buffer for accumulating responses from USB
        buf_dropped = ''; % Buffer for accumulating incomplete data from USB for subsequent RX  
        
        useUSBTerminator = true; % Should the newline terminator be used to receive data from serial?
                
    end
    
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % PUBLIC PROPERTIES
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    properties
        eventLog      % Property that the error log handle is stored.
        
        serial      % Property that the serial port handle is created. 
        baudRate    % Serial Port Property. Stores the baudrate e.g 115200
        port        % Serial Port Property. Stores the port name e.g COM6
        byteOrder   % Serial Port Property. Stores the byte order e.g MSB
        terminator  % Serial Port Property. Stores the terminator used e.g LF
        dataBits    % Serial Port Property. How many data bits per byte e.g 8
        stopbits    % Serial Port Property. e.g 1
        
        
        
        % ########------------------------------------------------
        % Board Data - Such as system variables or measured data
        % ########------------------------------------------------
        
        system_state % DC2100A Property. Stores the current state of the board
        
        numBoards = 0; % The number of boards currently connected
        numCells = 0;
        selectedBoard = 0; % The board in focus or the board that is being communicated to

        board_address_table = zeros(1, DC2100A.LTC6804_MAX_BOARDS); % A table of addresses set by A0 to A3 on the DC2100A board
        
        
        Board_ID_Data = repmat(struct... % Some board data useful for identification etc
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
        
        
        EEPROM_Data = repmat(... % Data stored in the EEProm of each board. Includes Calibration data
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
        
        temperature_timestamp  % temperature timestamp variable. Initialized in "System_Init()"
        max_time_difference = 0;
        num_times_over_4sec = 0;
        
        
        %  *** Summary of Board and Stack Voltages and Temperatures Display
        %  Stack is a string of boards
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
        
        Board_Summary_Data % Summary for each board. Initialized in "System_Init()"
        
        %  *** Cell Level Data
        cellPresent % Array of true/false elements indicating if cells from boards are plugged in
        Voltages = zeros(DC2100A.MAX_BOARDS, DC2100A.MAX_CELLS); % Container to store the most recently measured VOLTAGE of each cell on each board
        Currents = zeros(DC2100A.MAX_BOARDS, DC2100A.MAX_CELLS); % Container to store the most recently measured VOLTAGE of each cell on each board
        Temperatures = zeros(DC2100A.MAX_BOARDS, DC2100A.MAX_CELLS); % Container to store the most recently measured TEMPERATURE of each thermistor on each board
        OV_Flags = zeros(1,DC2100A.MAX_BOARDS); % Array of true/false values indicating if the boards connected have OV conditions
        UV_Flags = zeros(1,DC2100A.MAX_BOARDS); % Array of true/false values indicating if the boards connected have UV conditions
        vMax % Current setting for maximum voltage threshold
        vMin % Current setting for minimum voltage threshold
        
        
        % *** Balancer Controls
        LTC3300s = []; % Array of LTC3300 Balancers objects for the max amount of boards
        Timed_Balancers = repmat(struct('bal_action', 0, 'bal_timer', 0),...
            DC2100A.MAX_BOARDS, DC2100A.MAX_CELLS);
        Passive_Balancers = zeros(1, DC2100A.MAX_BOARDS); % Not implemented yet since not needed.
        Min_Balance_Time_Value = 0;
        Min_Balance_Time_Board = 0;
        Max_Balance_Time_Value = 0;
        Max_Balance_Time_Board = 0;
        isBalancing = false;
        isTimedBalancing = false;
        
        % End of Board Data Section
        % ########------------------------------------------------
        
        
        % ########------------------------------------------------
        % COMM Variables - USB flags, timer variables, Parsing commands/dataLengths 
        % and condition variables for communication
        % ########------------------------------------------------
        
        %  *** Variables to control rate at which commands are sent and responses are received
        USB_Comm_Can_Send = true;   % TRUE if allowed to send data to pipe
        USB_Comm_Can_Receive = true;
        
        % Variables to contain responses from before they are parsed
        USB_Parser_Buffer_In                           % Buffer for accumulating responses from USB
        USB_Parser_Buffer_Dropped                      % Buffer for accumulating characters dropped from USB
        
        USB_Comm_Cycle_Counter = 0;
        USB_Comm_Cycle_Counter_Period = DC2100A.USB_COMM_CYCLE_PERIOD_DEFAULT;
        
        % Variables to contain commands that are sent to the boards
        % #todo - some kind of timeout between sending commands and getting responses would be great, but the underlying system doesn't account for this easily.
        USB_Comm_List_Out_Count_This_Cycle = 0;            % Variable to track how many commands were sent in this comm cycle
        USB_Comm_List_Out_Count_Per_Cycle_Max = 0;         % Variable to track the maximum number of commands sent in a comm cycle
        USB_Parser_Response_DataLengths = containers.Map;

        autoRead = true;
        Temperature_ADC_Test = false;
        
        % End of COMM Variables section
        % ########------------------------------------------------
        
        % *** Async Communcation variables - Not Implemented. Might not need it
        USBPool
        USBPoolSize = 1;
        USBPool_FOut % = parallel.FevalFuture;
        USB_Async_Flag = false;
        
        
        %  *** Timer Object
        USBTimer
        
        sTime_MPC = 1;
        Val = 0;
    end

    
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % STATIC METHODS
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
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
        
        function ADD_RANGE(buf, arr, startInd, endInd)
            %ADD_RANGE Adds multiple elements from an array range to a linkedlist
            %   Inputs:
            %       buf         : Java LinkedList
            %       arr         : Matlab Array
            %       startInd    : Starting [including] index of array "arr"
            %       endInd      : Ending [including] index of array "arr"
            %       
            %       e.g ADD_RANGE(buf, [1,2,3, 4], 2, 4) = {2, 3, 4}
            %       
            %   Outputs:
            %   
            
            for i = startInd : endInd
                buf.add(arr(i));
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
%                 obj.LTC3300s = repmat(...
%                     LTC3300(0, obj.eventLog),...
%                     DC2100A.MAX_BOARDS, DC2100A.NUM_LTC3300); % Array of the LTC3300 Class
%                 
%                 for board_num = 0 : DC2100A.MAX_BOARDS -1
%                     for ic_numVal = 0 : DC2100A.NUM_LTC3300 -1
%                         % Group together the IC level status bits for this LTC3300
%                         obj.LTC3300s(board_num +1, ic_numVal +1).ic_num = ic_numVal;
%                     end
%                 end

                ic_IDs = [zeros(DC2100A.MAX_BOARDS, 1), ones(DC2100A.MAX_BOARDS, 1)];
                for i = 1 : DC2100A.MAX_BOARDS * DC2100A.NUM_LTC3300
                    LTC_Bal(i) = LTC3300(ic_IDs(i), obj.eventLog);
                end
                obj.LTC3300s = reshape(LTC_Bal, DC2100A.MAX_BOARDS, DC2100A.NUM_LTC3300);
                                
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
                
                obj.Board_Summary_Data = repmat(obj.Stack_Summary_Data,...
                    1, DC2100A.MAX_BOARDS);
                
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
                
                
            catch MEX
                Handle_Exception(obj, MEX);
            end
            
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
                if obj.useUSBTerminator == true
                    data = char(readline(obj.serial));
                else
                    data = read(obj.serial, dataLen ,"char");
                end
                status = ErrorCode.NO_ERROR;
                % Turn USB Callback on again
                
                if obj.useUSBTerminator == false
                    configureCallback(obj.serial, "byte", obj.serial.NumBytesAvailable ,@obj.USBDataIn_Callback)
                elseif obj.useUSBTerminator == true
                    configureCallback(obj.serial, "terminator" ,@obj.USBDataIn_Callback)
                end
                
            catch MEX
                Handle_Exception(obj, MEX);
                status = ErrorCode.UNKNOWN_ERROR;
            end
        end
        
        
        function setUSBDataSizes(obj)
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_MFG_COMMAND)...
                = 1 + (1 * 2) + strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT) ...
                + 1 + strlength(DC2100A.DC2100A_SERIAL_NUM_DEFAULT) ...
                + (4 * 2 * 2) + strlength(DC2100A.APP_FW_STRING_DEFAULT);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_SYSTEM_COMMAND)...
                = 1 + (1 * 2) + (DC2100A.MAX_BOARDS * 1 * 2) + (2 * 2) ...
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
                = strlength(DC2100A.HELLOSTRING) - 1;
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_IDSTRING_COMMAND)...
                = strlength(DC2100A.DC2100A_IDSTRING);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_DEFAULT_COMMAND) ...
                = strlength(DC2100A.USB_PARSER_DEFAULT_STRING);
            
            obj.USB_Parser_Response_DataLengths(DC2100A.USB_PARSER_EMERGENCY_STOP_COMMAND) ...
                = 1;
        end
        
        
        function USBDataOut_Timer_Callback(obj, varargin)
%             xx = tic;
            dataString = "";
            % If we're able to send more commands, send them.
            % Don't send we are expecting the DC2100A to enter the bootloader, however, or if we're in the middle of asking if they want to enter the bootloader.
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
                        if obj.isBalancing == true % If Balancing, poll data from the Balancers
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
                        write(obj.serial, dataString, "char"); % Pass the string to write
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
%             obj.count = obj.count+1;
%             disp("Count " + obj.count + ": " + num2str(toc(xx)) + "ms");    

            % Print Voltages every 1s
%             if obj.Val == 50
%                 ind = 1:DC2100A.MAX_CELLS; s="";
%                 for i = ind(logical(obj.cellPresent(1, :)))
%                     s = s+sprintf("Volt[%d] = %.4f\t", i, obj.Voltages(1, i));
%                 end
%                 fprintf(s + newline);
%                 obj.Val = 0;
%             else
%                 obj.Val = obj.Val + 1;
%             end

        end
        
        
        % The inputs are required and passed in by the configureCallback function
        function USBDataIn_Callback(obj, s, ~)
            %USBDataIn_Callback Callback when data available in serial
            %buffer is available
            
            if obj.USB_Comm_Can_Receive == true
                obj.USB_Comm_Can_Receive = false;
                if strcmpi(s.BytesAvailableFcnMode, "byte")
                    USB_In = read(s, s.NumBytesAvailable, "char");
                    USBDataIn_Parser(obj, USB_In);
                elseif strcmpi(s.BytesAvailableFcnMode, "terminator")
                    USB_In = char(readline(s));
                    USBDataIn_Parser(obj, USB_In);
                end
                
                obj.USB_Comm_Can_Receive = true;
            end
        end
        
        
        function USBDataIn_Parser(obj, new_data)
            %USBDataIn_Parser Parses String data input from serial buffer
            %to workable values
            %   Inputs: 
            %       obj             : DC2100A object. Can otherwise 
            %                           add it behind function i.e. 
            %                           obj.USBDataIn_Parser(new_data)
            %       new_data        : String of data received from the USB 
            %                           serial buffer. The string must have
            %                           a key containing a command. The
            %                           subsequent data is then parsed.
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
                        [status, response_length] = USB_Process_Response(obj, response_length);
                        ind = ind + response_length;
                        
                        % Check the status for errors
                        if status == ErrorCode.NO_ERROR
                        elseif status == ErrorCode.USB_PARSER_NOTDONE
                            obj.eventLog.Add(ErrorCode.USB_PARSER_NOTDONE,...
                                "Parser could not finish while parsing '" + key + "'");
                        end
                    else
                        % Or else, pretend to store the remaining data by 
                        % incrementing the "ind" variable so we can keep 
                        % track of the input data
                        ind = ind + (length(new_data) - ind);
                    end
                else
                    % Save the characters that were dropped, and write them into the Error log at the next good transaction.
                    obj.USB_Parser_Buffer_Dropped = obj.USB_Parser_Buffer_Dropped + obj.buf_in.remove;
                    if strlength(obj.USB_Parser_Buffer_Dropped) > DC2100A.USB_MAX_PACKET_SIZE
                        obj.eventLog.Add(ErrorCode.USB_DROPPED, obj.USB_Parser_Buffer_Dropped);
                        obj.USB_Parser_Buffer_Dropped = "";
                    end
                    ind = ind + 1;
                end
            end
        end
        
        
        function [status, length] = USB_Process_Response(obj, length)
            %USB_Process_Response Converts String to the required data
            %based on the initial command to the string
            switch (obj.buf_in.peek())
                
                case DC2100A.USB_PARSER_HELLO_COMMAND
                    helloStr = DC2100A.REMOVE_LEN(obj.buf_in, length);
                    helloStr = helloStr(1:end-1); % remove the newline character
                    charHelloStr = char(DC2100A.HELLOSTRING);
                    if(strcmp(helloStr, charHelloStr(1:length-1)))
                        status = ErrorCode.NO_ERROR;
                        if isvalid(obj.USBTimer)
                            if strcmpi(obj.USBTimer.Running, 'off')
                                % Restart COMM out timer if it was
                                % initially stopped
                                start(obj.USBTimer);
                            end
                        end
                    else
                        obj.eventLog.Add(ErrorCode.COMMTEST_DATA_MISMATCH,...
                            "Did not receive Hello String from MCU.");
                        status = ErrorCode.COMMTEST_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_IDSTRING_COMMAND
                    status = ErrorCode.NO_ERROR;
                    obj.buf_in.remove; % Remove the command or first character
                    string1 = DC2100A.REMOVE_LEN(obj.buf_in,...
                        strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT));
                    string2 = char(DC2100A.DC2100A_IDSTRING);
                    string2 = string2(1:...
                        strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT));
                    if (strcmp1(string1, string2))
                        obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_IDSTRING,...
                            "Unknown ID String received by MCU.");
                        status = ErrorCode.USB_PARSER_UNKNOWN_IDSTRING;
                    end
                    
                    string1 = DC2100A.REMOVE_LEN(obj.buf_in,...
                        length - strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT));
                    string2 = DC2100A.DC2100A_IDSTRING(...
                        strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT):...
                        length - strlength(DC2100A.DC2100A_MODEL_NUM_DEFAULT));
                    
                    if (strcmp1(string1, string2))
                        obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_IDSTRING,...
                            "Unknown ID String received by MCU.");
                        status = ErrorCode.USB_PARSER_UNKNOWN_IDSTRING;
                    end
                    
                case DC2100A.USB_PARSER_DEFAULT_COMMAND
                    status = ErrorCode.NO_ERROR;
                    if (DC2100A.REMOVE_LEN(obj.buf_in, length) ...
                            ~= DC2100A.USB_PARSER_DEFAULT_STRING)
                        obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_COMMAND,...
                            "Unknown command received by MCU.");
                        status = ErrorCode.USB_PARSER_UNKNOWN_COMMAND;
                    end
                    
                case DC2100A.USB_PARSER_BOOT_MODE_COMMAND % #Scrapping - Not Needed
                    
                case DC2100A.USB_PARSER_ERROR_COMMAND
                    try
                        status = ErrorCode.NO_ERROR;
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
%                         temp_error_data
                        
                        % *** If we got here, all data conversion were successful
                        
                        % Create error log entry
                        switch(temp_error_num)
                            case DC2100A.FW_ERROR_CODE.LTC6804_CRC
                                error_string = ...
                                    "Board: " + num2str(temp_error_data(1))...
                                    + ", Command: " + dec2hex(bitshift(temp_error_data(2), 8) + temp_error_data(3), 4)...
                                    + ", Bytes: ";
                                for byte_num = 4:DC2100A.ERROR_DATA_SIZE
                                    error_string = error_string ...
                                        + dec2hex(temp_error_data(byte_num), 2) + ", ";
                                end
                                obj.eventLog.Add(ErrorCode.LTC6804_CRC, error_string, num2str(obj.Board_Summary_Data(temp_error_data(1)).Volt_Sum, 5)); % 5 here ensures 5 sig figs
                                
                            case DC2100A.FW_ERROR_CODE.LTC3300_CRC
                                error_string = ...
                                    "Board: " + num2str(temp_error_data(1))...
                                    + ", IC: " + num2str(temp_error_data(2))...
                                    + ", Command: " + dec2hex(temp_error_data(3), 2)...
                                    + ", Bytes: ";
                                for byte_num = 4:DC2100A.ERROR_DATA_SIZE
                                    error_string = error_string ...
                                        + dec2hex(temp_error_data(byte_num), 2) + ", ";
                                end
%                                 disp("temp_error_data(1) = " + num2str(temp_error_data(1)));
%                                 disp("Size of Board_Summary_Data: " + num2str(length(obj.Board_Summary_Data)));
%                                 disp("num err = " + num2str(obj.Board_Summary_Data(temp_error_data(1) +1).Volt_Sum, 5))
                                obj.eventLog.Add(ErrorCode.LTC3300_CRC, error_string,...
                                    "Volt_Sum: " + num2str(obj.Board_Summary_Data(temp_error_data(1) +1).Volt_Sum, 5) + "V"); % 5 here ensures 5 sig figs
                                
                            case DC2100A.FW_ERROR_CODE.LTC6804_FAILED_CFG_WRITE
                                error_string = ...
                                    "Board: " + num2str(temp_error_data(1))...
                                    + ", Test_Value_VUV: " + num2str(bitshift(temp_error_data(2), 8) + temp_error_data(3))...
                                    + " : " + num2str(bitshift(temp_error_data(4), 8) + temp_error_data(5))...
                                    + ", Test_Value_VOV: " + num2str(bitshift(temp_error_data(6), 8) + temp_error_data(7))...
                                    + " : " + num2str(bitshift(temp_error_data(8), 8) + temp_error_data(9));
                                
                                obj.eventLog.Add(ErrorCode.LTC6804_Failed_CFG_Write, error_string);
                                
                            case DC2100A.FW_ERROR_CODE.LTC6804_ADC_CLEAR
                                error_string = ...
                                    "Board: " + num2str(temp_error_data(1))...
                                    + " failed to start ADC conversion.";
                                fail_timestamp = bitshift(temp_error_data(2), 24) + bitshift(temp_error_data(3), 16) + bitshift(temp_error_data(4), 8) + temp_error_data(5);
                                
                                obj.eventLog.Add(ErrorCode.LTC6804_ADC_CLEAR, error_string, fail_timestamp);
                                
                            case DC2100A.FW_ERROR_CODE.LTC3300_FAILED_CMD_WRITE
                                error_string = ...
                                    "Board: " + num2str(temp_error_data(1))...
                                    + " failed to write balance command."...
                                    + ", write value:" + dec2hex(bitshift(temp_error_data(2), 16) + bitshift(temp_error_data(3), 8) + temp_error_data(4) , 4)...
                                    + ", read value:" + dec2hex(bitshift(temp_error_data(5), 16) + bitshift(temp_error_data(6), 8) + temp_error_data(7) , 4);
                                
                                obj.eventLog.Add(ErrorCode.LTC3300_FAILED_CMD_WRITE, error_string, num2str(obj.Board_Summary_Data(temp_error_data(1)).Volt_Sum, 5)); % 5 here ensures 5 sig figs
                                
                            otherwise
                                error_string = "Bytes: ";
                                for byte_num = 1:DC2100A.ERROR_DATA_SIZE
                                    error_string = error_string ...
                                        + num2str(temp_error_data(byte_num)) + ", ";
                                end
                                obj.eventLog.Add(ErrorCode.LTC3300_CRC, error_string);
                        end
%                         disp(num2str(toc - obj.count) + "ms");
%                         obj.count = toc;
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_UVOV_COMMAND
                    try
                        status = ErrorCode.NO_ERROR;
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
                            obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCode.USB_PARSER_UNKNOWN_BOARD;
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
                                if (((system_ov_last == false) && (obj.Get_SystemOV() == true)) || ...
                                        ((system_uv_last == false) && (obj.Get_SystemUV() == true)))
                                    
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
                                        obj.eventLog.Add(ErrorCode.OVUV,...
                                            "Board: " + num2str(board_num)...
                                            + " " + condition_string + ". Flags = "...
                                            + dec2hex(temp_ov_flags, 3) + dec2hex(temp_uv_flags, 3));
                                    else
                                        obj.eventLog.Add(ErrorCode.OVUV,...
                                            "Board: " + num2str(board_num)...
                                            + " returned from OV/UV" + ". Flags = "...
                                            + dec2hex(temp_ov_flags, 3) + dec2hex(temp_uv_flags, 3));
                                    end
                                end
                            end
                        end                        
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_SYSTEM_COMMAND
                    % Process the system configuration information
                    try
                        status = ErrorCode.NO_ERROR;
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
                        for board_num = 0 : DC2100A.MAX_BOARDS - 1
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
                            obj.board_address_table(board_num +1)...
                                = temp_board_address_table(board_num +1);
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
                            % #todo - this is so gross
                            if (num_boards_next == 1) ...
                                    && (obj.system_state ~= DC2100A.SYSTEM_STATE_TYPE.Awake)
                                
                                obj.buf_out.add(DC2100A.USB_PARSER_MFG_COMMAND...
                                    + "R" + dec2hex(DC2100A.NUCLEO_BOARD_NUM, 2));
                                
                                obj.buf_out.add(DC2100A.USB_PARSER_EEPROM_COMMAND...
                                    + "R" + dec2hex(DC2100A.NUCLEO_BOARD_NUM, 2) + "0");
                                
                                obj.buf_out.add(DC2100A.USB_PARSER_EEPROM_COMMAND...
                                    + "R" + dec2hex(DC2100A.NUCLEO_BOARD_NUM, 2) + "1");
                                
                                % Read UV/OV, passive balancer, and ltc3300 register data for selected board
                                obj.buf_out.add(DC2100A.USB_PARSER_UVOV_COMMAND...
                                    + dec2hex(DC2100A.NUCLEO_BOARD_NUM, 2));
                                
                                obj.buf_out.add(DC2100A.USB_PARSER_PASSIVE_BALANCE_COMMAND...
                                    + "R" + dec2hex(DC2100A.NUCLEO_BOARD_NUM, 2));
                                
                                obj.buf_out.add(LTC3300_Raw_Read(obj,...
                                    DC2100A.NUCLEO_BOARD_NUM, LTC3300.Command.Read_Balance));
                                
                                obj.buf_out.add(LTC3300_Raw_Read(obj,...
                                    DC2100A.NUCLEO_BOARD_NUM, LTC3300.Command.Read_Status));
                                
                                disp("DC2100A has connected, and its cells are charged.");
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
                                    obj.buf_out.add(DC2100A.USB_PARSER_MFG_COMMAND...
                                        + "R" + dec2hex(board_num, 2));
                                    
                                    obj.buf_out.add(DC2100A.USB_PARSER_EEPROM_COMMAND...
                                        + "R" + dec2hex(board_num, 2) + "0");
                                    
                                    obj.buf_out.add(DC2100A.USB_PARSER_EEPROM_COMMAND...
                                        + "R" + dec2hex(board_num, 2) + "1");
                                    
                                    % Read UV/OV, passive balancer, and ltc3300 register data for all board
                                    obj.buf_out.add(DC2100A.USB_PARSER_UVOV_COMMAND...
                                        + dec2hex(board_num, 2));
                                    
                                    obj.buf_out.add(DC2100A.USB_PARSER_PASSIVE_BALANCE_COMMAND...
                                        + "R" + dec2hex(board_num, 2));
                                    
                                    obj.buf_out.add(LTC3300_Raw_Read(obj,...
                                        board_num, LTC3300.Command.Read_Balance));
                                    
                                    obj.buf_out.add(LTC3300_Raw_Read(obj,...
                                        board_num, LTC3300.Command.Read_Status));
                                    
                                    if size(obj.numCells(:), 1) >= obj.numBoards
                                        % Temporary #ComeBack - Need to have a better way for users
                                        % to enter number of cells connected
                                        ConfigConnectedCells(obj, board_num, obj.numCells(board_num +1));
                                        Cell_Present_Write(obj, board_num);
                                    end
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
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_MFG_COMMAND
                    % Process the Manufacturing Data
                    
                    try
                        status = ErrorCode.NO_ERROR;
                        temp_board_id_data = struct...
                            (...
                            'Model', DC2100A.DC2100A_MODEL_NUM_DEFAULT,...
                            'Serial_Number', DC2100A.DC2100A_SERIAL_NUM_DEFAULT,...
                            'Cap_Demo', false,...
                            'Average_Charge_Current_12Cell', 0,...
                            'Average_Discharge_Current_12Cell', 0,...
                            'Average_Charge_Current_6Cell', 0,...
                            'Average_Discharge_Current_6Cell', 0,...
                            'FW_Rev', DC2100A.APP_FW_STRING_DEFAULT);
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCode.USB_PARSER_UNKNOWN_BOARD;
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
                                = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                            
                            % get the 12 cell discharge current
                            num_bytes = 4;
                            temp_board_id_data.Average_Discharge_Current_12Cell...
                                = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                            
                            % get the 6 cell charge current
                            num_bytes = 4;
                            temp_board_id_data.Average_Charge_Current_6Cell ...
                                = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                            
                            % get the 6 cell discharge current
                            num_bytes = 4;
                            temp_board_id_data.Average_Discharge_Current_6Cell ...
                                = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
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
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_VOLTAGE_COMMAND
                    try
                        status = ErrorCode.NO_ERROR;
                        temp_voltages = zeros(1, DC2100A.MAX_CELLS);
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCode.USB_PARSER_UNKNOWN_BOARD;
                        else
                            % get the timestamp
                            num_bytes = 8;
                            temp_timestamp = uint32(hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes)));
                            index = index + num_bytes;
                            
                            % get the board voltages
                            num_bytes = 4;
                            for cell_num = 0 : DC2100A.MAX_CELLS - 1
                                temp_voltages(cell_num +1) ...
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
                            cell_max = 0;
                            cell_min = 0;
                            temp_sum = 0;
                            
                            for cell_num = 0 : DC2100A.MAX_CELLS - 1
                                obj.Voltages(board_num +1, cell_num +1) ...
                                    = temp_voltages(cell_num +1) ...
                                    * DC2100A.VOLTAGE_RESOLUTION;
                                if obj.cellPresent(board_num +1, cell_num +1) == true
                                    if obj.Voltages(board_num +1, cell_num +1) > temp_max
                                        temp_max = obj.Voltages(board_num +1, cell_num +1);
                                        cell_max = cell_num;
                                    end
                                    if obj.Voltages(board_num +1, cell_num +1) < temp_min
                                        temp_min = obj.Voltages(board_num +1, cell_num +1);
                                        cell_min = cell_num;
                                    end
                                    temp_sum = temp_sum + obj.Voltages(board_num +1, cell_num +1);
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
                                = UpdateTimestamp(obj, obj.voltage_timestamp(board_num +1), ...
                                temp_timestamp, temp_balancestamp);
                            
                            try
                                if obj.voltage_timestamp(board_num +1).time_difference > 4
                                    obj.num_times_over_4sec ...
                                        = obj.num_times_over_4sec + 1;
                                    obj.eventLog.Add(ErrorCode.USB_Delayed,...
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
                        status = ErrorCode.NO_ERROR;
                        temp_temperatures = zeros(1, DC2100A.NUM_TEMPS);
                        
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        
                        % get the board number
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            % If this is a board we don't know, then this is a failed response
                            obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCode.USB_PARSER_UNKNOWN_BOARD;
                        else
                            % get the timestamp
                            num_bytes = 8;
                            temp_timestamp = uint32(hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes)));
                            index = index + num_bytes;
                            
                            % get the board temperatures
                            num_bytes = 4;
                            for temp_num = 0 : DC2100A.NUM_TEMPS - 1
                                temp = DC2100A.REMOVE_LEN(obj.buf_in, num_bytes);
                                temp_temperatures(temp_num +1) ...
                                    = hex2dec(temp);
                                
                                % #todo - this is an ugly way to handle signs
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
                            end
                            obj.Stack_Summary_Data.Temp_Max = temp_max;
                            obj.Stack_Summary_Data.Temp_Min = temp_min;
                            obj.Stack_Summary_Data.Temp_Max_Cell = cell_max;
                            obj.Stack_Summary_Data.Temp_Min_Cell = cell_min;
                            
                            
                            obj.temperature_timestamp(board_num +1) ...
                                = UpdateTimestamp(obj, obj.temperature_timestamp(board_num +1), ...
                                temp_timestamp, temp_balancestamp);
                            
                            try
                                if obj.temperature_timestamp(board_num +1).time_difference > 4
                                    obj.num_times_over_4sec ...
                                        = obj.num_times_over_4sec + 1;
                                    obj.eventLog.Add(ErrorCode.USB_Delayed,...
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
                        status = ErrorCode.NO_ERROR;
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            % If this is a board we don't know, then this is a failed response
                            obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCode.USB_PARSER_UNKNOWN_BOARD;
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
                        status = ErrorCode.NO_ERROR;
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            % If this is a board we don't know, then this is a failed response
                            obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCode.USB_PARSER_UNKNOWN_BOARD;
                        else
                            % get the cell present values
                            num_bytes = 4;
                            cell_present_bitmap ...
                                = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                            index = index + num_bytes;
                            
                            % If we got here, all data conversion were successful
                            num_cells = 0;
                            for cell_num = 0:DC2100A.MAX_CELLS -1
                                if bitand(cell_present_bitmap, 1) == 0
                                    obj.cellPresent(board_num +1, cell_num +1) = false;
                                else
                                    obj.cellPresent(board_num +1, cell_num +1) = true;
                                    num_cells = num_cells + 1;
                                end
                                cell_present_bitmap = bitshift(cell_present_bitmap, -1);
                            end
                            
                            obj.LTC3300s(board_num +1, 1).Enabled = true;
                            if (num_cells <= LTC3300.NUM_CELLS) % If the second/higer Balancer does not have cells connected, disable it
                                obj.LTC3300s(board_num +1, 2).Enabled = false;
                            else
                                obj.LTC3300s(board_num +1, 2).Enabled = true;
                            end

                            % Note that Get_Cell_Number_From_String returns a zero referenced number
                            obj.Board_Summary_Data(board_num +1).Num_Cells = num_cells;
                            
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
                        status = ErrorCode.NO_ERROR;
                        adc_values = zeros(1, DC2100A.NUM_TEMPS);
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            % If this is a board we don't know, then this is a failed response
                            obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCode.USB_PARSER_UNKNOWN_BOARD;
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
                        status = ErrorCode.NO_ERROR;
                        register = zeros(1, DC2100A.NUM_LTC3300);
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
                        index = 1;
                        num_bytes = 2;
                        board_num = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                        index = index + num_bytes;
                        if board_num >= DC2100A.MAX_BOARDS
                            obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCode.USB_PARSER_UNKNOWN_BOARD;
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
                                status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                            else
                                
                                % Add to the length to wait the number of data bytes actually in this response.
                                length = length + (bytes_read - 1) * 2;      % subtract the command byte, to add 2 ascii characters per register byte
                                ics_read = floor((bytes_read - 1) / 2);   % each ic requires 4 ascii bytes per register
                                
                                if (obj.buf_in.size < length - index)
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
                                obj.eventLog.Add(ErrorCode.LTC3300_Status, ...
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
                        status = ErrorCode.NO_ERROR;
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
                            obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_BOARD,...
                                "Board: " + num2str(board_num),...
                                DC2100A.REMOVE_LEN(obj.buf_in, length - index));
                            status =  ErrorCode.USB_PARSER_UNKNOWN_BOARD;
                        else
                            % get the board balance states
                            num_bytes = 4;
                            for cell_num = 0 : DC2100A.MAX_CELLS - 1
                                balancer_state = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                                
                                if balancer_state == 0
                                    balance_action(cell_num +1) ...
                                        = LTC3300.Cell_Balancer.BALANCE_ACTION.None;
                                elseif (bitand(balancer_state, 0x8000) == 0)
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
                        status = ErrorCode.NO_ERROR;
                        temp_eeprom_data = ...
                            struct('Capacity', zeros(DC2100A.MAX_CELLS, 1),...
                            'Charge_Currents', zeros(DC2100A.MAX_CELLS, 1),...
                            'Discharge_Currents', zeros(DC2100A.MAX_CELLS, 1));
                        
                        % get the board number
                        obj.buf_in.remove; % Remove the command or first character
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
                                if (obj.buf_in.size < length - index)
                                    status = ErrorCode.USB_PARSER_NOTDONE;
                                else
                                    for cell_num = 0:DC2100A.MAX_CELLS -1
                                        num_bytes = 4;
                                        
                                        % Get Capacity
                                        temp_eeprom_data.Capacity(cell_num +1)...
                                            = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes))...
                                            / DC2100A.SOC_CAP_SCALE_FACTOR;
                                        index = index + num_bytes;
                                    end
                                end
                                
                            elseif item_num == DC2100A.EEPROM_Item_Type.Current
                                length = length + (4 * DC2100A.MAX_CELLS);
                                if (obj.buf_in.size < length - index)
                                    status = ErrorCode.USB_PARSER_NOTDONE;
                                else
                                    for cell_num = 0:DC2100A.MAX_CELLS -1
                                        num_bytes = 2;
                                        
                                        % Get Charge Current Scale Factor
                                        cal_factor ...
                                            = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                                        current = obj.Board_ID_Data(board_num +1).Average_Charge_Current_6Cell ...
                                            + obj.Board_ID_Data(board_num +1).Average_Charge_Current_6Cell ...
                                            * cal_factor / DC2100A.CURRENT_SCALE_FACTOR;
                                        temp_eeprom_data.Charge_Currents(cell_num +1) = current;
                                        index = index + num_bytes;
                                        
                                        % Get Discharge Current Scale Factor
                                        cal_factor ...
                                            = hex2dec(DC2100A.REMOVE_LEN(obj.buf_in, num_bytes));
                                        current = obj.Board_ID_Data(board_num +1).Average_Discharge_Current_6Cell...
                                            + obj.Board_ID_Data(board_num +1).Average_Discharge_Current_6Cell...
                                            * cal_factor / DC2100A.CURRENT_SCALE_FACTOR;
                                        temp_eeprom_data.Discharge_Currents(cell_num +1) = current;
                                        index = index + num_bytes;
                                    end
                                end
                            end
                            
                            % If we got here, all data conversion were
                            % successful
                            if item_num == DC2100A.EEPROM_Item_Type.Cap
                                for cell_num = 0:DC2100A.MAX_CELLS -1
                                    obj.EEPROM_Data(board_num +1).Capacity(cell_num +1)...
                                    = temp_eeprom_data.Capacity(cell_num +1);
                                end
                            elseif item_num == DC2100A.EEPROM_Item_Type.Current
                                for cell_num = 0:DC2100A.MAX_CELLS -1
                                    obj.EEPROM_Data(board_num +1).Charge_Currents(cell_num +1)...
                                        = temp_eeprom_data.Charge_Currents(cell_num +1);
                                    
                                    obj.EEPROM_Data(board_num +1).Discharge_Currents(cell_num +1)...
                                        = temp_eeprom_data.Discharge_Currents(cell_num +1);
                                end
                            else
                                status = ErrorCode.USB_PARSER_UNKNOWN_EEPROM_ITEM;
                            end
                            
                        else
                            status =  ErrorCode.USB_PARSER_UNKNOWN_BOARD;
                        end
                    catch MEX
                        Handle_Exception(obj, MEX);
                        status = ErrorCode.USB_PARSER_UNSUCCESSFUL;
                    end
                    
                case DC2100A.USB_PARSER_EMERGENCY_STOP_COMMAND
                    status = ErrorCode.NO_ERROR;
                    obj.buf_in.remove; % Remove the command or first character
                    index = 1;
                    EmergencyStop(obj);
                    obj.eventLog.Add(ErrorCode.EMERGENCY_STOP,...
                        "Emergency Stop was sent by the MCU." + newline);
            end
        end
        
        
        function [status, board_num] = Get_SystemOVorUV(obj)
            %Get_SystemOVorUV  Gets first board with either OV or UV
            %   Returns True if OV or UV is present, 
            %   returns the first board found with an OV/UV as board_num.
            [status_OV, board_num_OV] = Get_SystemOV(obj);
            [status_UV, board_num_UV] = Get_SystemUV(obj);
            
            if (status_OV == true) || (status_UV == true)
                board_num = min(board_num_OV, board_num_UV);
                status = true;
                return;
            end
            board_num = 0;
            status = false;
        end
        
        
        function [status, board_num] = Get_SystemOV(obj)
            %Get_SystemOV  Returns True if OV is present, returns the first board found with an OV/UV as board_num.
            for board_num = 0 : obj.numBoards -1
                if (obj.OV_Flags(board_num +1) ~= 0)
                    status = true;
                    return;
                end
            end
            board_num = 0;
            status = false;
        end
        
        
        function [status, board_num] = Get_SystemUV(obj)
            %Get_SystemUV Returns the first board found with an OV/UV as board_num.
            %   Returns True if UV is present, 
            %   Note that a board with cells so low that the 6804 can not communicate, counts as UV.
            for board_num = 0 : obj.numBoards -1
                if (obj.UV_Flags(board_num +1) ~= 0) || (obj.system_state ~= DC2100A.SYSTEM_STATE_TYPE.Awake)
                    status = true;
                    return;
                end
            end
            board_num = 0;
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
            %                           function i.e. obj.ResetTimestamp(timeVar)
            %       timeVar         : timestamp struct for Voltage or
            %                           Temperature
            
            timeVar.timestamp_last = 0;
            timeVar.time = -1;
            timeVar.is_balancing = false;
            
        end
        
        
        function USBTimerStopped(obj, varargin)
           disp("USBTimer has stopped"); 
           disp("USBTimer Instant Period = " + num2str(obj.USBTimer.InstantPeriod) + "s");
           disp("USBTimer Average Period = " + num2str(obj.USBTimer.AveragePeriod) + "s");
        end
        
        
        function status = ConfigConnectedCells(obj, board_num, num_connected_cells)
            %ConfigConnectedCells Converts num of cells to connection map
            %    Configures the number of connected cells to a bitmap
            %    corresponding to where on the board the device
            %    manual specifies the cells to be connected.
            %
            %    Inputs:
            %       obj                 : DC2100A object. Can otherwise
            %                               add it behind function i.e.
            %                               obj.ConfigConnectedCells(num_connected_cells)
            %       board_num           : board # from 0 to MAX Num of boards - 1 (9)
            %       num_connected_cells : Number of connected cells equal
            %                               to what the user has physically
            %                               connected according to the
            %                               configurations on the DC2100B
            %                               Demo manual
            status = ErrorCode.NO_ERROR;
            if CheckSelectBoard(obj, board_num) == false
                status = ErrorCode.USB_PARSER_UNKNOWN_BOARD;
                return; 
            end
            
            switch num_connected_cells
                case 4
                    board_config = [false, false, true, true, true, true, false, false, false, false, false, false];
                    ic_config = [true, false];
                case 5
                    board_config = [false, true, true, true, true, true, false, false, false, false, false, false];
                    ic_config = [true, false];
                case 6
                    board_config = [true, true, true, true, true, true, false, false, false, false, false, false];
                    ic_config = [true, false];
                case 7
                    board_config = [false, false, false, true, true, true, false, false, true, true, true, true];
                    ic_config = [true, true];
                case 8
                    board_config = [false, false, true, true, true, true, false, false, true, true, true, true];
                    ic_config = [true, true];
                case 9
                    board_config = [false, false, true, true, true, true, false, true, true, true, true, true];
                    ic_config = [true, true];
                case 10
                    board_config = [false, true, true, true, true, true, false, true, true, true, true, true];
                    ic_config = [true, true];
                case 11
                    board_config = [false, true, true, true, true, true, true, true, true, true, true, true];
                    ic_config = [true, true];
                case 12
                    board_config = [true, true, true, true, true, true, true, true, true, true, true, true];
                    ic_config = [true, true];
                otherwise
                    status = ErrorCode.OUT_OF_BOUNDS;
                    obj.eventLog.Add(ErrorCode.OUT_OF_BOUNDS,...
                        "Board: " + num2str(board_num),...
                        ". The number of cells specified " + ...
                        + " is outside the allowable range of 4 - 12. Resorting to the Max value.", ...
                    "Value Chosen: " + num2str(num_connected_cells));
                    board_config = [true, true, true, true, true, true, true, true, true, true, true, true];
                    ic_config = [true, true];
            end
            
            for cell_num = 0 : DC2100A.MAX_CELLS - 1
                obj.cellPresent(board_num +1, cell_num +1) = board_config(cell_num +1);
            end
            
            for ic_num = 0 : DC2100A.NUM_LTC3300 - 1
                obj.LTC3300s(board_num +1, ic_num +1).Enabled = ic_config(ic_num +1);
            end
            
            obj.Board_Summary_Data(board_num +1).Num_Cells = num_connected_cells;
            
            % Tell board how many cells are present
            %            obj.Cell_Present_Write(board_num);
            
        end
        
        
        function [status, bal_duration] = Validate_Balance_Duration(obj, bal_duration)
            %Validate_Balance_Duration Checks the entered balance durations
            %for errors.
            %   Errors include typos, over limit or under limit
            %
            status = ErrorCode.NO_ERROR;
            for cell_num = 0 : length(bal_duration)-1
                
                try
                    new_time = bal_duration(cell_num +1);
                    % Bound at upper and lower values
                    if new_time > LTC3300.Cell_Balancer.BALANCE_TIME_MAX
                        new_time = LTC3300.Cell_Balancer.BALANCE_TIME_MAX;
                    elseif new_time < 0
                        new_time = 0;
                    end
                    
                    % Round to nearest value
                    if (mod(new_time, LTC3300.Cell_Balancer.BALANCE_TIME_RESOLUTION)...
                            < LTC3300.Cell_Balancer.BALANCE_TIME_RESOLUTION / 2)
                        new_time = new_time ...
                            - mod(new_time, LTC3300.Cell_Balancer.BALANCE_TIME_RESOLUTION);
                    else
                        new_time = new_time ...
                            - mod(new_time, LTC3300.Cell_Balancer.BALANCE_TIME_RESOLUTION)...
                            + LTC3300.Cell_Balancer.BALANCE_TIME_RESOLUTION;
                    end
                    
                catch MEX
                    Handle_Exception(obj, MEX);
                    new_time = 0;
                    status = ErrorCode.EXCEPTION;
                end
                bal_duration(cell_num +1) = new_time;
            end
            
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
            
            obj.eventLog.Add(ErrorCode.EXCEPTION, mexStr); % Show the exception on the Error Logger app
        end
        
        
%         function testErr(obj, varargin)
%             varargin{:} % Test print any inputs you get
%             disp("In Error")
%         end
        
    end
    
    
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % PUBLIC METHODS
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=   
    % Main Methods
    methods
        
        function obj = DC2100A(COMport, eventLogApp, varargin)
            %DC2100A Initiates an instance of DC2100A class that takes
            %the COM port or serial object as an argument.
            %   This Constructor creates a generic serial object with
            %   Baudrate = 115200, DataBits = 8, Parity = 'none',
            %   StopBits = 1, and Terminator = 'LF'.
            %   port = 'COM#' (String)
            %
            %   Inputs:
            %       COMport         : Serial COMM Port e.g 'COM4' or 'COM6'
            %       eventLogApp       : ErrorLog App object. This should be 
            %                           activated outside this class by 
            %                           running "app = ErrorLog;" and
            %                           passing "app" as eventLogApp.
            %       varargin        : Name-Value pairs of input consisting
            %                           of only the following:
            %                           - 'USB_ASYNC' ,true / [false]
            %                           - 'Num_Cells' ,[4] - 12 cells for
            %                           each board connected/planned to be
            %                           connected. e.g [12, 12, 4] for
            %                           board 0, board 1, and board 2
            %                           respectively
            %                           
            try
%                 profile on
                % Varargin Evaluation
                % Code to implement user defined values
                param = struct(...
                    'USB_ASYNC',        false   , ...
                    'Num_Cells',        4);
                
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
                
                obj.numCells = param.Num_Cells;
                                
                tic;
                
                obj.USBTimer = timer;

                % Not yet implemented. There might not be a need for it
                obj.USB_Async_Flag = param.USB_ASYNC;
                if obj.USB_Async_Flag == true
                    if isempty(gcp('nocreate'))
                        obj.USBPool = parpool(obj.USBPoolSize);
                    else
                        obj.USBPool = gcp('nocreate');
                    end
                end
                
                setUSBDataSizes(obj);

                
                
%                 obj.baudRate = 115200;
%                 obj.port = COMport;
%                 obj.byteOrder = "big-endian";
%                 obj.terminator = "LF";
%                 obj.stopbits = 1;
                                
                %{
                serialAvail = serialportlist("available"); % Get all serial ports currently available
                serialAll = serialportlist("all");  % Get all serial ports connected
                if ~(ismember(COMport, serialAvail)) && ~(ismember(COMport, serialAll))
                    warning(COMport + " is not available." + newline + "Ensure MCU is"...
                        + " connected or confirm COM port." + newline + ...
                        "Available COM ports are: ");
                    disp(serialAvail)
                    
                    list = ["", serialAvail];
                    [indx,~] = listdlg('ListString',list,...
                        'PromptString','Select a COM Port:', ...
                        'SelectionMode','single', ...
                        'OKString','Apply', ...
                        'ListSize',[200,250]);
                    if isempty(indx)
                        return;
                    end
                    obj.port = list(indx);
                elseif ~(ismember(COMport, serialAvail)) && (ismember(COMport, serialAll))
                    warning("Serial Port is still open." + newline ...
                        + "Will attempt to close previously open Serial port now.");
                    disconnectSerial(obj);
                    return;
                end
                %}

                
                % If not able to find an Event Logger object. create a new
                % one
                if nargin < 2 || isempty(eventLogApp) || ~isvalid(eventLogApp)
                    obj.eventLog = EventLogger();
                else
                    obj.eventLog = eventLogApp;
                end
                
           
                connectSerial(obj, COMport);

%                 obj.serial = serialport(obj.port, obj.baudRate);
%                 obj.serial.ByteOrder = obj.byteOrder;

                
               
            catch MEX
                disconnectSerial(obj);
                rethrow(MEX);
            end
        end
        
        
        function Cell_Present_Write(obj, board_num, num_cells)
            %Cell_Present_Write Sends num of connected cells to MCU for OVUV prevention.
            %   Writes the cells that have been selected by
            %   the user as connected to the MCU so the cells don't trigger 
            %   OV or UV errors
            %    Inputs:
            %       obj                 : DC2100A object. Can otherwise 
            %                               add it behind function i.e. 
            %                               obj.Cell_Present_Write(board_num)
            %       board_num           : board # from 0 to MAX Num of boards - 1 (9)
            %       varargin            : Number of cells connected
            
            if nargin > 2
               status = ConfigConnectedCells(obj, board_num, num_cells);
               if status ~= ErrorCode.NO_ERROR
                   obj.eventLog.Add(status,...
                    "Board: " + num2str(board_num),...
                    ". Unable to write Cell Present configuration.");
               end
            end
            
            dataString = DC2100A.USB_PARSER_CELL_PRESENT_COMMAND + "W";
            cell_present_bitmap = 0;
            
            dataString = dataString + dec2hex(board_num, 2);
            
            for cell_num = DC2100A.MAX_CELLS -1 : -1 : 0
                cell_present_bitmap = bitshift(cell_present_bitmap, 1); % Positive bitshift = Shift Left
                if obj.cellPresent(board_num +1, cell_num +1)
                    cell_present_bitmap = cell_present_bitmap + 1;
                end
            end
            
            dataString = dataString + dec2hex(cell_present_bitmap, 4);
            
            obj.buf_out.add(dataString);
            
        end
        
        
        function validBoard = CheckSelectBoard(obj, board_num)
            %CheckSelectBoard Checks to see if selected board is valid.
            %
            %   This functions checks to see if the board selected is 
            %   within the number of boards connected. It also sets the
            %   selectedBoard property
            
            % Log an error when the board selected is greater than the 
            % number of boards connected
            if(board_num < obj.numBoards) 
                obj.selectedBoard = board_num;
                validBoard = true;
            else
                validBoard = false;
                obj.eventLog.Add(ErrorCode.USB_PARSER_UNKNOWN_BOARD,...
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
            ModelNum = "BAD";
            key = DC2100A.USB_PARSER_MFG_COMMAND; 
            if(isKey(obj.USB_Parser_Response_DataLengths, key))
                num_bytes = obj.USB_Parser_Response_DataLengths(key);
            else
                error("Unrecognized Command. Key '" + key + "' Not Found");
            end
            
            [status, data] = readData(obj,...
                DC2100A.USB_PARSER_MFG_COMMAND + "R"...
                + dec2hex(DC2100A.NUCLEO_BOARD_NUM, 2), num_bytes); 
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
                
        
        function Timed_Balance_Write(obj, board_num, bal_actions, balance_timer)
            %Timed_Balance_Write Write the command to perform a timed
            %balance on one or more cells.
            %   Inputs:
            %       obj                 : DC2100A object. Can otherwise add it behind
            %                               function i.e. obj.Timed_Balance_Start() 
            %       board_num           : Board # from 0 to MAX Num of boards - 1 (9)
            %       bal_actions         : Balancer Actions based on
            %                               LTC3300.Cell_Balancer.BALANCE_ACTION
            %                               in a vector ranging from
            %                               1 to (LTC3300.NUM_CELLS * DC2100A.NUM_LTC3300).
            %       balance_timer       : Balancer Durations or times in
            %                               seconds. Decimal notation is in
            %                               increments of 0.0625 otherwise it
            %                               rounds it down to nearest 0.625.
            %                               This happens due to the task
            %                               rate of the balancer task in
            %                               the FW. It runs every 250ms.
            %
            
            balancer_error = false;
            
            % Send the command for the selected DC2100A
            dataString = DC2100A.USB_PARSER_TIMED_BALANCE_COMMAND + "W" ...
                + dec2hex(board_num, 2); 
            
            [status, balance_timer] = Validate_Balance_Duration(obj, balance_timer);
            
            if status ~= ErrorCode.NO_ERROR
                obj.eventLog.Add(status, "Error occured. Could not validate durations for write.");
                return;
            end
            
            for cell_num = 0 : DC2100A.MAX_CELLS -1
                if bal_actions(cell_num +1) == LTC3300.Cell_Balancer.BALANCE_ACTION.None...
                        && balance_timer(cell_num +1) ~= 0
                    % If timed balance settings do not make sense, flag error to popup message box instead of write to the board.
                    balancer_error = true; 
                else
                    % If timed balance settings are reasonable, then write them to the board
                    balancer_state = uint16(balance_timer(cell_num +1) / LTC3300.Cell_Balancer.BALANCE_TIME_RESOLUTION);
                    if (balance_timer(cell_num +1) ~= 0) ...
                            && bal_actions(cell_num +1) == LTC3300.Cell_Balancer.BALANCE_ACTION.Discharge
                        % #todo - this is pretty gross, hardcoding that the 
                        % top bit indicates whether the balancer is discharging 
                        % or charging when the timer ~= 0
                        % Each cell has a 16 bit value:
                        %   bit(1) => 0=charge, 1=disharge 
                        %   bit(2:16) => balance duration (0s - 8191.75s)
                        balancer_state = balancer_state + 0x8000;    
                        
                    end
                    dataString = dataString + dec2hex(balancer_state, 4);
                end
            end
            
            if balancer_error == true
                errordlg("A Timed Balance Value Must be associated with a Charge or Discharge command."...
                    +newline + "Unable to write commands.", ...
                    "Timed_Balance_Write Error");
            else
                obj.buf_out.add(dataString);
            end
        end
        
        
        function Timed_Balance_Start(obj)
            %Timed_Balance_Start Starts the timed balancing process
            %assuming the balancing commands have been written.
            %
            %   Inputs: 
            %       obj             : DC2100A object. Can otherwise add it behind
            %                           function i.e. obj.Timed_Balance_Start()            
            %
            
            % Flag that balancing is started
            obj.isTimedBalancing = true;
            obj.isBalancing = true;
            
            % Send the command for the selected DC2100A
            % Note that the whole system will start balancing.  
            % The selected board is the only one that will reply with its balancing data for display, however.
            obj.buf_out.add(DC2100A.USB_PARSER_TIMED_BALANCE_COMMAND + "B" + dec2hex(obj.selectedBoard, 2));
            
        end
        
        
        function Timed_Balance_Stop(obj, board_num, reset)
            %Timed_Balance_Stop Stops the timed balancing process
            %
            %   Inputs:
            %       obj             : DC2100A object. Can otherwise add it behind
            %                           function i.e. obj.Timed_Balance_Stop(board_num, reset)
            %       board_num       : board # from 0 to MAX Num of boards - 1 (9)
            %       reset           : Whether or not to reset the timers.
            %                           - Set true to end balancing,
            %                               clear all balancing durations
            %                               and let the LTC3300 IC go to
            %                               sleep
            %                           - Set false to only pause or suspend
            %                               the timed balacing. Blanacing
            %                               durations are not reset/cleared.
            
            %  Flag that timed balancing is stopped
            obj.isTimedBalancing = false;
            obj.isBalancing = false;
            
            % Either reset or suspend the balancing operation
            if reset == false
                % Send the command for the selected DC2100A
                % Note that the whole system will suspend balancing.  The selected board is the only one that will reply with its balancing data for display, however.
                obj.buf_out.add(DC2100A.USB_PARSER_TIMED_BALANCE_COMMAND + "S" + dec2hex(board_num, 2))
            else
                
                % Send the command for the selected DC2100A
                % Note that the whole system will end balancing.  The selected board is the only one that will reply with its balancing data for display, however.
                obj.buf_out.add(DC2100A.USB_PARSER_TIMED_BALANCE_COMMAND + "E" + dec2hex(board_num, 2))
            end
            
            % #todo - do we need to refresh data here or will the timed call be fine for it?
            ReadAllData(obj);
            
        end

        
        function LTC3300_Write_Balance(obj, board_num, bal_actions)
            %LTC3300_Write_Balance Writes balancing command to specified board
            %   Writes the balancing commands for each cell to the DC2100A 
            %   board specified. The balancing commands do not begin to run
            %   until the execute command is sent.
            %
            %    Inputs:
            %       obj                 : DC2100A object. Can otherwise 
            %                               add it behind function i.e. 
            %                               obj.LTC3300_Write_Balance(obj, board_num, bal_actions)
            %       board_num           : board # from 0 to MAX Num of boards - 1 (9)
            %       bal_actions         :  Balancer Actions based on
            %                               LTC3300.Cell_Balancer.BALANCE_ACTION
            %                               in a vector ranging from
            %                               1 to (LTC3300.NUM_CELLS * DC2100A.NUM_LTC3300), 
            %                               i.e. [cells(1-6), cells(7-12)].
            %   Human "Balance Actions" include : 
            %       - LTC3300.Cell_Balancer.BALANCE_ACTION.None         = 0
            %       - LTC3300.Cell_Balancer.BALANCE_ACTION.Discharge    = 1
            %       - LTC3300.Cell_Balancer.BALANCE_ACTION.Charge       = 2
            
            ltc3300_Command = LTC3300.Command.Write_Balance;
            
            obj.buf_out.add(LTC3300_Raw_Write(obj, ltc3300_Command,  board_num, bal_actions)); 
            
        end
        
        
        function LTC3300_Execute(obj)
            %LTC3300_Execute Begins balancing on the all boards connected
            %   Writes the execute command to all DC2100A boards which
            %   results in the initiation of balancing on all enabled
            %   balancers (depending on the number of batteries connected).
            %
            %    Inputs:
            %       obj                 : DC2100A object. Can otherwise
            %                               add it behind function i.e.
            %                               obj.LTC3300_Execute()
            
            % If OV or UV is not present, start the balancing
            [status, board_num] = Get_SystemOVorUV(obj);
            if status == false
                ltc3300_Command = LTC3300.Command.Execute;
                obj.buf_out.add(LTC3300_Raw_Write(obj, ltc3300_Command));
                obj.isBalancing = true;
                
                ReadAllData(obj);
            else
                % If OV or UV is present, do nothing
                popupStr = DC2100A.SET_POPUP_TEXT("Balancing" , ...
                    Get_OVUV_Condition_String(obj, board_num), board_num, false);
                errordlg(popupStr, "OV or UV Error");
            end
        end
        
        
        function LTC3300_Suspend(obj)
            %LTC3300_Suspend Suspends balancing on all boards connected
            %   Writes the suspend command to all DC2100A boards which
            %   results in the suspension of all enabled balancers (depending on
            %   the number of batteries connected).
            %   
            %
            %    Inputs:
            %       obj                 : DC2100A object. Can otherwise 
            %                               add it behind function i.e. 
            %                               obj.LTC3300_Suspend()
            
            ltc3300_Command = LTC3300.Command.Suspend;
            
            obj.buf_out.add(LTC3300_Raw_Write(obj, ltc3300_Command));
            ReadAllData(obj);
            
            obj.isBalancing = false;
            
        end

        
        function ReadAllData(obj)
            % get strings to read the LTC3300 registers for the selected board
            for board_num = 0 : obj.numBoards -1
                obj.buf_out.add(LTC3300_Raw_Read(obj, board_num, LTC3300.Command.Read_Balance));
                obj.buf_out.add(LTC3300_Raw_Read(obj, board_num, LTC3300.Command.Read_Status));
            end
            
            % #todo - the autoread stuff will need to change when FW is in control of streaming the data
            if obj.autoRead == false
                obj.buf_out.add(DC2100A.USB_PARSER_VOLTAGE_COMMAND);
                obj.buf_out.add(DC2100A.USB_PARSER_TEMPERATURE_COMMAND);
                %                 Temperature_Update_Flag = true; % #NeededNow???
                %                 Voltage_Update_Flag = true;
            end
            
        end
        
        
        function dataString = LTC3300_Raw_Write(obj, command, board_num, bal_actions)
            %LTC3300_Raw_Write  Returns the USB command to write to the LTC3300s on the selected board
            %   Input:
            %       obj         : DC2100A object. Can otherwise add it behind
            %                       function i.e. obj.LTC3300_Raw_Write(cmd, board_num)
            %       command     : General LTC3300 Command value from the LTC3300 Class
            %       board_num   : Default=0. board # from 0 to MAX Num of boards - 1 (9)
            %       Bal_Actions : Default=[]
            %                       Balancer Actions based on
            %                       LTC3300.Cell_Balancer.BALANCE_ACTION
            %                       in a vector ranging from
            %                       1 to (LTC3300.NUM_CELLS * DC2100A.NUM_LTC3300), 
            %                       i.e. [cells(1-6), cells(7-12)].
            %                       This input is only valid when command =
            %                       LTC3300.Command.Write_Balance.
            %
            %   Output:
            %       dataString  : Command String written to the board containing
            %                       data to the LTC3300 Balancers on board.
            
            
            if nargin < 3
                board_num = 0;
                bal_actions = [];
            end
            
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
            dataString = dataString + dec2hex(command, 2);
            
            % Send Balance Command
            if (command == LTC3300.Command.Write_Balance)
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
            dataString = dataString + dec2hex(command, 2);
            
        end
        
        
        function Set_OVUV_Threshold(obj, Vmax, Vmin)
            vmax_last = obj.vMax;
            vmin_last = obj.vMin;
            
            try
                vmax_limit = DC2100A.VOLTAGE_MAX_LIMIT;
                vmin_limit = DC2100A.VOLTAGE_MIN_LIMIT;
                
                % Bounds Check the OV setting
                obj.vMax = Vmax;
                if obj.vMax > vmax_limit
                    obj.vMax = vmax_limit;
                elseif obj.vMax < obj.vMin 
                    obj.vMax = obj.vMin;
                end
                
                
                % Bounds Check the UV setting
                obj.vMin = Vmin;
                if obj.vMin > obj.vMax 
                    obj.vMin = obj.vMax;
                elseif obj.vMin < vmin_limit
                    obj.vMin = vmin_limit;
                end

                obj.buf_out.add(DC2100A.USB_PARSER_UVOV_THRESHOLDS_COMMAND...
                    + dec2hex(uint32(obj.vMax / DC2100A.VOLTAGE_RESOLUTION), 4)...
                    + dec2hex(uint32(obj.vMin / DC2100A.VOLTAGE_RESOLUTION), 4));
                
            catch MEX
                Handle_Exception(obj, MEX);
                obj.vMax = vmax_last;
                obj.vMin = vmin_last;
            end
        end
        
        
        function Set_OV_Threshold(obj, Vmax)
            vmax_last = obj.vMax;
            
            try
                vmax_limit = DC2100A.VOLTAGE_MAX_LIMIT;
                
                % Bounds Check the OV setting
                obj.vMax = Vmax;
                if obj.vMax > vmax_limit
                    obj.vMax = vmax_limit;
                elseif obj.vMax < obj.vMin 
                    obj.vMax = obj.vMin;
                end

                obj.buf_out.add(DC2100A.USB_PARSER_UVOV_THRESHOLDS_COMMAND...
                    + dec2hex(uint32(obj.vMax / DC2100A.VOLTAGE_RESOLUTION), 4)...
                    + dec2hex(uint32(obj.vMin / DC2100A.VOLTAGE_RESOLUTION), 4));
                
            catch MEX
                Handle_Exception(obj, MEX);
                obj.vMax = vmax_last;
            end
        end
        
        
        function Set_UV_Threshold(obj, Vmin) 
            vmin_last = obj.vMin;
            
            try
                vmin_limit = DC2100A.VOLTAGE_MIN_LIMIT;
                
                % Bounds Check the UV setting
                obj.vMin = Vmin;
                if obj.vMin > obj.vMax 
                    obj.vMin = obj.vMax;
                elseif obj.vMin < vmin_limit
                    obj.vMin = vmin_limit;
                end

                obj.buf_out.add(DC2100A.USB_PARSER_UVOV_THRESHOLDS_COMMAND...
                    + dec2hex(uint32(obj.vMax / DC2100A.VOLTAGE_RESOLUTION), 4)...
                    + dec2hex(uint32(obj.vMin / DC2100A.VOLTAGE_RESOLUTION), 4));
                
            catch MEX
                Handle_Exception(obj, MEX);
                obj.vMin = vmin_last;
            end
            
            
        end
        
        
        function SetBalanceCurrent(obj, board_num, current)
            
            if CheckSelectBoard(obj, board_num) == false, return; end
            
            num_currents = length(current);
            if num_currents == DC2100A.MAX_CELLS
                curr2Send = current;
                obj.Currents(board_num, :) = current(1, logical(bal.cellPresent(1, :)));
                
            elseif num_currents == obj.numCells(board_num +1)
                curr2Send = zeros(DC2100A.MAX_CELLS, 1);
                curr2Send(obj.cellPresent(board_num +1, :)) = current;
                
            elseif num_currents < DC2100A.MIN_CELLS || num_currents > DC2100A.MAX_CELLS
                obj.eventLog.Add(ErrorCode.OUT_OF_BOUNDS,...
                    "Board: " + num2str(board_num),...
                    ". The number of current values being sent to the balancer" + ...
                    + " is outside the allowable range of 4 - 12.", ...
                    num2str(num_currents));
            end
            
            dataString = DC2100A.USB_PARSER_ALGORITHM_COMMAND + "W";
            
%             % #SingleBoard - Currently Defaulted to "DC2100A_NUCLEO_BOARD_NUM" in firmware
%             dataString = dataString + dec2hex(board_num, 2); 
            
            % Create Balance Actions and associate their respective current
            % values. These Balance Actions do not need to converted to
            % balance commands since they are not being sent directly to
            % the LTC3300s but instead, to a low level controller.
            
            actions = zeros(1, DC2100A.MAX_CELLS);
            dchrg_ind = curr2Send > 0; % Negative values are charging currents, positive values discharging
            actions(dchrg_ind) = 1; % Discharge Action 
            
            actions2Send = bin2dec(num2str(flip(actions))); % flip cuz bin2dec takes the array from the right to left instead of left to right
            
            curr2Send2 = abs(curr2Send) * DC2100A.MA_PER_A * obj.sTime_MPC; % Send in terms of capacity (mAs) in 2 bytes per cell current
            
            dataString = dataString + string(dec2hex(actions2Send, 4));
            dataString = dataString + strjoin(string(dec2hex(curr2Send2, 4)), "");
            
            obj.buf_out.add(dataString);
            
        end
        
        
        function SetBalanceCharges(obj, board_num, charges)
            
            if CheckSelectBoard(obj, board_num) == false, return; end
            
            num_charges = length(charges);
            if num_charges == DC2100A.MAX_CELLS
                charges2Send = charges;
                obj.Currents(board_num, :) = charges(1, logical(bal.cellPresent(1, :)));
                
            elseif num_charges == obj.numCells(board_num +1)
                charges2Send = zeros(DC2100A.MAX_CELLS, 1);
                charges2Send(obj.cellPresent(board_num +1, :)) = charges;
                
            elseif num_charges < DC2100A.MIN_CELLS || num_charges > DC2100A.MAX_CELLS
                obj.eventLog.Add(ErrorCode.OUT_OF_BOUNDS,...
                    "Board: " + num2str(board_num),...
                    ". The number of current values being sent to the balancer" + ...
                    + " is outside the allowable range of 4 - 12.", ...
                    num2str(num_charges));
            end
            
            dataString = DC2100A.USB_PARSER_ALGORITHM_COMMAND + "W";
            
%             % #SingleBoard - Currently Defaulted to "DC2100A_NUCLEO_BOARD_NUM" in firmware
%             dataString = dataString + dec2hex(board_num, 2); 
            
            % Create Balance Actions and associate their respective current
            % values. These Balance Actions do not need to converted to
            % balance commands since they are not being sent directly to
            % the LTC3300s but instead, to a low level controller.
            
            actions = zeros(1, DC2100A.MAX_CELLS);
            dchrg_ind = charges2Send > 0; % Negative values are charging currents, positive values discharging
            actions(dchrg_ind) = 1; % Discharge Action 
            
            actions2Send = bin2dec(num2str(flip(actions))); % flip cuz bin2dec takes the array from the right to left instead of left to right
            
            curr2Send2 = abs(charges2Send) * DC2100A.MA_PER_A * obj.sTime_MPC; % Send in terms of capacity (mAs) in 2 bytes per cell current
            
            dataString = dataString + string(dec2hex(actions2Send, 4));
            dataString = dataString + strjoin(string(dec2hex(curr2Send2, 4)), "");
            
            obj.buf_out.add(dataString);
            
        end

        
        function EmergencyStop(obj)
            if isvalid(obj.USBTimer)
                if strcmpi(obj.USBTimer.Running, 'on')
                    stop(obj.USBTimer);
                end
            end
            % Send Emergency command to MCU as well to Shut off balancing 
            if obj.isBalancing == true
               write(obj.serial, DC2100A.USB_PARSER_EMERGENCY_STOP_COMMAND, 'char');
            end
            
        end
        
        
        function disconnect(obj)
            %DISCONNECT Disconnects and deletes device's serial port and deletes the device object
            if obj.isBalancing == true
               write(obj.serial, DC2100A.USB_PARSER_EMERGENCY_STOP_COMMAND, 'char');
               disp("Sent Emergency Stop Command since balancers were still on. ");
               obj.eventLog.Add(ErrorCode.EMERGENCY_STOP, ...
                   "Emergency Stop Triggered while trying to disconnect" ...
                   + " board during balancing." + newline + "Command Sent.");
            end
            
            s = inputname(1);
            if ~isnumeric(obj.USBTimer)
                if isvalid(obj.USBTimer)
                    if strcmpi(obj.USBTimer.Running, 'on')
                        stop(obj.USBTimer);
                    end
                    delete(obj.USBTimer);
                end
            end
            
            if ~isnumeric(obj.serial)
                availBytes = obj.serial.NumBytesAvailable;
                if availBytes ~= 0
                    disp("Num Bytes Available in serial buffer = " ...
                        + availBytes + " bytes.")
                    disp("Serial Buffer Cleared.");
                end
                flush(obj.serial, 'input');
                disp("DC2100A Board disconnected")
            end
            
            evalin('caller', [['clear '], s ,';']);
%             profile viewer
%             profile off;
        end
        
    end
    
    
    % Serial Connection Methods
    methods
        function set.baudRate(obj, value)
            obj.baudRate = value;
            obj.serial.BaudRate = value;
        end
        
        function set.dataBits(obj, value)
            obj.dataBits = value;
            obj.serial.DataBits = value;
        end
        
        function set.byteOrder(obj, value)
            obj.byteOrder = value;
            obj.serial.ByteOrder = value;
        end
        
        
        function reply = connectSerial(obj, port, varargin)
            %connect2Serial Connects to a serial port
            
            if isempty(obj.serial)
                
                % Varargin Evaluation
                % Code to implement user defined values
                param = struct(...
                    'baudRate',       115200, ...
                    'byteOrder',      'big-endian',...
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
                
                obj.port = upper(port);
                s = serialport(obj.port, param.baudRate); %Creates a serial port object
                obj.serial = s;
                
                flush(obj.serial);
                
                obj.baudRate    = param.baudRate;
                obj.byteOrder   = param.byteOrder;
                obj.stopbits    = param.stopBits;
                
                
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
                elseif status == ErrorCode.COMM_TIMEOUT
                    warning("There has been a TIMEOUT while trying to read Model_Num");
                elseif status == ErrorCode.NO_ERROR
                    disp("Model Num Confirmed. Test String = '" + ModelNum + "'");
                    obj = System_Init(obj, true);
                    
                    if obj.useUSBTerminator == false
                        configureCallback(obj.serial, "byte",...
                            obj.serial.NumBytesAvailable ,@obj.USBDataIn_Callback);
                        
                    elseif obj.useUSBTerminator == true
                        configureCallback(obj.serial, "terminator" ,@obj.USBDataIn_Callback); %, 'ErrorOccuredFcn', @testErr);
                    end
                    
                    obj.USBTimer.ExecutionMode = 'fixedSpacing';
                    obj.USBTimer.Period = DC2100A.USB_COMM_TIMER_INTERVAL / DC2100A.MS_PER_SEC;
                    %                     obj.USBTimer.StartDelay = 1;
                    %                     obj.USBTimer.TasksToExecute = 1000;
                    obj.USBTimer.StopFcn = @obj.USBTimerStopped;
                    obj.USBTimer.TimerFcn = @obj.USBDataOut_Timer_Callback;
                    obj.USBTimer.ErrorFcn = {@obj.Handle_Exception, []};
                    % Start COMM out timer
                    start(obj.USBTimer);
                    
                else
                    disp("Returned Error from getModelNum = " + status);
                end
                
                reply = "Connected";
                
            else
                reply = "Already Connected";
            end
        end
        
        function reply = disconnectSerial(obj)
            %DISCONNECTSERIAL Disconnects and deletes device's serial port ONLY.
            %   Critical components are also shutdown to avoid the 
            %   inability to solve issues that might arise after disconnection.
            
            if obj.isBalancing == true
               write(obj.serial, DC2100A.USB_PARSER_EMERGENCY_STOP_COMMAND, 'char');
               disp("Sent Emergency Stop Command since balancers were still on. ");
               obj.eventLog.Add(ErrorCode.EMERGENCY_STOP, ...
                   "Emergency Stop Triggered while trying to disconnect" ...
                   + " board during balancing." + newline + "Command Sent.");
            end
            
            if ~isnumeric(obj.USBTimer)
                if isvalid(obj.USBTimer)
                    if strcmpi(obj.USBTimer.Running, 'on')
                        stop(obj.USBTimer);
                    end
                    delete(obj.USBTimer);
                end
            end
            
            if ~isnumeric(obj.serial)
                availBytes = obj.serial.NumBytesAvailable;
                if availBytes ~= 0
                    disp("Num Bytes Available in serial buffer = " ...
                        + availBytes + " bytes.")
                    disp("Serial Buffer Cleared.");
                end
                flush(obj.serial, 'input');
                disp("DC2100A Board disconnected")
            end
            
            obj.serial = [];
            reply = "Disconnected";
        end
        
        function response = serialStatus(obj)
            %serialStatus Reports if the serial port is "connected" or
            %"disconnected".
            if isempty(obj.serial)
                response = "Disconnected";
            else
                if isvalid(obj.serial)
                    response = "Connected";
                end
            end
        end
    end
end


