% loadlibrary('mcp2210_dll_m', 'mcp2210_dll_m_dotnetv4_x64.dll');
% loadlibrary('mcp2210_dll_m', 'mcp2210_dll_m_dotnetv2_x86.dll');

libname = 'mcp2210_dll_um_x64';
loadlibrary(libname ,'mcp2210_dll_um.h');
tf = libisloaded(libname);

DEFAULT_VID = 0x4d8;
DEFAULT_PID = 0xde;

devPathSizePtr = libpointer('uint32Ptr');
devPathPtr = libpointer('stringPtr');

x = calllib(libname,'Mcp2210_GetConnectedDevCount', DEFAULT_VID, DEFAULT_PID);
% Mcp2210_GetConnectedDevCount(DEFAULT_VID, DEFAULT_PID);
disp("Number of connected MCP2210 Devices are: " + x);

devIndex = 0; % First device
% Open Serial
devHandle = libpointer('voidPtr');
devHandle = calllib(libname,'Mcp2210_OpenByIndex', DEFAULT_VID, DEFAULT_PID, devIndex,...
    devPathPtr, devPathSizePtr);

err = calllib(libname,'Mcp2210_GetLastError'); % Check to see if there were any error

switch err
    case -106
        warning("CONNECTION ALREADY OPEN!");
    case -103
        warning("DEVICE NOT FOUND");
    
end

% Create Buffer
% BufferSize = 99;
% pBuffer = libpointer('int16Ptr',zeros(BufferSize,1));

% VM/NVRAM selection - use it as cfgSelector parameter
MCP2210_VM_CONFIG = 0;     % designates current chip setting - Volatile Memory
MCP2210_NVRAM_CONFIG = 1;  % designates power-up chip setting - NVRAM          */

% cfgSelector = uint8(MCP2210_VM_CONFIG);
cfgSelector = uint8(MCP2210_NVRAM_CONFIG);


% txData = [072, 101, 108, 108, 111, 032, 087, 111, 114, 108, 100, 010];
% txData = 72;
% txData = ['H', 'e', 'l', 'l', 'o', ' ', 'W', 'o', 'r', 'l', 'd', '\n'];
txData = uint8(['Hello World', newline]);
rxData = uint8(zeros(1, 12));

% txData = char();

% Using the pointer is imperative to being able to receive data back
txDataBuf = libpointer('uint8Ptr', txData);
rxDataBuf = libpointer('uint8Ptr', rxData);
baudRatePtr = libpointer('uint32Ptr',uint32(zeros(1,1))); % = 0; % libpointer('uint16Ptr', 10000);
CSIdleVal = libpointer('uint32Ptr',uint32(zeros(1,1))); % = 4; % The value of Chip select pin when idling (0 or 1). Depends on modes
CSActiveVal = libpointer('uint32Ptr',uint32(zeros(1,1))); % = 4; % The value of Chip select pin when active (0 or 1). Depends on modes
CS2DataDly = libpointer('uint32Ptr',uint32(zeros(1,1))); % = 0; % The delay setting between each byte of data while sending
data2CSDly = libpointer('uint32Ptr',uint32(zeros(1,1))); % = 0; % The delay setting between each byte of data while sending
data2DataDly = libpointer('uint32Ptr',uint32(zeros(1,1))); % = 0; % The delay setting between each byte of data while sending
spiMode = libpointer('uint8Ptr',uint8(zeros(1,1))); % = 5; % Mode setting of the SPI protocol (mode 0, 1, 2 or 3)
txferSizePtr = libpointer('uint32Ptr',uint32(zeros(1,1))); % = 12; % libpointer('uint16Ptr', 1);
csConfig = 0x20; % 0 keeps the setting unchanged
serialNum = libpointer('stringPtr', "");

output = calllib(libname,'Mcp2210_GetSerialNumber', devHandle, serialNum);
disp("Seral Number for current MCP2210 is: " + serialNum.value)

output = calllib(libname,'Mcp2210_GetSpiConfig', devHandle,  cfgSelector,...
   baudRatePtr, CSIdleVal, CSActiveVal, CS2DataDly, data2CSDly, data2DataDly,... 
   txferSizePtr, spiMode)

disp("Baud Rate: " + num2str(baudRatePtr.value));
disp("CS Idle Val: " + num2str(CSIdleVal.value));
disp("CS Active Val: " + num2str(CSActiveVal.value));
disp("CS to Data Dly: " + num2str(CS2DataDly.value));
disp("data to CS Dly: " + num2str(data2CSDly.value));
disp("data to Data Dly: " + num2str(data2DataDly.value));
disp("txfer Size Ptr: " + num2str(txferSizePtr.value));
disp("spiMode: " + num2str(spiMode.value));


txferSizePtr = 32; % libpointer('uint16Ptr', 1);


output = calllib(libname,'Mcp2210_xferSpiData', devHandle, txDataBuf, ...
     rxDataBuf, baudRatePtr, txferSizePtr, csConfig)

 %% Send and Receive Data from DC2100A balancer
 
 LTC6804_CMD_CODE_BROADCAST_ADDRESS = 0x00; % Address used for an LTC6804 command to be broadcast to all boards
 LTC6804_CMD_CODE_BASE_CLRCELL = 0x711; % Base (register) command to Clear Cell Voltage Register Group

 bal_address = LTC6804_CMD_CODE_BROADCAST_ADDRESS;

 % Clear ADC results, so that it can be detected 
 % if LTC6804_Cell_ADC_Start() command is not successful.
 
 
 LTC6804_CMD_CODE_CLRCELL = bitor(bitand(LTC6804_CMD_CODE_BASE_CLRCELL, 0x7FF),...
     (bitshift((uint16(bitand(bal_address, 0x1F))), 11))); % Device Command to Clear ADC (including address
 
 %% Close Connection
output = calllib(libname, 'Mcp2210_Close', devHandle)
% unloadlibrary libname