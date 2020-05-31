% The MCP2210 device from Microchip is initialized here to facilitate 
% USB to SPI communication 

% Load device library. libname is the dll file equivalent of the .h file
% below
libname = 'mcp2210_dll_um_x64';
loadlibrary(libname ,'mcp2210_dll_um.h');
libLoaded = libisloaded(libname);
if libLoaded == false
    error("MCP2210 Library failed to load.");
end

%% Variable and Pointer Definition
DEFAULT_VID = 0x4d8;
DEFAULT_PID = 0xde;

devPathSizePtr = libpointer('uint32Ptr');
devPathPtr = libpointer('stringPtr');

%% Initialize connection with MCP2210
numDev = calllib(libname,'Mcp2210_GetConnectedDevCount', DEFAULT_VID, DEFAULT_PID);
% Mcp2210_GetConnectedDevCount(DEFAULT_VID, DEFAULT_PID);
disp("Number of connected MCP2210 Devices are: " + numDev);

devIndex = numDev - 1; % Last device connected
% Open Serial
devHandle = libpointer('voidPtr');
devHandle = calllib(libname,'Mcp2210_OpenByIndex', DEFAULT_VID, DEFAULT_PID, devIndex,...
    devPathPtr, devPathSizePtr);

err = calllib(libname,'Mcp2210_GetLastError'); % Check to see if there were any error
MCP2210_catchErrs(err); 

