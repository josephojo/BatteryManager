classdef MCP2210_USB2SPI
    %MCP2210_USB2SPI Library specific for the MCP2210 breakout board to
    %transfer SPI Commands and Data through USB
    %   The Library is based on the unmananged dll (library) and header
    %   file provided by the manufacturer (Microchip). This means that this
    %   .m file requires the following files in the same folder to be
    %   functional:
    %   - mcp2210_dll_um.h
    %   - mcp2210_dll_um_x64.dll (untested with mcp2210_dll_um_x86.dll)
    %
    %   Please refer to the MCP2210 Breakout Module User’s Guide for more
    %   detail about the settings and functions of this device.
            
    
    % Definitions from the mcp2210_dll_um.h header file
    properties (Constant)
        
        LIBRARY_VERSION_SIZE            	= 64;              % version string maximum byte size including null character
        SERIAL_NUMBER_LENGTH            	= 10;              % MPC2210 HID serial number length - count of wide characters
        
        % chip setting constants
        NUM_GPIO_PINS                       = 9;               % there are 9 GPIO pins
        
        % GPIO Pin Designation
        PIN_DES_GPIO                    	= 0x00;            % pin configured as GPIO
        PIN_DES_CS                      	= 0x01;            % pin configured as chip select - CS
        PIN_DES_FN                      	= 0x02;            % pin configured as dedicated function pin
        
        % VM/NVRAM selection - use it as cfgSelector parameter for setting
        % or getting configurations
        VM_CONFIG = 0;     % designates current chip setting - Volatile Memory
        NVRAM_CONFIG = 1;  % designates power-up chip setting - NVRAM
        
        % remote wake-up enable/disable
        REMOTE_WAKEUP_ENABLED           	= 1;
        REMOTE_WAKEUP_DISABLED          	= 0;
        
        % interrupt counting mode
        INT_MD_CNT_HIGH_PULSES          	= 0x4;
        INT_MD_CNT_LOW_PULSES           	= 0x3;
        INT_MD_CNT_RISING_EDGES         	= 0x2;
        INT_MD_CNT_FALLING_EDGES        	= 0x1;
        INT_MD_CNT_NONE                 	= 0x0;
        
        % SPI bus release enable/disable
        SPI_BUS_RELEASE_ENABLED         	= 1;
        SPI_BUS_RELEASE_DISABLED        	= 0;
        
        % SPI bus release ACK pin value
        SPI_BUS_RELEASE_ACK_LOW         	= 0;
        SPI_BUS_RELEASE_ACK_HIGH        	= 1;
        
        % SPI maximum transfer attempts threshold
        XFER_RETRIES                    	= 200;
        
        % min and max current amount from USB host
        MIN_USB_AMPERAGE                	= 2;
        MAX_USB_AMPERAGE                	= 510;
        
        % USB string descriptor params
        DESCRIPTOR_STR_MAX_LEN          	= 29;              % maximum UNICODE size of the string descriptors, without NULL terminator
        
        % SPI Mode selection
        SPI_MODE0                       	= 0x00;
        SPI_MODE1                       	= 0x01;
        SPI_MODE2                       	= 0x02;
        SPI_MODE3                       	= 0x03;
        
        % GP8 firmware error workaround bit
        GP8CE_MASK                      	= 0x80000000;
        
        % NVRAM chip settings protection access control
        NVRAM_PASSWD_LEN                	=    8;            % the password must be a NULL terminated string of 8 characters (bytes)
        NVRAM_NO_PROTECTION             	= 0x00;
        NVRAM_PROTECTED                 	= 0x40;
        NVRAM_LOCKED                    	= 0x80;
        NVRAM_PASSWD_CHANGE             	= 0xA5;
    end
    
    % Matlab Class Constants
    properties (Constant)
        
        % Defualt values
        DEFAULT_VID 			= 0x4d8;
        DEFAULT_PID 			= 0xde;
        DEFAULT_SPI_MODE 		= uint8(0);
        DEFAULT_CS_ACTIVE_STATE = uint32(0); 		% all 8 pins are active low: B00000000
        DEFAULT_CS_IDLE_STATE 	= uint32(255); 		% all 8 pins are by default high: B11111111
        DEFAULT_BAUDRATE 		= uint32(499999); 	% Transfer Speed in bits per second (bps)
        DEFAULT_CS2DATA_DLY 	= uint32(0); 		% Multiples of 100 microseconds
        DEFAULT_DATA2CS_DLY 	= uint32(0); 		% Multiples of 100 microseconds
        DEFAULT_DATA2DATA_DLY 	= uint32(0); 		% Multiples of 100 microseconds
        DEFAULT_TXFERSIZE 		= uint32(4);		% Default number of bytes to transfer
        DEFAULT_CSPIN 			= uint32(0x00);     % What pin is being used as CS. Default is GP5, 0x20 or B0000100000.
        
%         DEFAULT_GPIO_PIN_DES    = uint8([0 1 2 1 2 1 2 0 0]); % LSB ... MSB. 0=GPIO, 1=CS, 2=DedicatdFunc
        DEFAULT_GPIO_PIN_DES    = uint8(...
            repmat(MCP2210_USB2SPI.PIN_DES_GPIO, 1, MCP2210_USB2SPI.NUM_GPIO_PINS));
        DEFAULT_GPIO_OUTPUT     = uint32(0x1FF); % All 9 pins are set to 1 (Default High)
%         DEFAULT_GPIO_DIRECTION  = uint32(0x1DF);  % 0=Output, 1=Input
        DEFAULT_GPIO_DIRECTION  = uint32(0x100);  % 0=Output, 1=Input. Pin8 has to always be an input unless no COMM
        DEFAULT_REM_WAKEUP_EN   = uint8(MCP2210_USB2SPI.REMOTE_WAKEUP_ENABLED);
        DEFAULT_INT_PIN_MODE    = uint8(MCP2210_USB2SPI.INT_MD_CNT_RISING_EDGES);
        DEFAULT_SPI_BUS_REL_EN  = uint8(MCP2210_USB2SPI.SPI_BUS_RELEASE_DISABLED);
        
        DEFAULT_LIBNAME 		= 'mcp2210_dll_um_x64'; % DLL filename
        DEFAULT_HEADERNAME 		= 'mcp2210_dll_um.h'; % Daefault header filename
        
        
    end
    
    properties
        % Variables
        devHandle
        devPathPtr
        devPathSizePtr
        devIndex
        devSerialNum
        
        dev_vid 		= MCP2210_USB2SPI.DEFAULT_VID;
        dev_pid 		= MCP2210_USB2SPI.DEFAULT_PID;
        
        gpioPinDes
		dfltGpioOutput
		dfltGpioDir
		rmtWkupEn 
		intPinMd  
		spiBusRelEn
        
        spiMode
        activeCSstate
        idleCSstate
        baudRate
        cs2dataDly
        data2csDly
        data2dataDly
        txferSize
        csPin
        
        libname 		= MCP2210_USB2SPI.DEFAULT_LIBNAME ;
        headername 		= MCP2210_USB2SPI.DEFAULT_HEADERNAME;
    end
    
    methods (Static)
        function load_MCP2210_DLL()
            % If library is already loaded, do nothing else
            if (libisloaded(MCP2210_USB2SPI.DEFAULT_LIBNAME))
                return;
            end
            
            [notfound,warnings]=loadlibrary(MCP2210_USB2SPI.DEFAULT_LIBNAME,...
                MCP2210_USB2SPI.DEFAULT_HEADERNAME);
            libLoaded = libisloaded(MCP2210_USB2SPI.DEFAULT_LIBNAME);
            if libLoaded == false
                error("MCP2210 Library failed to load.");
            end
        end
        
        function numDev = totalNumMCP2210s()
            %totalNumMCP2210s Reports the total number of MCP2210
            %breakout boards with the default VID&PID connected.
            
            MCP2210_USB2SPI.load_MCP2210_DLL();
            numDev = calllib(MCP2210_USB2SPI.DEFAULT_LIBNAME,...
                'Mcp2210_GetConnectedDevCount', ...
                MCP2210_USB2SPI.DEFAULT_VID, MCP2210_USB2SPI.DEFAULT_PID);
            %             disp("Number of connected MCP2210 Devices with the default VID&PID are: " + numDev);
        end
        
        function unload_MCP2210_DLL()
            % If library is already loaded, do nothing else
            if (libisloaded(MCP2210_USB2SPI.DEFAULT_LIBNAME))
                unloadlibrary(MCP2210_USB2SPI.DEFAULT_LIBNAME)
            end
        end
    end
    
    methods (Access = private)
        %% Value to Pointers Conversion
        function ptr = toUINT8Ptr(varargin)
            if nargin == 1
                ptr = libpointer('uint8Ptr', uint8(0));
            elseif nargin == 2
                if isnumeric(varargin{2}) % strcmpi(class(varargin{2}), 'uint8')
                    ptr = libpointer('uint8Ptr', uint8(varargin{2}));
                else
                    error("Input argument is not a number");
                end
            else
                error("Only one numerical argument is allowed.");
            end
        end
        
        function ptr = toUINT16Ptr(varargin)
            if nargin == 1
                ptr = libpointer('uint16Ptr', uint16(0));
            elseif nargin == 2 % Value is 2 cuz the first argument is the object of the class
                if isnumeric(varargin{2}) % strcmpi(class(varargin{2}), 'uint16')
                    ptr = libpointer('uint16Ptr', uint16(varargin{2}));
                else
                    error("Input argument is not a number");
                end
            else
                error("Only one numerical argument is allowed.");
            end
        end
        
        function ptr = toUINT32Ptr(varargin)
            if nargin == 1 % Obj is the first argument
                ptr = libpointer('uint32Ptr', uint32(0));
            elseif nargin == 2 % Value is 2 cuz the first argument is the object of the class
                if isnumeric(varargin{2}) % strcmpi(class(varargin{2}), 'uint32')
                    ptr = libpointer('uint32Ptr', uint32(varargin{2}));
                else
                    error("Input argument is not a number");
                end
            else
                error("Only one numerical argument is allowed.");
            end
        end
        
        function ptr = toSTRINGPtr(varargin)
            if nargin == 1
                ptr = libpointer('stringPtr', "");
            elseif nargin == 2 % Value is 2 cuz the first argument is the object of the class
                if ischar(varargin{2}) % strcmpi(class(varargin{2}), 'string')
                    ptr = libpointer('stringPtr', string(varargin{2}));
                else
                    error("Input argument is not a string");
                end
            else
                error("Only one string argument is allowed.");
            end
        end
        
        function obj = ptrs2vals(obj)
            %ptrs2vals Updates the pointers with their values
            %equivalent
            global spiModePtr activeCSstatePtr idleCSstatePtr baudRatePtr...
                cs2dataDlyPtr data2csDlyPtr data2dataDlyPtr txferSizePtr
            
            obj.activeCSstate	 = activeCSstatePtr.value;
            obj.idleCSstate		 = idleCSstatePtr.value;
            obj.baudRate		 = baudRatePtr.value;
            obj.cs2dataDly		 = cs2dataDlyPtr.value;
            obj.data2csDly		 = data2csDlyPtr.value;
            obj.data2dataDly	 = data2dataDlyPtr.value;
            obj.txferSize		 = txferSizePtr.value;
            obj.spiMode          = spiModePtr.value;
        end
        
        function obj = vals2ptrs(obj)
            %vals2ptrs Updates the values from their values
            %equivalent
            
            global spiModePtr activeCSstatePtr idleCSstatePtr baudRatePtr...
                cs2dataDlyPtr data2csDlyPtr data2dataDlyPtr txferSizePtr
            
            activeCSstatePtr	= obj.toUINT32Ptr(obj.activeCSstate);
            idleCSstatePtr		= obj.toUINT32Ptr(obj.idleCSstate);
            baudRatePtr			= obj.toUINT32Ptr(obj.baudRate);
            cs2dataDlyPtr		= obj.toUINT32Ptr(obj.cs2dataDly);
            data2csDlyPtr		= obj.toUINT32Ptr(obj.data2csDly);
            data2dataDlyPtr		= obj.toUINT32Ptr(obj.data2dataDly);
            txferSizePtr		= obj.toUINT32Ptr(obj.txferSize);
            spiModePtr			= obj.toUINT8Ptr(obj.spiMode);
        end
        
    end
    
    methods
        
        function obj = MCP2210_USB2SPI(varargin)
            %MCP2210_USB2SPI Constructs an instance of the MCP2210_USB2SPI class
            %   This constructor loads the manufacturer's dll and allows
            %   the functions to be callable in this mlibrary. It also
            %   initilizes the device for communcation and transfers the
            %   default or user specified settings for communication.
            %   The settings include:
            %
            
            %             MCP2210_USB2SPI.load_MCP2210_DLL();
            
            %             global spiModePtr activeCSstatePtr idleCSstatePtr baudRatePtr...
            %         cs2dataDlyPtr data2csDlyPtr data2dataDlyPtr txferSizePtr csPinPtr
            
            numDev = MCP2210_USB2SPI.totalNumMCP2210s();
            if numDev == 0
                error("There are no MCP2210 (USB to SPI) breakout boards connected. ");
            end
            
            % Code to implement user defined values
            param = struct(...
                'devIndex',         uint32(numDev - 1),...
                'devSerialNum',     "",...
                'spiMode',          MCP2210_USB2SPI.DEFAULT_SPI_MODE,...
                'activeCSstate',    MCP2210_USB2SPI.DEFAULT_CS_ACTIVE_STATE,...
                'idleCSstate',      MCP2210_USB2SPI.DEFAULT_CS_IDLE_STATE,...
                'baudRate',         MCP2210_USB2SPI.DEFAULT_BAUDRATE,...
                'cs2dataDly',       MCP2210_USB2SPI.DEFAULT_CS2DATA_DLY,...
                'data2csDly',       MCP2210_USB2SPI.DEFAULT_DATA2CS_DLY,...
                'data2dataDly',     MCP2210_USB2SPI.DEFAULT_DATA2DATA_DLY,...
                'txferSize',        MCP2210_USB2SPI.DEFAULT_TXFERSIZE,...
                'csPin',            MCP2210_USB2SPI.DEFAULT_CSPIN,...
                'gpioPinDes',       MCP2210_USB2SPI.DEFAULT_GPIO_PIN_DES,...
                'dfltGpioOutput',   MCP2210_USB2SPI.DEFAULT_GPIO_OUTPUT,...
                'dfltGpioDir',      MCP2210_USB2SPI.DEFAULT_GPIO_DIRECTION,...
                'rmtWkupEn',        MCP2210_USB2SPI.DEFAULT_REM_WAKEUP_EN,...
                'intPinMd',         MCP2210_USB2SPI.DEFAULT_INT_PIN_MODE,...
                'spiBusRelEn',      MCP2210_USB2SPI.DEFAULT_SPI_BUS_REL_EN,...
                'libname',          MCP2210_USB2SPI.DEFAULT_LIBNAME);
            
            % read the acceptable names
            paramNames = fieldnames(param);
            
            % Ensure variable entries are pairs
            nArgs = length(varargin);
            if round(nArgs/2)~=nArgs/2
                error('MCP2210_USB2SPI needs propertyName/propertyValue pairs')
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
            
            obj.devIndex        = param.devIndex;
            obj.devSerialNum    = param.devSerialNum;
            obj.spiMode 		= uint8(param.spiMode);
            obj.activeCSstate 	= uint32(param.activeCSstate);
            obj.idleCSstate 	= uint32(param.idleCSstate);
            obj.baudRate 		= uint32(param.baudRate);
            obj.cs2dataDly 		= uint32(param.cs2dataDly);
            obj.data2csDly 		= uint32(param.data2csDly);
            obj.data2dataDly 	= uint32(param.data2dataDly);
            obj.txferSize 		= uint32(param.txferSize);
            obj.csPin           = uint32(param.csPin);
            obj.gpioPinDes      = uint8(param.gpioPinDes);
            obj.dfltGpioOutput  = uint32(param.dfltGpioOutput);
            obj.dfltGpioDir     = uint32(param.dfltGpioDir);
            obj.rmtWkupEn       = uint8(param.rmtWkupEn);
            obj.intPinMd        = uint32(param.intPinMd);
            obj.spiBusRelEn     = uint32(param.spiBusRelEn);
            obj.libname			= param.libname;
            
            obj.vals2ptrs();
            
            % Initialize SPI Communication
            [obj.devHandle, obj.devPathPtr, obj.devPathSizePtr] = obj.initByIndex(obj.devIndex);
            
            cfgStorageLoc = MCP2210_USB2SPI.VM_CONFIG; % designates current chip setting - Volatile Memory
            % cfgStorageLoc = MCP2210_USB2SPI.NVRAM_CONFIG; % designates power-up chip setting - NVRAM
            
            status = obj.setGPIOSettings(cfgStorageLoc, obj.gpioPinDes, ...
                 obj.dfltGpioOutput, obj.dfltGpioDir, obj.rmtWkupEn,...
                 obj.intPinMd, obj.spiBusRelEn);
            
            status = obj.setSPISettings(cfgStorageLoc, obj.baudRate, obj.idleCSstate, ...
                obj.activeCSstate, obj.cs2dataDly, obj.data2csDly,...
                obj.data2dataDly, obj.txferSize, obj.spiMode);
        end
        
        
        function [devHandle, devPathPtr, devPathSizePtr] = initByIndex(obj, devIndex)
            %initByIndex Initializes Serial Communication
            %   Detailed explanation goes here
            
            devPathSizePtr = obj.toUINT32Ptr();
            devPathPtr = obj.toSTRINGPtr();
            
            devHandle = calllib(obj.libname,'Mcp2210_OpenByIndex', ...
                MCP2210_USB2SPI.DEFAULT_VID, MCP2210_USB2SPI.DEFAULT_PID,...
                devIndex, devPathPtr, devPathSizePtr);
            
            %             err = calllib(obj.libname,'Mcp2210_GetLastError'); % Check to see if there were any error
            obj.catchErr();
        end
        
        function devIndex = getDevIndex(obj)
            devIndex = obj.devIndex;
        end
        
        function [status, serialNum, obj] = getDevSerialNum(obj)
            %getDevSerialNum Gets the Serial number of the current device from device
            % Todo Not working properly yet 
            serialNumPtr = obj.toSTRINGPtr(...
                repmat('', MCP2210_USB2SPI.SERIAL_NUMBER_LENGTH, 1));
            status = calllib(obj.libname, 'Mcp2210_GetSerialNumber',...
                obj.devHandle, serialNumPtr);
            obj.catchErr(status);
            serialNum = serialNumPtr.value;
            obj.devSerialNum = serialNum;
        end
        
        function status = terminate(obj)
            try
                status = calllib(obj.libname, 'Mcp2210_Close', obj.devHandle);
                obj.catchErr(status);
            catch ME
                rethrow(ME);
            end
            obj.unload_MCP2210_DLL();
        end
        
        
        %% SPI Related Functions
        function status = getSPISettings(obj, cfgStorageLoc)
            %getSPISettings Gets the settings of SPI communication, prints it and sets the.
            %	Parameters:
            %	Inputs:
            %	 - uint8 cfgSelector 	- current/power-up chip setting selection.
            %							Valid values are:
            %								- MCP2210_VM_CONFIG: designates current chip setting (Volatile Memory)
            %								- MCP2210_NVRAM_CONFIG: designates power-up chip setting (NVRAM)
            %	Outputs:
            %	 - uint32 baudRate 		- transfer speed. Cannot be NULL.
            %
            %	 - uint32 idleCSstate 	- IDLE chip select value. Cannot be NULL.
            %							bit31 - - - - bit8 							  bit0
            %							x     x ... x CS8 CS7 CS6 CS5 CS4 CS3 CS2 CS1 CS0
            %
            %	 - uint32 activeCSstate - Active Chip Select Value. Cannot be NULL.
            %							bit31 - - - - bit8 							  bit0
            %							x     x ... x CS8 CS7 CS6 CS5 CS4 CS3 CS2 CS1 CS0
            %
            %	 - uint32 cs2dataDly 	- Chip Select to Data Delay (quanta of 100 us)
            %							- 16-bit value => max value is (2^16-1).
            %							- Cannot be NULL.
            %
            %	 - uint32 data2csDly 	- Last Data Byte to CS (de-asserted) Delay (quanta of 100 us)
            %							- 16-bit value => max value is (2^16) -1.
            %							- Cannot be NULL.
            %
            %	 - uint32 data2dataDly 	- Delay Between Subsequent Data Bytes (quanta of 100 us)
            %							- 16-bit value => max value is (2^16) -1.
            %							- Cannot be NULL.
            %
            %	 - uint32 txferSize 	- Bytes to Transfer per SPI Transaction.
            %							- 16-bit value => max value is (2^16) -1.
            %							- Cannot be NULL.
            %
            %	 - uint8 spiMode 		- SPI Mode. Cannot be NULL.
            %							Valid values are: 0, 1, 2, 3
            global spiModePtr activeCSstatePtr idleCSstatePtr baudRatePtr...
                cs2dataDlyPtr data2csDlyPtr data2dataDlyPtr txferSizePtr
            
            status = calllib(obj.libname,'Mcp2210_GetSpiConfig' ,obj.devHandle,...
                cfgStorageLoc, baudRatePtr, idleCSstatePtr,...
                activeCSstatePtr, cs2dataDlyPtr,...
                data2csDlyPtr, data2dataDlyPtr,...
                txferSizePtr, spiModePtr);
            
            obj.catchErr(status); % Check for errors
            obj.ptrs2vals();
            
            str = sprintf([                              ...
                'Baud Rate:  		%s\n'	,...
                'CS Idle Val: 		%s\n'	,...
                'CS Active Val:		%s\n'	,...
                'CS to Data Dly: 	%s\n'	,...
                'data to CS Dly: 	%s\n'	,...
                'data to Data Dly: 	%s\n'	,...
                'txfer Size Ptr: 	%s\n'	,...
                'spiMode: 			%s\n']	,...
                num2str(obj.baudRate)  		,...
                num2str(obj.idleCSstate)    ,...
                num2str(obj.activeCSstate)  ,...
                num2str(obj.cs2dataDly)   	,...
                num2str(obj.data2csDly)   	,...
                num2str(obj.data2dataDly) 	,...
                num2str(obj.txferSize) 		,...
                num2str(obj.spiMode));
            fprintf(str);
        end
        
        function status = setSPISettings(obj, cfgStorageLoc, baudRate, idleCSstate, ...
                activeCSstate, cs2dataDly, data2csDly, data2dataDly, txferSize, spiMode)
            %setSPISettings Set the SPI transfer settings for current (VM) configuration or for power-up default (NVRAM) SPI configuration.
            %	Parameters:
            %	Inputs:
            %	 - uint8 cfgSelector 	- current/power-up chip setting selection.
            %							Valid values are:
            %								- MCP2210_VM_CONFIG: designates current chip setting (Volatile Memory)
            %								- MCP2210_NVRAM_CONFIG: designates power-up chip setting (NVRAM)
            %	 - uint32 baudRate 		- transfer speed. Cannot be NULL.
            %
            %	 - uint32 idleCSstate 	- IDLE chip select value. Cannot be NULL.
            %							bit31 - - - - bit8 							  bit0
            %							x     x ... x CS8 CS7 CS6 CS5 CS4 CS3 CS2 CS1 CS0
            %
            %	 - uint32 activeCSstate - Active Chip Select Value. Cannot be NULL.
            %							bit31 - - - - bit8 							  bit0
            %							x     x ... x CS8 CS7 CS6 CS5 CS4 CS3 CS2 CS1 CS0
            %
            %	 - uint32 cs2dataDly 	- Chip Select to Data Delay (quanta of 100 us)
            %							- 16-bit value => max value is (2^16-1).
            %							- Cannot be NULL.
            %
            %	 - uint32 data2csDly 	- Last Data Byte to CS (de-asserted) Delay (quanta of 100 us)
            %							- 16-bit value => max value is (2^16) -1.
            %							- Cannot be NULL.
            %
            %	 - uint32 data2dataDly 	- Delay Between Subsequent Data Bytes (quanta of 100 us)
            %							- 16-bit value => max value is (2^16) -1.
            %							- Cannot be NULL.
            %
            %	 - uint32 txferSize 	- Bytes to Transfer per SPI Transaction.
            %							- 16-bit value => max value is (2^16) -1.
            %							- Cannot be NULL.
            %
            %	 - uint8 spiMode 		- SPI Mode. Cannot be NULL.
            %							Valid values are: 0, 1, 2, 3
            
            status = calllib(obj.libname,'Mcp2210_SetSpiConfig' ,obj.devHandle,...
                cfgStorageLoc, obj.toUINT32Ptr(baudRate), obj.toUINT32Ptr(idleCSstate),...
                obj.toUINT32Ptr(activeCSstate), obj.toUINT32Ptr(cs2dataDly),...
                obj.toUINT32Ptr(data2csDly), obj.toUINT32Ptr(data2dataDly),...
                obj.toUINT32Ptr(txferSize), obj.toUINT8Ptr(spiMode));
            obj.catchErr(status);
        end
        
        function [status, rxData] = transfer(obj, txCmd, varargin)
            %transfer Transfers cmd or data through SPI.
            
            if ~strcmpi(class(txCmd), 'uint8')
                error("Input buffer is not of type 'uint8' array." + ...
                    "Please convert data before transfer.");
            else
                txSize = length(txCmd);
                if nargin == 3 && isnumeric(varargin{1})
                    rxSize = varargin{1};
                else
                    rxSize = txSize;
                end

                sizePtr = obj.toUINT32Ptr(rxSize);
                txCmdPtr = obj.toUINT8Ptr(uint8(txCmd));
                rxData = zeros(1, rxSize);
                rxDataPtr = obj.toUINT8Ptr(uint8(rxData));
                bdRatePtr = obj.toUINT32Ptr(obj.baudRate);
                status = calllib(obj.libname,'Mcp2210_xferSpiData',...
                    obj.devHandle, txCmdPtr, rxDataPtr, bdRatePtr,...
                    sizePtr, obj.csPin);
                
                % (2:end) exists below cuz the process always seems to 
                %   first read the value from the previous SPI stream.  
                %   Possibly a bug in the API.(2:end) is not needed if the
                %   function is called twice. Once to send cmd, and send to
                %   send a null parameter and receive Data.
                rxData = rxDataPtr.value; % (2:end); 
                obj.catchErr(status);
                
                % Wait for SPI process to complete
                spiTxferStat = 0x01;
                while(spiTxferStat > 0)
                    [~, ~, ~, spiTxferStat] = getSPIStatus(obj);
                    disp("Waiting for SPI...");
                end
            end
        end
        
        function [status, rxData] = send(obj, txCmd)
            [status, rxData] = transfer(obj, txCmd);
        end
        
        function [status, rxData] = receive(obj, rxSize)
            [status, rxData] = transfer(obj, uint8(255), rxSize);
        end
        
        function [status, spiExtReqStat, spiOwner, spiTxferStat] ...
                = getSPIStatus(obj)
            
            spiExtReqStatPtr = obj.toUINT8Ptr(uint8(1));
            spiOwnerPtr = obj.toUINT8Ptr(uint8(0));
            spiTxferStatPtr = obj.toUINT8Ptr(uint8(1));
            
            status = calllib(obj.libname,'Mcp2210_GetSpiStatus', ...
                obj.devHandle, spiExtReqStatPtr, spiOwnerPtr,...
                spiTxferStatPtr);
            obj.catchErr(status);
            
            spiExtReqStat = spiExtReqStatPtr.value;
            spiOwner = spiOwnerPtr.value;
            spiTxferStat = spiTxferStatPtr.value;
        end
          
        %% GPIO Related Functions
        % Please note, the device comm handle is called within each
        % function
        
        function [status, pinDirs] = getGPIOPinDirs(obj)
            %getGPIOPinDirs Gets the pin direction of all GPIO pins
            %	The function gets the current directions of all pins
            %	configured as GPIO pins. 
            %   Where:
            %   0 is Output Direction for each pin
            %   1 is Input Direction for each pin
            
            pinDirsPtr = obj.toUINT32Ptr();
            status = calllib(obj.libname,'Mcp2210_GetGpioPinDir' ,...
                obj.devHandle, pinDirsPtr);
            obj.catchErr(status); % Check for errors
            pinDirs = pinDirsPtr.value;
        end
        
        function status = setGPIOPinDirs(obj, gpioDirs)
            %setGPIOPinDirs Sets the pin direction for all GPIO pins
            %	The function gets the current directions of all pins
            %	configured as GPIO pins. 
            %   Where:
            %   0 is Output Direction for each pin
            %   1 is Input Direction for each pin
            
            status = calllib(obj.libname,'Mcp2210_SetGpioPinDir' ,...
                obj.devHandle, uint32(gpioDirs));
            obj.catchErr(status); % Check for errors
        end
        
        function [status, pinVals] = getGPIOPinVals(obj)
            %getGPIOPinVals Gets the states (Hi/Lo) for all GPIO pins
            %	The function gets the current GPIO Pin states/values of
            %	all pins configured as GPIO pins. Hence for
            
            pinValsPtr = obj.toUINT32Ptr();
            status = calllib(obj.libname,'Mcp2210_GetGpioPinVal' ,...
                obj.devHandle, pinValsPtr);
            obj.catchErr(status); % Check for errors
            pinVals = pinValsPtr.value;
        end
        
        function [status, retPinVals] = setGPIOPinVals(obj, pinVals)
            %getGPIOPinVals Gets the states (Hi/Lo) for all GPIO pins
            %	The function gets the current GPIO Pin states/values of
            %	all pins configured as GPIO pins. Hence for
            
            retPinValsPtr = obj.toUINT32Ptr();
            status = calllib(obj.libname,'Mcp2210_SetGpioPinVal' ,...
                obj.devHandle, pinVals, retPinValsPtr);
            obj.catchErr(status); % Check for errors
            retPinVals = retPinValsPtr.value;
        end
        
        function [status, pinVal] = readPin(obj, pinNum)
            [status, pinVals] = getGPIOPinVals(obj);
            pinVal = bitget(pinVals, pinNum+1, 'uint32');
%             pinNumMask = bitshift(1, pinNum);
%             pinVal = bitshift(bitand(pinVals, pinNumMask), -pinNum);
        end
        
        function [status, retPinVal] = writePin(obj, pinNum, setPinVal)
            %writePin Writes a specified bit to the specified pin
            %   Inputs:
            %       - obj - MCP2210 object (alternative: use dot formation:
            %          obj.function(arguments)
            %       - pinNum - Pin index on MCP2210 from 0 to 8
            %       - setPinVal - Pin value between 0 and 1
            %   Outputs:
            %       - status - 0 means success
            
%             [~, currentPinVals] = getGPIOPinVals(obj);
%             pinVals = bitset(currentPinVals, pinNum+1, setPinVal,'uint32') % pinNum+1 because matlab indexes from 1 not 0
            
            if setPinVal == 1
                pinVals = uint32(161);
            else
                pinVals = uint32(129);
            end
            [status, retPinVals] = setGPIOPinVals(obj, pinVals);
            retPinVal = bitget(retPinVals, pinNum+1, 'uint32');
            
            if(retPinVal ~= setPinVal)
                warning("Pin was not set correctly!");
            end
        end
        
        function [status, obj] = getGPIOSettings(obj, cfgStorageLoc)
            %getSPISettings Provides the current GPIO configuration or the power-up default (NVRAM) GPIO configuration.
            %	Description: Provides the current GPIO configuration or the power-up default (NVRAM) GPIO configuration.
            %	Parameters:
            %
            %	Inputs:
            %		- voidPtr handle                - The pointer to the device handle. Cannot be NULL.
            %		- uint8 cfgSelector             - current/power-up chip setting selection.
            %											Valid values are:
            %											- MCP2210_VM_CONFIG: designates current chip setting (Volatile Memory)
            %											- MCP2210_NVRAM_CONFIG: designates power-up chip setting (NVRAM)
            %
            %	Outputs:
            %		- uint8Ptr gpioPinDes          - GPIO Pin Designation array. Cannot be NULL.
            %											Array length is MCP2210_GPIO_NR.
            %											Valid values for pin designation are:
            %											- MCP2210_PIN_DES_GPIO
            %											- MCP2210_PIN_DES_CS
            %											- MCP2210_PIN_DES_FN
            %		- uint32Ptr dfltGpioOutput      - GPIO pin output values. Cannot be NULL
            %		- uint32Ptr dfltGpioDir         - GPIO pin direction. Cannot be NULL
            %		- uint8Ptr rmtWkupEn            - remote wake-up setting. Cannot be NULL
            %											Valid values:
            %											- MCP2210_REMOTE_WAKEUP_ENABLE
            %											- MCP2210_REMOTE_WAKEUP_DISABLED
            %		- uint8Ptr intPinMd            - interrupt pulse count mode. Cannot be NULL.
            %											Valid values are:
            %											- MCP2210_INT_MD_CNT_HIGH_PULSES
            %											- MCP2210_INT_MD_CNT_LOW_PULSES
            %											- MCP2210_INT_MD_CNT_RISING_EDGES
            %											- MCP2210_INT_MD_CNT_FALLING_EDGES
            %											- MCP2210_INT_MD_CNT_NONE
            %		- uint8Ptr spiBusRelEn          - SPI Bus Release option. Cannot be NULL.
            %											Valid values are:
            %											- MCP2210_SPI_BUS_RELEASE_ENABLED
            %											- MCP2210_SPI_BUS_RELEASE_DISABLED
            %
            %	Returns:
            %		- 0 for success: 		E_SUCCESS
            %		- negative error code: 	E_ERR_NULL, E_ERR_INVALID_HANDLE_VALUE
            %								E_ERR_UNKOWN_ERROR, E_ERR_INVALID_PARAMETER
            %								E_ERR_HID_TIMEOUT, E_ERR_HID_RW_FILEIO
            %								E_ERR_CMD_ECHO, E_ERR_CMD_FAILED
            
            gpioPinDesPtr       = obj.toUINT8Ptr();
            dfltGpioOutputPtr   = obj.toUINT32Ptr();
            dfltGpioDirPtr      = obj.toUINT32Ptr();
            rmtWkupEnPtr        = obj.toUINT8Ptr();
            intPinMdPtr         = obj.toUINT8Ptr();
            spiBusRelEnPtr      = obj.toUINT8Ptr();
            
            status = calllib(obj.libname,'Mcp2210_GetGpioConfig' ,...
                obj.devHandle, cfgStorageLoc,...
                gpioPinDesPtr, dfltGpioOutputPtr,...
                dfltGpioDirPtr, rmtWkupEnPtr,...
                intPinMdPtr, spiBusRelEnPtr);
            
            obj.catchErr(status); % Check for errors
            
            obj.gpioPinDes		= gpioPinDesPtr.value;
            obj.dfltGpioOutput	= dfltGpioOutputPtr.value;
            obj.dfltGpioDir		= dfltGpioDirPtr.value;
            obj.rmtWkupEn 		= rmtWkupEnPtr.value;
            obj.intPinMd  		= intPinMdPtr.value;
            obj.spiBusRelEn		= spiBusRelEnPtr.value;
            
            
             str = sprintf([                     ...
                'GPIO Pin Desc:         %s\n'	,...
                'Default GPIO Val:      %s\n'	,...
                'Default GPIO Dir:      %s\n'	,...
                'Remote Wakeup Enbld:   %s\n'	,...
                'Interupt Pin Mode:     %s\n'	,...
                'SPI Bus Release Enbld: %s\n']	,...
                num2str(obj.gpioPinDes)         ,...
                num2str(obj.dfltGpioOutput)     ,...
                num2str(obj.dfltGpioDir)        ,...
                num2str(obj.rmtWkupEn)          ,...
                num2str(obj.intPinMd)           ,...
                num2str(obj.spiBusRelEn));
            fprintf(str);
            
        end
        
        function [status, obj] = setGPIOSettings(obj, cfgStorageLoc, gpioPinDes, ...
                 dfltGpioOutput, dfltGpioDir, rmtWkupEn, intPinMd, spiBusRelEn)
            %setSPISettings Sets the current GPIO configuration or the power-up default (NVRAM) GPIO configuration.
            %	Description: Sets the current GPIO configuration or the power-up default (NVRAM) GPIO configuration.
            %	Parameters:
            %
            %	Inputs:
            %		- voidPtr handle                - The pointer to the device handle. Cannot be NULL.
            %		- uint8 cfgSelector             - current/power-up chip setting selection.
            %											Valid values are:
            %											- MCP2210_VM_CONFIG: designates current chip setting (Volatile Memory)
            %											- MCP2210_NVRAM_CONFIG: designates power-up chip setting (NVRAM)
            %
            %	Outputs:
            %		- uint8Ptr gpioPinDes          - GPIO Pin Designation array. Cannot be NULL.
            %											Array length is MCP2210_GPIO_NR.
            %											Valid values for pin designation are:
            %											- MCP2210_PIN_DES_GPIO
            %											- MCP2210_PIN_DES_CS
            %											- MCP2210_PIN_DES_FN
            %		- uint32Ptr dfltGpioOutput      - GPIO pin output values. Cannot be NULL
            %		- uint32Ptr dfltGpioDir         - GPIO pin direction. Cannot be NULL
            %		- uint8Ptr rmtWkupEn            - remote wake-up setting. Cannot be NULL
            %											Valid values:
            %											- MCP2210_REMOTE_WAKEUP_ENABLE
            %											- MCP2210_REMOTE_WAKEUP_DISABLED
            %		- uint8Ptr intPinMd            - interrupt pulse count mode. Cannot be NULL.
            %											Valid values are:
            %											- MCP2210_INT_MD_CNT_HIGH_PULSES
            %											- MCP2210_INT_MD_CNT_LOW_PULSES
            %											- MCP2210_INT_MD_CNT_RISING_EDGES
            %											- MCP2210_INT_MD_CNT_FALLING_EDGES
            %											- MCP2210_INT_MD_CNT_NONE
            %		- uint8Ptr spiBusRelEn          - SPI Bus Release option. Cannot be NULL.
            %											Valid values are:
            %											- MCP2210_SPI_BUS_RELEASE_ENABLED
            %											- MCP2210_SPI_BUS_RELEASE_DISABLED
            %
            %	Returns:
            %		- 0 for success: 		E_SUCCESS
            %		- negative error code: 	E_ERR_NULL, E_ERR_INVALID_HANDLE_VALUE
            %								E_ERR_UNKOWN_ERROR, E_ERR_INVALID_PARAMETER
            %								E_ERR_HID_TIMEOUT, E_ERR_HID_RW_FILEIO
            %								E_ERR_CMD_ECHO, E_ERR_CMD_FAILED
            
            gpioPinDesPtr       = obj.toUINT8Ptr(gpioPinDes);
            
            status = calllib(obj.libname,'Mcp2210_SetGpioConfig' ,...
                obj.devHandle, cfgStorageLoc,...
                gpioPinDesPtr, dfltGpioOutput,...
                dfltGpioDir, rmtWkupEn,...
                intPinMd, spiBusRelEn);
            
            obj.catchErr(status); % Check for errors
        end
        
        %% Error Catching Function
        function errCode = catchErr(obj, varargin)
            %MCP2210_catchErr Converts MCP2210 (USB to SPI) error codes to warnings or
            %errors so the user can take correction steps
            %   errorCode could range from 0 to -401.
            %   errorCode = 0 means process was sucessful
            
            if nargin == 1
                errCode = calllib(obj.libname,'Mcp2210_GetLastError'); % Check to see if there were any error
            elseif nargin == 2
                errCode = varargin{1};
            end
            switch errCode
                case  0
                    % Do Nothing Since Successful
                case -1
                    error("ERR_UNKOWN_ERROR");
                case -2
                    error("ERR_INVALID_PARAMETER");
                case -3
                    error("ERR_BUFFER_TOO_SMALL");
                    
                    % memory access errors
                case -10  % NULL pointer parameter
                    error("ERR_NULL_PTR_PARAM");
                case -20  % memory allocation error
                    error("ERR_MALLOC");
                case -30  % invalid file handler use
                    error("ERR_INVALID_HANDLE_VALUE");
                    
                    % errors connecting to HID device
                case -100
                    error("ERR_FIND_DEV");
                case -101  % we tried to connect to a device with a non existent index
                    error("ERR_NO_SUCH_INDEX");
                case -103 % no device matching the provided criteria was found
                    warning("DEVICE NOT FOUND");
                case -104  % internal function buffer is too small
                    error("ERR_INTERNAL_BUFFER_TOO_SMALL");
                case -105  % an error occurred when trying to get the device handle
                    error("ERR_OPEN_DEVICE_ERROR");
                case -106 % connection already opened
                    error("CONNECTION ALREADY OPEN!");
                case -107
                    error("ERR_CLOSE_FAILED");
                case -108  % no device found with the given serial number
                    error("ERR_NO_SUCH_SERIALNUM");
                case -110  % HID file operation timeout. Device may be disconnected
                    error("ERR_HID_RW_TIMEOUT");
                case -111  % HID file operation unknown error. Device may be disconnected
                    error("ERR_HID_RW_FILEIO");
                    
                    % MCP2210 device command reply errors
                case -200
                    error("ERR_CMD_FAILED");
                case -201
                    error("ERR_CMD_ECHO");
                case -202
                    error("ERR_SUBCMD_ECHO");
                case -203  % SPI configuration change refuzed because transfer is in progress
                    error("ERR_SPI_CFG_ABORT");
                case -204  % the SPI bus is owned by external master, data transfer not possible
                    error("ERR_SPI_EXTERN_MASTER");
                case -205  % SPI transfer attempts exceeded the MCP2210_XFER_RETRIES threshold
                    error("ERR_SPI_TIMEOUT");
                case -206  % the number of bytes received after the SPI transfer
                    % is less than configured transfer size
                    error("ERR_SPI_RX_INCOMPLETE");
                case -207
                    error("ERR_SPI_XFER_ONGOING");
                    
                    % MCP2210 device password protection
                case -300   % the command cannot be executed because the device settings are
                    % either password protected or permanently locked
                    error("ERR_BLOCKED_ACCESS ");
                case -301   % EEPROM write failure due to FLASH memory failure
                    error("ERR_EEPROM_WRITE_FAIL");
                case -350   % NVRAM is permanently locked, no password is accepted
                    error("ERR_NVRAM_LOCKED");
                case -351   % password mismatch, but number of attempts is less than 5
                    error("ERR_WRONG_PASSWD");
                case -352   % password mismatch, but the number of attempts exceeded 5,
                    % so the NVRAM access is denied until the next device reset
                    error("ERR_ACCESS_DENIED");
                case -353   % NVRAM access control protection is already enabled, so
                    % the attempt to enable it twice is rejected
                    error("ERR_NVRAM_PROTECTED");
                case -354   % NVRAM access control is not enabled, so password change is
                    % not allowed
                    error("ERR_PASSWD_CHANGE");
                    
                    % MCP2210 USB descriptors
                case -400   % the NVRAM string descriptor is invalid
                    error("ERR_STRING_DESCRIPTOR");
                case -401   % the size of the input string exceds the limit
                    error("ERR_STRING_TOO_LARGE");
                
                % Error codes based on functions
            end
        end
        
    end
end
