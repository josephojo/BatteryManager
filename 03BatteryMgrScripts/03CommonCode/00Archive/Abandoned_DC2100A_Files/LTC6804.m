classdef LTC6804
    %LTC6804 Class of the LTC6804 Device used in DC2100A.m
    %   Detailed explanation goes here
    
    
    
    %% Configuration Register Group specified by datasheet Table 46: memory Bit Descriptions
    % (API) todo - some of this stuff could be dependent upon ADC bits, Number of GPIO, and Number of cells
    properties (Access = private)
        % ADCOPT:
        %   0 -> Selects Modes 27kHz, 7kHz or 26Hz with MD[1:0] Bits
        %       in ADC Conversion Commands.
        %   1 -> Selects Modes 14kHz, 3kHz or 2kHz with MD[1:0] Bits
        %       in ADC Conversion Commands.
        CFGR0_ADCOPT_MASK       = LTC6804.CFGR0_ADCOPT(1);
        
        % SWTEN Pin Status (Read Only):
        %   1 -> SWTEN Pin at Logic 1
        %   0 -> SWTEN Pin at Logic 0
        CFGR0_SWTRD_MASK        = 0x02;
        
        % 1 -> Reference Remains Powered Up Until Watchdog Timeout
        % 0 -> Reference Shuts Down after Conversions
        CFGR0_REFON_MASK        = LTC6804.CFGR0_REFON(1);
        
        % Write:
        %   0 -> GPIOx Pin Pull-Down ON;
        %   1 -> GPIOx Pin Pull-Down OFF Read:
        %   0 -> GPIOx Pin at Logic 0;
        %   1 -> GPIOx Pin at Logic 1
        CFGR0_GPIOx_MASK        = LTC6804.CFGR0_GPIOx(0x1F);
        
        % Comparison voltage = (VUV + 1) • 16 • 100µV
        % Default:  VUV  =  0x000
        CFGR1_VUV_MASK          = LTC6804.CFGR1_VUV(0xFFF);
        
        % Comparison voltage = VOV • 16 • 100µV
        % Default:  VOV  =  0x000
        CFGR2_VOV_MASK          = LTC6804.CFGR2_VOV(0xFFF);
        
        % x = 1 to 12
        %  1 -> Turn ON Shorting Switch for Cell x
        %  0 -> Turn OFF Shorting Switch for Cell x (Default)
        CFGR4_DCCx_MASK         = LTC6804.CFGR4_DCCx(0xFFF);
        
        % todo - each value has a different code,
        % with read and write being different.  Enum really necessary?
        CFGR5_DCTO_MASK         = LTC6804.CFGR5_DCTO(0xF);
        
        
    end
    
    % All of these functions were macros in the LTC6804 API
    methods (Static)
        function res = CFGR0_ADCOPT(adcopt)
            res = bitshift(adcopt, 0);         % ADC Mode Option Bit
        end
        
        function res = CFGR0_REFON(ref_on)
            if ref_on == 1
                res = 1;
            else
                res = 0;
            end
            res = bitshift(res, 2); % Reference Powered Up
        end
        
        function res = CFGR0_GPIOx(gpiox)
            res = bitshift(bitand(gpiox, 0x1F), 3); % GPIOx Pin Control
        end
        
        function res = CFGR1_VUV(vuv)
            res = bitshift(bitand(vuv, 0xFFF), 0); % Undervoltage Comparison Voltage*
        end
        
        function res = CFGR2_VOV(vov)
            res = bitshift(bitand(vov, 0xFFF), 4); % Overvoltage Comparison Voltage*
        end
        
        function res = CFGR4_DCCx(dccx)
            res = bitshift(bitand(dccx, 0xFFF), 0);% Discharge Cell x
        end
        
        function res = CFGR5_DCTO(dcto)
            res = bitshift(bitand(dcto, 0xF), 4); % Discharge  Time Out Value
        end
    end
    
    %% Class Properties and Methods
    properties (Constant)
        COMMAND_CODE_BROADCAST_ADDRESS = 0x00; % Address used for an LTC6804 command to be broadcast to all boards
        COMMAND_CODE_ADDRESSED_BIT     = 0x10; % Bit set in address used for an LTC6804 command to be addressed to one board
        COMMAND_CODE_ADDRESS_MASK      = 0x0F; 

        
        % Table used perform PEC calculation defined by datasheet figure 22.
        PEC_SEED_VALUE = uint16(16); % Seed value for PEC group set
        PEC_TABLE = ... % PEC table obtained from (LTC6804-2.c program file).
            uint16([  ...
            0x0000, 0xc599, 0xceab, 0x0b32, 0xd8cf, 0x1d56, 0x1664, 0xd3fd, 0xf407, 0x319e, 0x3aac, ...
            0xff35, 0x2cc8, 0xe951, 0xe263, 0x27fa, 0xad97, 0x680e, 0x633c, 0xa6a5, 0x7558, 0xb0c1, ...
            0xbbf3, 0x7e6a, 0x5990, 0x9c09, 0x973b, 0x52a2, 0x815f, 0x44c6, 0x4ff4, 0x8a6d, 0x5b2e, ...
            0x9eb7, 0x9585, 0x501c, 0x83e1, 0x4678, 0x4d4a, 0x88d3, 0xaf29, 0x6ab0, 0x6182, 0xa41b, ...
            0x77e6, 0xb27f, 0xb94d, 0x7cd4, 0xf6b9, 0x3320, 0x3812, 0xfd8b, 0x2e76, 0xebef, 0xe0dd, ...
            0x2544, 0x02be, 0xc727, 0xcc15, 0x098c, 0xda71, 0x1fe8, 0x14da, 0xd143, 0xf3c5, 0x365c, ...
            0x3d6e, 0xf8f7, 0x2b0a, 0xee93, 0xe5a1, 0x2038, 0x07c2, 0xc25b, 0xc969, 0x0cf0, 0xdf0d, ...
            0x1a94, 0x11a6, 0xd43f, 0x5e52, 0x9bcb, 0x90f9, 0x5560, 0x869d, 0x4304, 0x4836, 0x8daf, ...
            0xaa55, 0x6fcc, 0x64fe, 0xa167, 0x729a, 0xb703, 0xbc31, 0x79a8, 0xa8eb, 0x6d72, 0x6640, ...
            0xa3d9, 0x7024, 0xb5bd, 0xbe8f, 0x7b16, 0x5cec, 0x9975, 0x9247, 0x57de, 0x8423, 0x41ba, ...
            0x4a88, 0x8f11, 0x057c, 0xc0e5, 0xcbd7, 0xe4e,  0xddb3, 0x182a, 0x1318, 0xd681, 0xf17b, ...
            0x34e2, 0x3fd0, 0xfa49, 0x29b4, 0xec2d, 0xe71f, 0x2286, 0xa213, 0x678a, 0x6cb8, 0xa921, ...
            0x7adc, 0xbf45, 0xb477, 0x71ee, 0x5614, 0x938d, 0x98bf, 0x5d26, 0x8edb, 0x4b42, 0x4070, ...
            0x85e9, 0x0f84, 0xca1d, 0xc12f, 0x04b6, 0xd74b, 0x12d2, 0x19e0, 0xdc79, 0xfb83, 0x3e1a, 0x3528, ...
            0xf0b1, 0x234c, 0xe6d5, 0xede7, 0x287e, 0xf93d, 0x3ca4, 0x3796, 0xf20f, 0x21f2, 0xe46b, 0xef59, ...
            0x2ac0, 0x0d3a, 0xc8a3, 0xc391, 0x0608, 0xd5f5, 0x106c, 0x1b5e, 0xdec7, 0x54aa, 0x9133, 0x9a01, ...
            0x5f98, 0x8c65, 0x49fc, 0x42ce, 0x8757, 0xa0ad, 0x6534, 0x6e06, 0xab9f, 0x7862, 0xbdfb, 0xb6c9, ...
            0x7350, 0x51d6, 0x944f, 0x9f7d, 0x5ae4, 0x8919, 0x4c80, 0x47b2, 0x822b, 0xa5d1, 0x6048, 0x6b7a, ...
            0xaee3, 0x7d1e, 0xb887, 0xb3b5, 0x762c, 0xfc41, 0x39d8, 0x32ea, 0xf773, 0x248e, 0xe117, 0xea25, ...
            0x2fbc, 0x0846, 0xcddf, 0xc6ed, 0x0374, 0xd089, 0x1510, 0x1e22, 0xdbbb, 0x0af8, 0xcf61, 0xc453, ...
            0x01ca, 0xd237, 0x17ae, 0x1c9c, 0xd905, 0xfeff, 0x3b66, 0x3054, 0xf5cd, 0x2630, 0xe3a9, 0xe89b, ...
            0x2d02, 0xa76f, 0x62f6, 0x69c4, 0xac5d, 0x7fa0, 0xba39, 0xb10b, 0x7492, 0x5368, 0x96f1, 0x9dc3, ...
            0x585a, 0x8ba7, 0x4e3e, 0x450c, 0x8095 ...
            ]);
        
        % LTC6804 Command Codes Base Address, as defined by datasheet Table 34
        COMMAND_CODE_BASE_WRCFG     = 0x001; % Write Configuration Register Group
        COMMAND_CODE_BASE_RDCFG     = 0x002; % Read Configuration Register Group
        COMMAND_CODE_BASE_RDCVA     = 0x004; % Read Cell Voltage Register Group A
        COMMAND_CODE_BASE_RDCVB     = 0x006; % Read Cell Voltage Register Group B
        COMMAND_CODE_BASE_RDCVC     = 0x008; % Read Cell Voltage Register Group C
        COMMAND_CODE_BASE_RDCVD     = 0x00A; % Read Cell Voltage Register Group D
        COMMAND_CODE_BASE_RDAUXA    = 0x00C; % Read Auxiliary Register Group A
        COMMAND_CODE_BASE_RDAUXB    = 0x00E; % Read Auxiliary Register Group B
        COMMAND_CODE_BASE_RDSTATA   = 0x010; % Read Status Register Group A
        COMMAND_CODE_BASE_RDSTATB   = 0x012; % Read Status Register Group B
        COMMAND_CODE_BASE_ADCV      = 0x260; % Start Cell Voltage ADC Conversion and Poll Status
        COMMAND_CODE_BASE_ADOW      = 0x228; % Start Open Wire ADC Conversion and Poll Status
        COMMAND_CODE_BASE_CVST      = 0x207; % Start Self-Test Cell Voltage Conversion and Poll Status
        COMMAND_CODE_BASE_ADAX      = 0x460; % Start GPIOs ADC Conversion and Poll Status
        COMMAND_CODE_BASE_AXST      = 0x407; % Start Self-Test GPIOs Conversion and Poll Status
        COMMAND_CODE_BASE_ADSTAT    = 0x468; % Start Status group ADC Conversion and Poll Status
        COMMAND_CODE_BASE_STATST    = 0x40F; % Start Self-Test Status group Conversion and Poll Status
        COMMAND_CODE_BASE_ADCVAX    = 0x46F; % Start Combined Cell Voltage and GPIO1, GPIO2 Conversion and Poll Status
        COMMAND_CODE_BASE_CLRCELL   = 0x711; % Clear Cell Voltage Register Group
        COMMAND_CODE_BASE_CLRAUX    = 0x712; % Clear Auxiliary Register Group
        COMMAND_CODE_BASE_CLRSTAT   = 0x713; % Clear Status Register Group
        COMMAND_CODE_BASE_PLADC     = 0x714; % Poll ADC Conversion Status
        COMMAND_CODE_BASE_DIAGN     = 0x715; % Diagnose MUX and Poll Status
        COMMAND_CODE_BASE_WRCOMM    = 0x721; % Write COMM Register Group
        COMMAND_CODE_BASE_RDCOMM    = 0x722; % Read COMM Register Group
        COMMAND_CODE_BASE_STCOMM    = 0x723; % Start I2C/SPI Communication
        
        % LTC6804 Constants
        MAX_BOARDS          = 8;  % The maximum number of DC2100A boards that can be stacked together into one system.
        % Note: the number of boards that can be stacked, is limited by the voltage rating on transformer T15.
        BROADCAST           = LTC6804.MAX_BOARDS;
        COMMAND_SIZE        = 2;  % bytes per command
        REGISTER_GROUP_SIZE = 6;  % bytes per register group
        PEC_SIZE            = 2;  % 15 bit PEC, requires int16 data type
        ADC_SIZE            = 2;  % 16 bit ADC results
        
        % Bit Definitions for adc options are specified by datasheet Table 46.
        ADCOPT_0                    = 0x0;         % 0 -> Selects Modes 27kHz, 7kHz or 26Hz with MD[1:0] Bits in ADC Conversion Commands.
        ADCOPT_1                    = 0x1;        % 1 -> Selects Modes 14kHz, 3kHz or 2kHz with MD[1:0] Bits in ADC Conversion Commands.
        
        % Bit Definitions for command codes are specified by datasheet Table 35.
        MD_MODE_FAST                = 0x1;         % ADC Mode: 27kHz (ADCOPT = 0), 14kHz (ADCOPT = 1)
        MD_MODE_NORMAL              = 0x2;          % ADC Mode: 7kHz  (ADCOPT = 0), 3kHz (ADCOPT = 1)
        MD_MODE_FILTERED            = 0x3;         % ADC Mode: 26Hz (ADCOPT = 0), 2kHz (ADCOPT = 1)
        
        % Bit Definition for discharge permission is specified by datasheet Table 46.
        DCP_DISCHARGE_NOT_PERMITTED = 0;           % Discharge Not Permitted
        DCP_DISCHARGE_PERMITTED     = 1;           % Discharge Permitted
        
        % Bit Definitions for COMM Register Group specified by datasheet Table 46: memory Bit Descriptions
        ICOM_I2C_WRITE_START                            = 0x6;
        ICOM_I2C_WRITE_STOP                             = 0x1;
        ICOM_I2C_WRITE_BLANK                            = 0x0;
        ICOM_I2C_WRITE_NO_TRANSMIT                      = 0x7;
        ICOM_I2C_READ_START                             = 0x6;
        ICOM_I2C_READ_STOP                              = 0x1;
        ICOM_I2C_READ_SDA_LOW                           = 0x0;
        ICOM_I2C_READ_SDA_HIGH                          = 0x7;
        FCOM_WRITE_I2C_ACK                              = 0x0;
        FCOM_WRITE_I2C_NACK                             = 0x8;
        FCOM_WRITE_I2C_NACK_STOP                        = 0x9;
        FCOM_READ_I2C_ACK_FROM_MASTER                   = 0x0;
        FCOM_READ_I2C_ACK_FROM_SLAVE                    = 0x7;
        FCOM_READ_I2C_NACK_FROM_SLAVE                   = 0xF;
        FCOM_READ_I2C_ACK_FROM_SLAVE_STOP_FROM_MASTER   = 0x1;
        FCOM_READ_I2C_NACK_FROM_SLAVE_STOP_FROM_MASTER  = 0x9;
        
        ICOM_SPI_WRITE_CSB_LOW                          = 0x8;
        ICOM_SPI_WRITE_CSB_HIGH                         = 0x9;
        ICOM_SPI_WRITE_NO_TRANSMIT                      = 0xF;
        ICOM_SPI_READ                                   = 0x7;
        FCOM_SPI_WRITE_CSB_LOW                          = 0x8;
        FCOM_SPI_WRITE_CSB_HIGH                         = 0x9;
        FCOM_SPI_READ                                   = 0xF;
        
        % COMM register data bytes must be set to 0xFF when reading.
        COMM_READ_DUMMY                                 = 0xFF;
        
        CS_PIN                                          = 5;
        
        % Timing parameters for state transitions defined by datasheet Figure 1.
        % Electrical Characteristics from datasheet pages 7 and 8 contain worst case values.
        TIDLE                                          = 4300; % us, min value
        TDWELL                                         = 1;    % us, min value of 240ns in datasheet is outside resolution of uP timer.
        TWAKE                                           = 300;     % us, max value
        TSLEEP                                          = 1800;    % ms, min value
        TREADY                                          = 10;      % us, max value
        
        CONVERSION_27KHZ_MODE = 0;  % 27kHz conversion mode
        CONVERSION_14KHZ_MODE = 1;  % 14kHz conversion mode
        CONVERSION_7KHZ_MODE = 2;   % 7kHz conversion mode
        CONVERSION_3KHZ_MODE = 3;   % 3kHz conversion mode
        CONVERSION_2KHZ_MODE = 4;   % 2kHz conversion mode
        CONVERSION_26HZ_MODE = 5;   % 26Hz conversion mode

    end
    
    properties %(Access = private)
        spi
        
        adcopt
    end
    
    
    methods (Static)
        
        % Extracts the upper byte (most significant byte) from a 16 bit
        % value
        function uByte = UPPER_BYTE(val)
            %UPPER_BYTE Extracts the higher byte (MSB) from a 16 bit value
            if ~strcmpi(class(val), 'uint16')
                error("Cannot get the upper byte of value. Data type needs to be of type 'uint16'. It is currently: %s", class(val));
            end
            uByte = bitand(uint8(bitshift(val, -8)), 0xff);
        end
        
        
        % Extracts the lower byte (least significant byte) from a 16 bit
        % value
        function lByte = LOWER_BYTE(val)
            %LOWER_BYTE Extracts the lower byte (LSB) from a 16 bit value
            
            if ~strcmpi(class(val), 'uint16')
                error("Cannot get the upper byte of value. Data type needs to be of type 'uint16'");
            end
            lByte = uint8(bitand(val, 0x00ff));
        end
        
        
        % Calculates the LTC6804 CRC over a string of bytes as per datasheet figure 22.
        function remainder2 = PEC_Calc(data, length)
            %PEC_Calc Calculates the LTC6804 CRC over a string of bytes as per datasheet figure 22.
            if ~strcmpi(class(data), 'uint8')
                error("Argument 'data' has to be of type uint8 array(char* in c Lang). ");
            end
            remainder = uint16(LTC6804.PEC_SEED_VALUE);
            for i = 1:length
                remainder = LTC6804.PEC_LOOKUP(data(i), remainder);
            end
            remainder2 = uint16(remainder * 2); % The CRC15 has a 0 in the LSB so the remainder must be multiplied by 2
        end
        
        % calculates the pec for one byte, and returns the intermediate calculation
        function remainder = PEC_LOOKUP(data, remainder)
            if ~strcmpi(class(data), 'uint8')
                error("Argument 'data' has to be of type uint8 (char in c Lang). ");
            end
            addr = bitand(bitxor(uint8(bitshift(remainder, -7)), data), 0xff);    % calculate PEC table address
            remainder = bitxor(bitshift(remainder, 8), LTC6804.PEC_TABLE(addr+1));   % get value from CRC15Table;
            remainder = uint16(remainder);
        end
        
                
        function address = CONFIG_GET_BOARD_ADDRESS(board_num)
            %CONFIG_GET_BOARD_ADDRESS
            if (board_num == LTC6804.BROADCAST)
                address = LTC6804.COMMAND_CODE_BROADCAST_ADDRESS;
            else
                %     address = bitor(System_Address_Table(board_num), COMMAND_CODE_ADDRESSED_BIT);
            end
        end
        
        % Returns adcopt and md values to achieve the desired sample rate.
        function [adcopt_ptr, md_ptr] = get_adcopt_and_md(conversion_mode)
            % Select adcopt for this sample rate.
            switch(conversion_mode)
                case LTC6804.CONVERSION_27KHZ_MODE
                    adcopt_ptr = LTC6804.ADCOPT_0;
                    md_ptr = LTC6804.MD_MODE_FAST;
                case LTC6804.CONVERSION_14KHZ_MODE
                    adcopt_ptr = LTC6804.ADCOPT_1;
                    md_ptr = LTC6804.MD_MODE_FAST;
                case LTC6804.CONVERSION_7KHZ_MODE
                    adcopt_ptr = LTC6804.ADCOPT_0;
                    md_ptr = LTC6804.MD_MODE_NORMAL;
                case LTC6804.CONVERSION_3KHZ_MODE
                    adcopt_ptr = LTC6804.ADCOPT_1;
                    md_ptr = LTC6804.MD_MODE_NORMAL;
                case LTC6804.CONVERSION_2KHZ_MODE
                    adcopt_ptr = LTC6804.ADCOPT_1;
                    md_ptr = LTC6804.MD_MODE_FILTERED;
                case LTC6804.CONVERSION_26HZ_MODE
                otherwise
                    adcopt_ptr = LTC6804.ADCOPT_0;
                    md_ptr = LTC6804.MD_MODE_FILTERED;
            end
        end
        
        function DELAY_US(time_us)
            java.lang.Thread.sleep(time_us/1000);
        end
        
    end
    
    % LTC6804 Command Codes with variable bits, as defined by datasheet Table 34 and Table 35
    % Based off #define macros in the LTC6804_Registers.h header file
    methods (Access = private)
        
        function code_address = COMMAND_CODE_ADDRESS(obj, cmd_code, address)   
            code_address = bitor(bitand(cmd_code, 0x7FF),...
                bitshift(uint16(bitand(address, 0x1F)), 11));
        end
            
        function COMMAND_CODE_WRCFG(obj, address)
            % Write Configuration Register Group
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_WRCFG, address)); 
        end
        function cmd_code = COMMAND_CODE_RDCFG(obj, address)
            % Read Configuration Register Group
            cmd_code = obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_RDCFG, address); 
        end
        function COMMAND_CODE_RDCVA(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_RDCVA, address)); % Read Cell Voltage Register Group A
        end
        function COMMAND_CODE_RDCVB(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_RDCVB, address)); % Read Cell Voltage Register Group B
        end
        function COMMAND_CODE_RDCVC(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_RDCVC, address)); % Read Cell Voltage Register Group C
        end
        function COMMAND_CODE_RDCVD(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_RDCVD, address)); % Read Cell Voltage Register Group D
        end
        function COMMAND_CODE_RDAUXA(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_RDAUXA, address)); % Read Auxiliary Register Group A
        end
        function COMMAND_CODE_RDAUXB(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_RDAUXB, address)); % Read Auxiliary Register Group B
        end
        function cmd_code = COMMAND_CODE_RDSTATA(obj, address)
            cmd_code = obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_RDSTATA, address); % Read Status Register Group A
        end
        function cmd_code = COMMAND_CODE_RDSTATB(obj, address)
            cmd_code = obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_RDSTATB, address); % Read Status Register Group B
        end
        function COMMAND_CODE_ADCV(obj, address, md, dcp, ch)
        (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_ADCV, address) +...
            bitshift(int16(bitand(md, 0x3)), 7) + bitshift(bitand(dcp, 0x1), 4) +...
            bitshift(bitand(ch , 0x7), 0)); % Start Cell Voltage ADC Conversion and Poll Status
        end
        function COMMAND_CODE_ADOW(obj, address, md, pup, dcp, ch)
        (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_ADOW, address) +...
            bitshift(int16(bitand(md, 0x3)), 7) +...
            bitshift(bitand(pup, 0x1), 4) + bitshift(bitand(dcp, 0x1), 4) +...
            bitshift(bitand(ch, 0x7), 0)); % Start Open Wire ADC Conversion and Poll Status
        end
        function COMMAND_CODE_CVST(obj, address, md, st)
            obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_CVST, address) +...
            bitshift(int16(bitand(md, 0x3)), 7) + bitshift(bitand(st , 0x3), 5); % Start Self-Test Cell Voltage Conversion and Poll Status
        end
        function COMMAND_CODE_ADAX(obj, address, md, chg)
            obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_ADAX, address) +...
            bitshift(int16(bitand(md, 0x3)), 7) + bitshift(bitand(chg, 0x7), 0); % Start GPIOs ADC Conversion and Poll Status
        end
        function COMMAND_CODE_AXST(obj, address, md, st)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_AXST, address) +...
             bitshift(int16(bitand(md, 0x3)), 7) + bitshift(bitand(st , 0x3), 5)); % Start Self-Test GPIOs Conversion and Poll Status
        end
        function COMMAND_CODE_ADSTAT(obj, address, md, chst)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_ADSTAT, address) +...
             bitshift(int16(bitand(md, 0x3)), 7) + bitshift(bitand(chst, 0x7), 0)); % Start Status group ADC Conversion and Poll Status
        end
        function COMMAND_CODE_STATST(obj, address, md, st)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_STATST, address) +...
             bitshift(int16(bitand(md, 0x3)), 7) + bitshift(bitand(st  , 0x3), 5)); % Start Self-Test Status group Conversion and Poll Status
        end
        function COMMAND_CODE_ADCVAX(obj, address, md, dcp)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_ADCVAX, address) +...
             bitshift(int16(bitand(md, 0x3)), 7) + bitshift(bitand(dcp , 0x1), 4)); % Start Combined Cell Voltage and GPIO1, GPIO2 Conversion and Poll Status
        end
        function COMMAND_CODE_CLRCELL(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_CLRCELL, address)); % Clear Cell Voltage Register Group
        end
        function COMMAND_CODE_CLRAUX(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_CLRAUX, address)); % Clear Auxiliary Register Group
        end
        function COMMAND_CODE_CLRSTAT(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_CLRSTAT, address)); % Clear Status Register Group
        end
        function COMMAND_CODE_PLADC(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_PLADC, address)); % Poll ADC Conversion Status
        end
        function COMMAND_CODE_DIAGN(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_DIAGN, address)); % Diagnose MUX and Poll Status
        end
        function COMMAND_CODE_WRCOMM(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_WRCOMM, address)); % Write COMM Register Group
        end
        function COMMAND_CODE_RDCOMM(obj, address)
            (obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_RDCOMM, address)); % Read COMM Register Group
        end
        function COMMAND_CODE_STCOMM(obj, address)
            obj.COMMAND_CODE_ADDRESS(LTC6804.COMMAND_CODE_BASE_STCOMM, address); % Start I2C/SPI Communication
        end 
    end
    
    
    % Regular private functions
    methods (Access = private)
        
        % Sends a command code to the LTC6804 Device
        function command_code_send(obj, cmd_code, reg_group_command)
            totalSize = LTC6804.COMMAND_SIZE + LTC6804.PEC_SIZE;
            writebyte = uint8(...
                zeros(totalSize, 1));
            % Pull CS low to start write
%             obj.spi.writePin(LTC6804.CS_PIN, 0);
            
            %  Build the Command Code
            writebyte(1) = LTC6804.UPPER_BYTE(cmd_code);
            writebyte(2) = LTC6804.LOWER_BYTE(cmd_code);
            
            % Send Command (synchronous)
%             [status, rxData] = obj.spi.send(writebyte(1:LTC6804.COMMAND_SIZE));
            
            %  Calculate PEC
            pec = LTC6804.PEC_Calc(writebyte, LTC6804.COMMAND_SIZE);
            writebyte(LTC6804.COMMAND_SIZE + 1) = LTC6804.UPPER_BYTE(pec);
            writebyte(LTC6804.COMMAND_SIZE + 2) = LTC6804.LOWER_BYTE(pec);
            
            % Send Command and PEC (synchronous)
%             [status, rxData] = obj.spi.send(...
%                 writebyte(LTC6804.COMMAND_SIZE+1:totalSize));
            writebyte
            %  If no register group to follow, release CS to end write
            if (reg_group_command == false)
                obj.spi.writePin(LTC6804.CS_PIN, 1); %  End the communication
            end
        end
        
        function register_group_write(obj, register_group)
            %register_group_write Writes a whole group ...
            %   Carries on most likely from "command_code_send"
            
            % Send register_group bytes
            obj.spi.send(register_group);
            
            writebyte = uint8(zeros(LTC6804.PEC_SIZE, 1));
            %  Calculate PEC
            pec = LTC6804.PEC_Calc(writebyte, LTC6804.COMMAND_SIZE);
            writebyte(1) = LTC6804.UPPER_BYTE(pec);
            writebyte(2) = LTC6804.LOWER_BYTE(pec);
            
            % Send Command and PEC (synchronous)
            obj.spi.send(writebyte);
            
            %  End the communication
            obj.spi.writePin(LTC6804.CS_PIN, 1);
        end
        
        
        function [success, register_group] = register_group_read(obj)
            %register_group_read
            %   Most likely carries on  from "command_code_send"
            
            % Send Command and PEC (synchronous)
            [~, register_group] = obj.spi.receive(...
                (LTC6804.REGISTER_GROUP_SIZE + LTC6804.PEC_SIZE));
            
            % Initialize PEC calculation
            pec_calc =  LTC6804.PEC_SEED_VALUE;
            
            for byte_num = 1 : LTC6804.REGISTER_GROUP_SIZE
                pec_calc = LTC6804.PEC_LOOKUP(register_group(byte_num), pec_calc); % Calculate PEC for this byte
            end
            
            % Complete PEC calculation
            pec_calc = bitshift(pec_calc, 1); % The CRC15 has a 0 in the LSB so the remainder must be multiplied by 2
            
            %  End the communication
            obj.spi.writePin(LTC6804.CS_PIN, 1);
            
            % Verify PEC and return result
            if((LTC6804.UPPER_BYTE(pec_calc) ~= register_group(LTC6804.REGISTER_GROUP_SIZE+1))...
                    || (LTC6804.LOWER_BYTE(pec_calc) ~= register_group(LTC6804.REGISTER_GROUP_SIZE + 2)))
                
                success = false;
            else
                success = true;
            end
        end
        
        
        function detectedBoards = detectBoards(obj)
            
        end
        
        
        function wakeup(obj)
            persistent wakeup_timestamp;
            
            % Check timestamp (ms) to determine if a short or long delay is required after wakeup signal.
            wakeup_timestamp_new = updateTimer(obj);
            
            obj.spi.writePin(LTC6804.CS_PIN, 0);
            LTC6804.DELAY_US(LTC6804.TDWELL);
            obj.spi.writePin(LTC6804.CS_PIN, 1);
            
            if((wakeup_timestamp_new - wakeup_timestamp) < LTC6804.TSLEEP)
                % If wakeup signal sent less than LTC6804_TSLEEP time ago, then a short delay of LTC6804_TREADY is required.
                LTC6804.DELAY_US(LTC6804.TREADY);
            else
                % If wakeup signal sent more than LTC6804_TSLEEP time ago, then a long delay of LTC6804_TWAKE is required.
                LTC6804.DELAY_US(LTC6804.TWAKE);
            end
            
            wakeup_timestamp = wakeup_timestamp_new;
        end
        
        
        function time = updateTimer(obj)
            persistent timerLast;
            
            timerNow = toc;
            time = (timerNow - timerLast)/1000; % In ms
            
            timerLast = timerNow;
        end
        
    end
    
    methods
        function obj = LTC6804()
            tic;
%             obj.spi = MCP2210_USB2SPI('spiMode', uint8(3));
            % init ADCOPT to nonsensical value so that it will always be set the first time.
            obj.adcopt = 0xFF;
            %             % Call a find devices function here
            %             obj.detectedBoards = detectBoards(obj);
        end
        
        % Gets the LTC6804 revision.
        function [success, revision] = Revision_Get(obj, board_num)
            
            success = true;
            
            %             % storage for the Status Register Group B + PEC
            %             stbr = uint8(zeros(LTC6804.REGISTER_GROUP_SIZE +...
            %                 LTC6804.PEC_SIZE,1));
            %
            % Get the board address from the board number
            address = LTC6804.CONFIG_GET_BOARD_ADDRESS(board_num);
            
            % Wakeup 6804 in case it has entered SLEEP or IDLE.
            obj.wakeup();
            
            command_code = obj.COMMAND_CODE_RDSTATB(address);
            
            % Send the command code
            obj.command_code_send(command_code, true);
            
            % Read the Status Register
            [readStatus, stbr] = obj.register_group_read();
            
            if(readStatus == true)
                revision = bitshift(stbr(5), -4);
            else
                %                 obj.LTC6804_CONFIG_ERROR_CRC(board_num, command_code, stbr, sizeof(stbr));
                success = false;
                revision = 0;
            end
        end
        
        % Gets the LTC6804 ADC Reference status, where 1 = ON and 0 = OFF.
        function [success, refon] = Refon_Get(obj, board_num)
            
            success = true;
            cfgr = zeros(1, LTC6804.REGISTER_GROUP_SIZE + LTC6804.PEC_SIZE);    % storage for the Configuration Register Group B + PEC
            
            % Get the board address from the board number
            address = LTC6804.CONFIG_GET_BOARD_ADDRESS(board_num);
            
            % Wakeup 6804 in case it has entered SLEEP or IDLE.
%             obj.wakeup();
            
            command_code = obj.COMMAND_CODE_RDCFG(address)
            
            % Send the command code
            obj.command_code_send(command_code, true);
            
            % Read the Status Register
            [~, cfgr] = obj.register_group_read();
            if(cfgr == true)
                if (bitand(cfgr(0), LTC6804.CFGR0_REFON_MASK))
                    refon = true;
                else
                    refon = false;
                end
            else
%                 LTC6804_CONFIG_ERROR_CRC(board_num, command_code, cfgr, sizeof(cfgr));
                refon = 10;
                success = false;
            end
        end

        
        
        
        % Clears the LTC6804 Cell Voltage ADC registers.  This is useful to detect if the conversion was started properly when the results are read.
        function Cell_ADC_Clear(obj)
            % Get the board address from the board number
            address = LTC6804.CONFIG_GET_BOARD_ADDRESS(board_num);
            
            % Wakeup 6804 in case it has entered SLEEP or IDLE.
            obj.wakeup();
            
            % Build the command code
            command_code = LTC6804.COMMAND_CODE_CLRCELL(address);
            
            % Send the command code
            obj.command_code_send(command_code, false);
        end
        
        
        
        
        
        
%         function Cell_ADC_Start(obj, board_num, mode, cell_select, discharge_permitted)
%             
%             % Get the board address from the board number
%             address = LTC6804.CONFIG_GET_BOARD_ADDRESS(board_num);
%             
%             % Get adcopt and md values to achieve the desired sample rate.
%             [adcopt1, md] = LTC6804.get_adcopt_and_md(mode);
%             
%             % Set adcopt in the cfg register, if necessary
%             if( obj.adcopt ~= adcopt1)
%                 ltc6804_adc_opt_set(board_num, adcopt1);
%             else
%                 % Wakeup 6804 in case it has entered SLEEP or IDLE.
%                 obj.wakeup();
%             end
%             
%             % Build the command code to start ADC conversion
%             command_code = LTC6804_COMMAND_CODE_ADCV(address, md, (discharge_permitted ? LTC6804_DCP_DISCHARGE_PERMITTED : LTC6804_DCP_DISCHARGE_NOT_PERMITTED), cell_select);
%             
%             % Send the command code
%             ltc6804_command_code_send(command_code, false);
%             
%         end
        
        
        function success = quit(obj)
            success = false;
            status = obj.spi.terminate();
            if status == 0
                success = true;
            end
        end
        
        
        function success = checkErr()
            if obj.Error_Code_LTC6804_CRC_Ignore == true
                return;
            end
            
        end
        
        
    end
    
end

