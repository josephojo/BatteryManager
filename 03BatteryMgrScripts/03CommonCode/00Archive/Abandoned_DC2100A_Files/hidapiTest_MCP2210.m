
%% Testing the MCP2210 to see if the hidapi works
DEFAULT_VID 			= 0x4d8;
DEFAULT_PID 			= 0xde;
        
libname 		= 'hidapi'; % DLL filename
headername 		= 'hidapi.h'; % Daefault header filename

maxLen = 255;
   

% If library is already loaded, do nothing else
if (libisloaded(libname))
    disp("HIDAPI has already been loaded");
else
    [notfound,warnings]=loadlibrary(libname, headername);
    libLoaded = libisloaded(libname);
    if libLoaded == false
        error("HIDAPI Library failed to load.");
    end
end



% Enumerate HID devices
% devices = calllib(libname,'hid_enumerate', DEFAULT_VID, DEFAULT_PID);

DC2100_VID = 1272;
DC2100_PID = 8004;

devices = calllib(libname,'hid_enumerate', DC2100_VID, DC2100_PID);

% devices = calllib(libname,'hid_enumerate', 0, 0); % Finds all HID devices

dev = devices.value;
calllib(libname,'hid_free_enumeration', devices);



res = calllib(libname,'hid_init');

devHandle = calllib(libname,'hid_open', DEFAULT_VID, DEFAULT_PID, libpointer('voidPtr'));

pathPtr = libpointer('stringPtr', "'\\?\hid#len0078#6&2884cfb5&0&0000#{4d1e55b2-f16f-11cf-88cb-001111000030}'"); %USB\VID_1272&PID_8004\LT000919201400162");
devHandle = calllib(libname,'hid_open_path', pathPtr);



% Manufacturer String
manuPtr = libpointer('uint16Ptr', uint16(zeros(1, maxLen)));
res = calllib(libname,'hid_get_manufacturer_string', devHandle, manuPtr, maxLen);
outVal = manuPtr.Value;
output = char(outVal); %convert to ASCII

s = sprintf("Manufacturer's string = %s\n", output);
fprintf(s);


% Product String
ptr = libpointer('uint16Ptr', uint16(zeros(1, maxLen)));
res = calllib(libname,'hid_get_product_string', devHandle, ptr, maxLen);
outVal = ptr.Value;
output = char(outVal); %convert to ASCII

s = sprintf("Product string = %s\n", output);
fprintf(s);


% Serial Number
ptr = libpointer('uint16Ptr', uint16(zeros(1, maxLen)));
res = calllib(libname,'hid_get_serial_number_string', devHandle, ptr, maxLen);
outVal = ptr.Value;
output = char(outVal); %convert to ASCII

s = sprintf("Serial Number = %s\n", output);
fprintf(s);


% Turn off LED at pin 5
buf = uint8(zeros(1, maxLen));
buf(2:6) = uint8([0x30 0x18 0x93 0x0E 0xDF]);
ptr = libpointer('uint8Ptr', buf);
res = calllib(libname,'hid_write', devHandle, ptr, 65)

pause(1);

% Turn ON LED at pin 5
buf = uint8(zeros(1, maxLen));
buf(2:6) = uint8([0x30 0x00 0x00 0x00 0xFF]);
ptr = libpointer('uint8Ptr', buf);
res = calllib(libname,'hid_write', devHandle, ptr, 65)

% Get LED state of all Pins
%Write Command
buf = uint8(zeros(1, maxLen));
buf(2:6) = uint8([0x31 0x00 0x00 0x00 0x00]);
ptr = libpointer('uint8Ptr', buf);
res = calllib(libname,'hid_write', devHandle, ptr, 65)

% Read Data
buf = uint8(zeros(1, maxLen));
ptr = libpointer('uint8Ptr', buf);
res = calllib(libname,'hid_read', devHandle, ptr, 65)
outVal = ptr.Value;

for ii=1:4
    s = sprintf("buf(%d) = %s\n", ii, dec2hex(outVal(ii)));
    fprintf(s);
end

calllib(libname,'hid_close', devHandle);

res = calllib(libname,'hid_exit');

if (libisloaded(libname))
    clear('devHandle', 'devices');
    unloadlibrary(libname)
end

