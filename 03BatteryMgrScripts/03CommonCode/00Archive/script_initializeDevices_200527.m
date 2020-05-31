% Arduino
%##########################################################################
% ardPort = 'COM8';
% ardSerial = instrfind('Port',ardPort, 'Status', 'open');
% if isempty(ardSerial)
%     ard = serial(ardPort);
%     ard.BaudRate = 115200;
%     ard.DataBits = 8;
%     ard.Parity = 'none';
%     ard.StopBits = 1;
%     ard.Terminator = 'LF';
%     fopen(ard);
% elseif ~exist('ard','var')
%     ard = ardSerial;
% end
% wait(2);
% -------------------------------------------------------------------------

%ARRAY ELOAD
%##########################################################################
eloadPort = 'COM2';
eloadSerial = instrfind('Port',eloadPort, 'Status', 'open');
if isempty(eloadSerial)
    eload = Array_ELoad(eloadPort);
    eload.SetSystCtrl('remote');
    eload.Disconnect();
    
elseif ~exist('eload','var')
    eload = Array_ELoad(eloadSerial);
end
%--------------------------------------------------------------------------

%APM POWER SUPPLY
%##########################################################################
psuPort = 'COM7';
psuSerial = instrfind('Port',psuPort, 'Status', 'open');
if isempty(psuSerial)
    psu = APM_PSU(psuPort);
    psu.disconnect();
elseif ~exist('psu','var')
    psu = APM_PSU(psuSerial);
end
%--------------------------------------------------------------------------

%THERMOCOUPLE MODULE
%##########################################################################
thermoPort = 'COM5';
if ~exist('thermo','var')
    thermo = modbus('serialrtu',thermoPort,'Timeout',10); % Initializes a Modbus
    %protocol object using serial RTU interface connecting to COM6 and a Time
    %out of 10s.
    thermo.BaudRate = 38400;
end
%--------------------------------------------------------------------------

% LABJACK
%##########################################################################
LJRelayPins = [5, 6];
if ~exist('ljasm','var')
    ljasm = NET.addAssembly('LJUDDotNet');
    ljudObj = LabJack.LabJackUD.LJUD;
    
    % Open the first found LabJack U3.
    [ljerror, ljhandle] = ljudObj.OpenLabJackS('LJ_dtU3', 'LJ_ctUSB', '0', ...
        true, 0);
    
    % Constant values used in the loop.
    LJ_ioGET_AIN = ljudObj.StringToConstant('LJ_ioGET_AIN');
    LJ_ioGET_AIN_DIFF = ljudObj.StringToConstant('LJ_ioGET_AIN_DIFF');
    LJE_NO_MORE_DATA_AVAILABLE = ljudObj.StringToConstant('LJE_NO_MORE_DATA_AVAILABLE');
    
    % Start by using the pin_configuration_reset IOType so that all pin
    % assignments are in the factory default condition.
    ljudObj.ePutS(ljhandle, 'LJ_ioPIN_CONFIGURATION_RESET', 0, 0, 0);
    ljudObj.ePutS(ljhandle, 'LJ_ioPUT_ANALOG_ENABLE_BIT', 7, 1, 0);

end

% -------------------------------------------------------------------------


% % Get the 0A voltage from the current sensor connected to the LabJack.
% % This section will give errors if script_initializeVariables isn't run
% % before this script
% cSigP = 0;
% cSigN = 0;
% n = 10;
% script_initializeVariables;
% for i = 1:n
%     script_avgLJMeas; % Gets the zero values of the sensor. % If Error occurs here, it's because script_initializeVariables wasn't before script_initializeDevices
%     cSigP = (ain0 / adcAvgCount) + cSigP;
%     cSigN = (ain1 / adcAvgCount) + cSigN;
% end
% cSigMid = (cSigP/n) - (cSigN/n);
% script_initializeVariables;
