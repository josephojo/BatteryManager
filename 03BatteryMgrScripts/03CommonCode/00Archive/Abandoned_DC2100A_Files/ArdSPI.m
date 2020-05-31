classdef ArdSPI
    %ArdSPI Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant)
        DEFAULT_CSPIN       = 'D10';
        DEFAULT_SPIMODE     = 3;
        DEFAULT_BITORDER    = 'msbfirst';
        DEFAULT_BITRATE     = 499999; %500000; % Doesn't matter what the slave baudrate is. Anything greater than 499999, doesn't work
    end
    
    properties
        ard
        spi
        
        csPin
        spiMode
        bitOrder
        bitRate

        
    end
    
    methods
        function obj = ArdSPI(port,board, varargin)
            %ArdSPI Constructs an instance of this class
            %   Detailed explanation goes here
            
            % Code to implement user defined values
            param = struct(...
                'spiMode',          ArdSPI.DEFAULT_SPIMODE,...
                'csPin',            ArdSPI.DEFAULT_CSPIN,...
                'bitOrder',         ArdSPI.DEFAULT_BITORDER,...
                'bitRate',          ArdSPI.DEFAULT_BITRATE, ...
                'baudRate',         ArdSPI.DEFAULT_BITRATE);
            
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
            
            obj.spiMode 		= param.spiMode;
            obj.csPin           = param.csPin;
            obj.bitOrder     	= param.bitOrder;
            obj.bitRate 		= param.baudRate;
            obj.bitRate 		= param.bitRate;

            
            obj.ard = arduino(port, board,'Libraries','SPI', 'BaudRate',921600);
            obj.spi = device(obj.ard,...
                'SPIChipSelectPin', obj.csPin, 'SPIMode', obj.spiMode,...
                'BitOrder', obj.bitOrder, 'BitRate', obj.bitRate);
        end
        
        function out = write(obj, writeData)
%             dataIn = [writeData zeros(1,length(writeData))];
            out = writeRead(obj.spi, writeData, 'uint8'); 
        end
        
        function out = read(obj, size)
%             cmd = dec2bin(1)
            dataIn = 0 * ones(1, size);
            out = writeRead(obj.spi, dataIn); 
        end
        
        function terminate(obj)
            %close Summary of this method goes here
            %   Detailed explanation goes here
            clear('obj');
        end
    end
end

