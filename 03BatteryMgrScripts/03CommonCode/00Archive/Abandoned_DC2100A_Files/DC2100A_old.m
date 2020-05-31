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
        
         % IDSTRING that the board sends back to the host
        IDSTRING            = "DC2100A-A,LTC3300-1 demonstration board";
        IDSTRING_SIZE       = (length(char(IDSTRING)));
        COMPANY_STRING      = "Linear Technology Inc.";
        COMPANY_STRING_SIZE = (length(char(COMPANY_STRING)));

        MODEL_NUM_DEFAULT   = "DC2100A-?";
        MODEL_NUM_SIZE      = (length(char(MODEL_NUM_DEFAULT)));  % The size of the model number string (non-unicode), no null terminator
        CAP_DEMO_DEFAULT    = '?';
        CAP_DEMO_SIZE       = 1;                                        % The size of the cap demo character
        SERIAL_NUM_DEFAULT  = "None             ";
        SERIAL_NUM_SIZE     = (length(char(SERIAL_NUM_DEFAULT))); % The size of the serial number string (non-unicode), no null terminator

        % DC2100A HW definition
        MAX_BOARDS              = 8;  % The maximum number of DC2100A boards that can be stacked together into one system.
                                      % Note: the number of boards that can be stacked, is limited by the voltage rating on transformer T15.
        NUM_CELLS               = 12; % The number of cells on one DC2100A board
        NUM_MUXES               = 2;  % The number of LTC1380 Muxes on a DC2100A board
        NUM_TEMPS               = 12; % The number of thermistor inputs on one DC2100A board
        NUM_LTC3300             = 2;  % The number of LTC3300 Balancers on a DC2100A board
        PIC_BOARD_NUM           = 0;  % It makes a lot of things simpler if the board with the PIC always has the same address.
        
    end
    
    
    properties
        spiComm  % Object for the MCP2210 USB to SPI converter
        
        % Error related constants
        Error_Code_LTC6804_CRC_Ignore = true;
        
        
    end
    
    
    

    

    
    methods
        function obj = DC2100A(varargin)
            %DC2100A Initiates an instance of DC2100A class that takes
            %the COM port or serial object as an argument.
            %   This Constructor creates a generic serial object with
            %   Baudrate = 19200, DataBits = 8, Parity = 'none',
            %   StopBits = 1, and Terminator = 'LF'. These settings are
            %   adjustable for and on the APM SPS80VDC1000W PSU.
            %   port = 'COM#' (String)
            tic;
            obj.spiComm = MCP2210_USB2SPI();
            
%             % Call a find devices function here
%             obj.detectedBoards = detectBoards(obj);
            
        end
        
       
        
    end
    
end