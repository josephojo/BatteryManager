% clear;clc;
%
tic;
psu = BK_PSU('COM4');
eload = Array_ELoad('COM2');
eload.SetSystCtrl('remote');
thermo = modbus('serialrtu','COM5','Timeout',10); % Initializes a Modbus
% %protocol object using serial RTU interface connecting to COM6 and a Time
% %out of 10s.
thermo.BaudRate = 38400;

ljasm = NET.addAssembly('LJUDDotNet');
ljudObj = LabJack.LabJackUD.LJUD;

% Open the first found LabJack U3.
[ljerror, ljhandle] = ljudObj.OpenLabJackS('LJ_dtU3', 'LJ_ctUSB', '0', ...
    true, 0);

% Constant values used in the loop.
LJ_ioGET_AIN = ljudObj.StringToConstant('LJ_ioGET_AIN');
LJ_ioGET_DIGITAL_BIT_STATE = ljudObj.StringToConstant('LJ_ioGET_DIGITAL_BIT_STATE');
LJ_ioGET_AIN_DIFF = ljudObj.StringToConstant('LJ_ioGET_AIN_DIFF');
LJE_NO_MORE_DATA_AVAILABLE = ljudObj.StringToConstant('LJE_NO_MORE_DATA_AVAILABLE');

ljudObj.ePutS (ljhandle, 'LJ_ioPUT_ANALOG_ENABLE_PORT', 0, 48, 8);

% % Start by using the pin_configuration_reset IOType so that all pin
% % assignments are in the factory default condition.
% ljudObj.ePutS(ljhandle, 'LJ_ioPIN_CONFIGURATION_RESET', 0, 0, 0);

%% APM PSU
clear; clc;

disp("Started");
psu = serial('COM5');
psu.BaudRate = 19200;
fopen(psu);
fprintf(psu, "*IDN?");
reply = fgetl(psu)

fprintf(psu, "ASWRS?");
reply = fgetl(psu)

fclose(psu);


%% APM Tech Power Supply (PSU) Voltage Respose
% clearvars;
% clc;

cellID = 'AA5';
script_initializeDevices;
script_initializeVariables;

tic;
timer1 = toc;
timer2 = toc;

curr = 2.15; %2.5A is 1C for the ANR26650
script_charge; % Run Script to begin/update charging process

while toc - timer1 < 10
    if toc - timer2 >= 0.5
        timer2 = toc;
        script_queryData; % Run Script to query data from devices
        script_failSafes; %Run FailSafe Checks
        % if limits are reached, break loop
        if errorCode == 1
            break;
        end
    end
end

curr = 1;
script_charge; % Run Script to begin/update charging process
timer1 = toc;
while toc - timer1 < 10
    if toc - timer2 >= 0.5
        timer2 = toc;
        script_queryData; % Run Script to query data from devices
        script_failSafes; %Run FailSafe Checks
        % if limits are reached, break loop
        if errorCode == 1
            break;
        end
    end
end

script_resetDevices


%% BK Precision 1688B Power Supply (PSU) COMM Timing
clear;
clc;
script_initializeDevices;
adcAvgCounter = 0; ain2 = 0; ain3 = 0;
adcAvgCount = 1;

% psu.Disconnect();
% psu.Connect();

% psu.SetCurr(6.0);
% pause(1);

tic;
timer1 = toc;

psu.SetVolt(5.5);
psu.SetCurr(15);
psu.Connect();
pause(0.04);


relayState = false; % Relay is in the Normally Opened Position
ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4,relayState, 0);
ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 5,relayState, 0);
ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 6,relayState, 0);
ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 7,relayState, 0);

toc

% pause(0.8);


% script_avgLJMeas


% psuData = zeros(1, 2);
[psuData, psuMode] = psu.GetVoltCurrD();
pause(0.8);

% while psuData(2) < 2.5
%     [psuData, psuMode] = psu.GetVoltCurrD();
%     Pstr = sprintf("PSU Volt = %.3f V\t\tPSU Curr = %.3f A\n", psuData(1), psuData(2));
%     fprintf(Pstr + newline);
% end
tElasped = toc - timer1;
disp(num2str(tElasped,'%.3f') + "seconds");

Pstr = sprintf("PSU Volt = %.3f V\t\tPSU Curr = %.3f A\n", psuData(1), psuData(2));
fprintf(Pstr + newline);

vBattp = ain2 / adcAvgCount;
vBattn = ain3 / adcAvgCount;
disp("Volt LJ = " + num2str(vBattp - vBattn + 0.011));
adcAvgCounter = 0; ain2 = 0; ain3 = 0;

script_resetDevices

%% Power Pulse Test COMM Timing
clear;
clc;
script_initializeDevices;
adcAvgCounter = 0; ain2 = 0; ain3 = 0;
adcAvgCount = 10;

psu.Disconnect();
eload.Disconnect();

% pause(0.5);

timer1 = toc;

psu.SetVolt(5.0);
psu.SetCurr(14.2);
psu.Connect();

relayState = false; % Relay is in the Normally Opened Position
ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4,relayState, 0);
ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 5,relayState, 0);
ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 6,relayState, 0);
ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 7,relayState, 0);
% pause(0.07);


% pause(0.8);

% psuData = zeros(1, 2);
[psuData, psuMode] = psu.GetVoltCurrD();
eloadData = eload.MeasureVoltCurr();

script_avgLJMeas

tElasped = toc - timer1;
disp(num2str(tElasped,'%.3f') + "seconds");

Pstr = sprintf("PSU Volt = %.3f V\t\tPSU Curr = %.3f A\n", psuData(1), psuData(2));
fprintf(Pstr + newline);
Estr = sprintf("ELoad Volt = %.3f V\tELoad Curr = %.3f A\n",  eloadData(1), eloadData(2));
fprintf(Estr + newline);
vBattp = ain2 / adcAvgCount;
vBattn = ain3 / adcAvgCount;
disp("Volt LJ = " + num2str(vBattp - vBattn + 0.011));
adcAvgCounter = 0; ain2 = 0; ain3 = 0;
pause(0.2);

% timer1 = toc;

% psu.SetVolt(3.8);
% psu.SetCurr(14.2);
% psu.Connect();

% pause(0.7);

% psuData = zeros(1, 2);
[psuData, psuMode] = psu.GetVoltCurrD();
eloadData = eload.MeasureVoltCurr();

script_avgLJMeas

tElasped = toc - timer1;
disp(num2str(tElasped,'%.3f') + "seconds");

Pstr = sprintf("PSU Volt = %.3f V\t\tPSU Curr = %.3f A\n", psuData(1), psuData(2));
fprintf(Pstr + newline);
Estr = sprintf("ELoad Volt = %.3f V\tELoad Curr = %.3f A\n",  eloadData(1), eloadData(2));
fprintf(Estr + newline);
vBattp = ain2 / adcAvgCount;
vBattn = ain3 / adcAvgCount;
disp("Volt LJ = " + num2str(vBattp - vBattn + 0.011));

script_resetDevices

%% Array 3721A ELoad COMM Timing
clear;
clc;
script_initializeDevices;

eload.SetSystCtrl("remote");

eloadReply = eload.SetLev_CC(0.0);

% relayState = false; % Relay is in the Normally Opened Position
% ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4,relayState, 0);
% ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 5,relayState, 0);
% ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 6,relayState, 0);
% ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 7,relayState, 0);

% pause(0.07);

psu.Disconnect();
eload.Disconnect();

pause(0.04);

tic
timer1 = toc;

eloadReply = eload.SetLev_CC(15);
eload.Connect();

relayState = true; % Relay is in the Normally Opened Position
ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4,relayState, 0);
ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 5,relayState, 0);
ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 6,relayState, 0);
ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 7,relayState, 0);
pause(0.07);




pause(0.2);

eloadData = eload.MeasureVoltCurr();


% eloadData = eload.MeasureVolt();
tElasped = toc - timer1;
disp(num2str(tElasped,'%.3f') + "seconds");
Estr = sprintf("ELoad Volt = %.3f V\tELoad Curr = %.3f A\n",  eloadData(1), eloadData(2));
fprintf(Estr + newline);

% Estr = sprintf("ELoad Volt = %.3f V\n",  eloadData(1));

script_resetDevices

%% PSU and Eload Response Time Test
clear;
clc;
script_initializeDevices;

psu.Disconnect();

% eload.SetLev_CC(15);
% eload.Connect();

psu.SetVolt(5.0);
psu.SetCurr(0.5);
psu.Connect();

% pause(0.8)

% tic;
% timer1 = toc;

% psu.SetCurr(1);

% pause(0.35); % 0.35 for ELoad,


toc

% pause(2);

eloadData = eload.MeasureVoltCurr();
[psuData, psuMode] = psu.GetVoltCurrD();
% eloadData = eload.MeasureVoltCurr();


tElasped = toc - timer1;
disp(num2str(tElasped,'%.3f') + "seconds");

Pstr = sprintf("PSU Volt = %.3f V\t\tPSU Curr = %.3f A\n", psuData(1), psuData(2));
Estr = sprintf("ELoad Volt = %.3f V\tELoad Curr = %.3f A\n",  eloadData(1), eloadData(2));
fprintf(Pstr);
fprintf(Estr + newline);

% pause(0.1);

% % ----------------------------------- Eload
%
% eload.Disconnect();
%
% pause(2)
%
% tic;
% timer1 = toc;
%
% eloadReply = eload.SetLev_CC(15);
% eload.Connect();
%
% toc
%
% % pause(0.8);
%
%
% [psuData, psuMode] = psu.GetVoltCurrD();
% eloadData = eload.MeasureVoltCurr();
%
% tElasped = toc - timer1;
% disp(num2str(tElasped,'%.3f') + "seconds");
%
% Pstr = sprintf("PSU Volt = %.3f V\t\tPSU Curr = %.3f A\n", psuData(1), psuData(2));
% Estr = sprintf("ELoad Volt = %.3f V\tELoad Curr = %.3f A\n",  eloadData(1), eloadData(2));
% fprintf(Pstr);
% fprintf(Estr + newline);
%
% pause(0.1);
%

script_resetDevices

%% Thermocouple DAQ Test through the thermocouple module and YN-4561 USB to Serial module COMM Timing
timer1 = toc;

thermoData = read(thermo,'holdingregs',9,3);%/10;
tElasped = toc - timer1;
disp(num2str(tElasped,'%.3f') + "seconds");
Tstr = sprintf("TC 1 = %.1f ºC\t\t\tTC 2 = %.1f ºC\t\t\tTC 3 = %.1f ºC\n" ,thermoData(1)/10, thermoData(2)/10, thermoData(3)/10);
fprintf(Tstr + newline);

%% Labjack Relay IO control
ain3 = 0; ain2 = 0;ain1 = 0; ain0 = 0; adcAvgCounter = 0;
adcAvgCount = 10;

tic;
disp("Before Switch");
toc
% False = Charge, True = Discharge
% relayState = true; % Relay is in the Normally Opened Position
% ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4,relayState, 0);
% ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 5,relayState, 0);
% ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 0,relayState, 0);
% ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 1,relayState, 0);

% wait(0.05); % Wait for the relays to switch


% % Request a single-ended reading from FIO4
% ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_DIGITAL_BIT_STATE', 4, 0, 0, 0);
% % Request a single-ended reading from FIO5
% ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_DIGITAL_BIT_STATE', 5, 0, 0, 0);
% % Request a single-ended reading from FIO0
% ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_DIGITAL_BIT_STATE', 0, 0, 0, 0);
% % Request a single-ended reading from FIO1
% ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_DIGITAL_BIT_STATE', 1, 0, 0, 0);

for ii = 1:3
    
    % Request a single-ended reading from AIN0 (VShunt+).
    ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN_DIFF', 4, 0, 5, 0);
    
    % Request a single-ended reading from AIN1 (VShunt-).
    % ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN', 5, 0, 32, 0);
    
    % Request a single-ended reading from AIN2 (VBatt+).
    ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN', 2, 0, 0, 0);
    
    % Request a single-ended reading from AIN3 (VBatt-).
    ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN', 3, 0, 0, 0);
    
    
    % Execute the requests.
    ljudObj.GoOne(ljhandle);
    
    pinStates = ones(1,4);
    
    [ljerror, ioType, channel, dblValue, dummyInt, dummyDbl] = ljudObj.GetFirstResult(ljhandle, 0, 0, 0, 0, 0);
    
    finished = false;
    while finished == false
        switch ioType
            case LJ_ioGET_AIN
                switch int32(channel)
                    case 4
                        ain0 = ain0 + dblValue;
                        %                     pinStates(3) = dblValue;
                    case 5
                        ain1 = ain1 + dblValue;
                        %                     pinStates(4) = dblValue;
                    case 2
                        ain2 = ain2 + dblValue;
                    case 3
                        ain3 = ain3 + dblValue;
                        %                 case 4
                        %                     pinStates(1) = dblValue;
                        %                 case 5
                        %                     pinStates(2) = dblValue;
                        %                 case 6
                        % %                     pinStates(3) = dblValue;
                        %                     ain0 = ain0 + dblValue;
                        %                 case 7
                        % %                     pinStates(4) = dblValue;
                        %                     ain0 = ain0 + dblValue;
                end
            case LJ_ioGET_AIN_DIFF
                switch int32(channel)
                    case 4
                        ain0 = ain0 + dblValue;
                    case 5
                        ain1 = ain1 + dblValue;
                end
        end
        
        try
            [ljerror, ioType, channel, dblValue, dummyInt, dummyDbl] = ljudObj.GetNextResult(ljhandle, 0, 0, 0, 0, 0);
        catch e
            if(isa(e, 'NET.NetException'))
                eNet = e.ExceptionObject;
                if(isa(eNet, 'LabJack.LabJackUD.LabJackUDException'))
                    % If we get an error, report it. If the error is
                    % LJE_NO_MORE_DATA_AVAILABLE we are done.
                    if(int32(eNet.LJUDError) == LJE_NO_MORE_DATA_AVAILABLE)
                        finished = true;
                    end
                end
            end
            % Report non LJE_NO_MORE_DATA_AVAILABLE error.
            if(finished == false)
                throw(e)
            end
        end
    end
    
    toc
    disp("After Switch");
    
    vBattp = ain2;
    vBattn = ain3;
    currBattp = ain0;
    currBattn = ain1;
    disp("currBattp = " + num2str((round(currBattp,3) + 0.003)))
    
    disp("batt LJ Volt: " + num2str(vBattp - vBattn + 0.01)); % Grabs new battery voltage and adds offset
    disp("batt LJ Curr: " + num2str((round(currBattp,2)) / 0.02)); % I = V/R
    ain3 = 0; ain2 = 0;ain1 = 0; ain0 = 0;
    % disp(pinStates);
    
    disp(newline)
    
    pause(0.5);
end

%% AC7152 Current Sensor Test
script_initializeDevices;
% ard = arduino();
script_initializeVariables;
ain3 = 0; ain2 = 0;ain1 = 0; ain0 = 0; adcAvgCounter = 0;
adcAvgCount = 5; ain = []; curr = []; currArd = [];

tic;
disp("Before Switch");
toc
battState = "discharging";
verbose = 1;

loadReply = eload.SetLev_CC(1);
eload.Connect();

% script_avgLJMeas;
%
% script_queryData



% False = Charge, True = Discharge
relayState = false; % Relay is in the Normally Opened Position
% ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4,relayState, 0);
% ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 5,relayState, 0);
% ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 6,relayState, 0);
% ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 7,relayState, 0);
% pause (0.15)
% script_switchRelays;

% psu.SetVolt(6);
% psu.SetCurr(1.0);
% psu.Connect();

for z = 1:12
    if mod(z,3) == 0
        eload.SetLev_CC(z);
        disp(z);
    end
    script_queryData;
    pause(0.1);
end

script_resetDevices


%% Labjack Relay control and Voltage Measurement Average Timing
ain3 = 0; ain2 = 0; adcAvgCounter = 0;
adcAvgCount = 10;

timer1 = toc;

% Due to the imprecision of the Labjack ADC (12bit)or 5mV variation
% This section averages 50 individual values from 2 analog ports
% vBattp (Vbatt+) and vBattn(Vbatt-) to stabilize the voltage
% difference and attain a variation of ±0.001 V or ±1 mV
while adcAvgCounter < adcAvgCount
    
    % Request a single-ended reading from AIN2 (VBatt+).
    ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN_DIFF', 6, 0, 199, 0);
    
    % Request a single-ended reading from (VBatt-).
    ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN_DIFF', 7, 0, 199, 0);
    %
    % Execute the requests.
    ljudObj.GoOne(ljhandle);
    
    [ljerror, ioType, channel, dblValue, dummyInt, dummyDbl] = ljudObj.GetFirstResult(ljhandle, 0, 0, 0, 0, 0);
    
    finished = false;
    while finished == false
        switch ioType
            case LJ_ioGET_AIN
                switch int32(channel)
                    case 2
                        ain2 = ain2 + dblValue;
                    case 3
                        ain3 = ain3 + dblValue;
                end
        end
        
        try
            [ljerror, ioType, channel, dblValue, dummyInt, dummyDbl] = ljudObj.GetNextResult(ljhandle, 0, 0, 0, 0, 0);
        catch e
            if(isa(e, 'NET.NetException'))
                eNet = e.ExceptionObject;
                if(isa(eNet, 'LabJack.LabJackUD.LabJackUDException'))
                    % If we get an error, report it. If the error is
                    % LJE_NO_MORE_DATA_AVAILABLE we are done.
                    if(int32(eNet.LJUDError) == LJE_NO_MORE_DATA_AVAILABLE)
                        finished = true;
                        adcAvgCounter = adcAvgCounter + 1;
                    end
                end
            end
            % Report non LJE_NO_MORE_DATA_AVAILABLE error.
            if(finished == false)
                throw(e)
            end
        end
    end
end

disp("Averaging time: " + num2str(toc - timer1,'%.3f') + "seconds");
%Finds avg of total voltages collected at both batt terminals
vBattp = ain2 / adcAvgCount;
vBattn = ain3 / adcAvgCount;

% Grabs new battery voltage and adds offset
battVolt = vBattp - vBattn + 0.011;

disp("battVolt: " + num2str(battVolt,'%.7f'))

%% BK Precision 1688B Power Supply (PSU) Control Test
clear;
clc;

s = serial('COM4');
s.BaudRate = 9600;
s.DataBits = 8;
s.Parity = 'none';
s.StopBits = 1;
s.Terminator = 'CR';

% Open Port
fopen(s)

% Sending V or I values
fprintf(s,'VOLT090')
reply = fscanf(s);
disp(reply)

% Receiving V or I Values
fprintf(s,'GETS')
reply = fscanf(s);
disp(reply)
reply = fscanf(s);
disp(reply)
% Close Serial Port
fclose(s);

%% Thermocouple DAQ Test through the thermocouple module and YN-4561 USB to Serial module
clear;
m = modbus('serialrtu','COM4','Timeout',10); % Initializes a Modbus protocol object using serial RTU interface connectinf to COM4 (current, could change) and a Time out of 10s.

read(m,'holdingregs',1,1) %Reads "16" values (thermocouple port 1 to port 16) from the holding registers "holdingregs" of address "1" on RS-485 using function code 03.
%The equivalent of this is 01 03 00 00 00 10
%CRC CRC which is the required text to send
%according to the thermo module doc on https://www.aliexpress.com/item/16-road-support-mix-PT100-K-T-J-N-E-S-4-20mA-thermocouple-thermal-resistance/32901795740.html?spm=2114.search0104.3.2.2f995c71hQ9X4m&ws_ab_test=searchweb0_0,searchweb201602_2_10065_10068_10130_10547_319_317_10548_10696_10924_453_10084_454_10083_10618_10139_10920_10921_10307_10922_537_536_10059_10884_10887_100031_321_322_10103,searchweb201603_51,ppcSwitch_0&algo_expid=3ec3e6b6-d45c-4224-be36-e1e004c5d5e2-0&algo_pvid=3ec3e6b6-d45c-4224-be36-e1e004c5d5e2

%% Array ELoad Control Test
clear;
clc;

eLoad = serial('COM2');
eLoad.BaudRate = 9600;
eLoad.DataBits = 8;
eLoad.Parity = 'none';
eLoad.StopBits = 1;
eLoad.Terminator = 'LF';

% Open Port
fopen(eLoad)

% Sending V or I values
fprintf(eLoad,'SYST:REM')
% reply = fscanf(eLoad);
% disp("reply")

% Receiving V or I Values
fprintf(eLoad,'CURR:LEV 3')
% reply = fscanf(eLoad);
% disp(reply)
% reply = fscanf(eLoad);
% disp(reply)

fprintf(eLoad,'SYST:LOC')

% Close Serial Port
fclose(eLoad);

%% Labjack IO control
clc;
ljasm = NET.addAssembly('LJUDDotNet');
ljudObj = LabJack.LabJackUD.LJUD;

try
    % Read and display the UD version.
    disp(['UD Driver Version = ' num2str(ljudObj.GetDriverVersion())])
    
    % Open the first found LabJack U3.
    [ljerror, ljhandle] = ljudObj.OpenLabJackS('LJ_dtU3', 'LJ_ctUSB', '0', true, 0);
    
    % Start by using the pin_configuration_reset IOType so that all pin
    % assignments are in the factory default condition.
    ljudObj.ePutS(ljhandle, 'LJ_ioPIN_CONFIGURATION_RESET', 0, 0, 0);
    
    tic;
    t1 = toc;
    state = true;
    for i = 1:10
        disp (i)
        while (t < 3)
            t2 = toc;
            t = t2 - t1;
        end
        state = ~state;
        disp ("state = " + state);%disp (state)
        ljudObj.ePutS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4,state, 0);
        t1 = t2;t=0;
    end
    
catch e
    showErrorMessage(e)
end

%% MCP2210 Communcation test (USB to board)

obj = MCP2210_USB2SPI('devIndex', 0, 'csPin', 0);
% txCmd = uint8(['Hello World', newline]);
txCmd = uint8(1);
% buf = uint8(zeros(1, 2));

obj.writePin(5, 0);
% [status, rxData1] = transfer(obj, txCmd);
% [status, rxData2] = transfer(obj, uint8(0), 14);

[status, rxData1] = send(obj, txCmd);
[status, rxData2] = receive(obj, 14);
%{
% for pos = 1: length(buf)
%     java.lang.Thread.sleep(15/1000);
%     [~, buf(pos)] = transfer(obj, uint8(0));
%     if (buf (pos) == 0)
%       break;
%     end
% end
% buf(end) = 0;  % ensure terminating null
% disp("We received: " + char(buf));

%}
disp("We received: " + char(rxData2));
obj.writePin(5, 1);

pause(2);
endStatus = obj.terminate();

%% Arduino SPI Test
obj = ArdSPI('COM5', 'Uno', 'spiMode', 0);

% 72   101   108   108   111    44    32   119   111   114   108   100    33

rxData1 = obj.write(1) % Write command: 1
rxData2 = obj.read(13) % Read 13 bytes. Trick to doing this is to write 255 * 13 (implemented in function)

% readCmd = 0b00000001;
% dataToWrite2 = [readCmd zeros(1,50)];

% rxData2 = writeRead(obj.spi, dataToWrite2)
disp("We received: " + char(rxData2));


clear('obj')

% pin = 'D10';
% configurePin(obj.ard, pin, 'DigitalOutput');
% writeDigitalPin(obj.ard, pin, 0);
% pause(3);
% writeDigitalPin(obj.ard, pin, 1);

%% DC2100A Comm Test

% Get Revision command is: [16 

obj = ArdSPI('COM5', 'Uno', 'spiMode', 3);

pin9 = 'D9';

time_ns = 500;
configurePin(obj.ard, pin9, 'DigitalOutput');
writeDigitalPin(obj.ard, pin9, 1)


prevTimer = toc;
writeDigitalPin(obj.ard, pin9, 0);

while (toc - prevTimer)*1E9 < time_ns 
end

writeDigitalPin(obj.ard, pin9, 1)
timer = toc;

s = sprintf("Lasted for %d ns\nOr %d ms\n", (timer-prevTimer)*1E9, (timer-prevTimer)*1E3);
fprintf(s);


% pause(1);

% writeDigitalPin(obj.ard, pin9, 0);
% % java.lang.Thread.sleep(time_ns/1000000);
% writeDigitalPin(obj.ard, pin9, 1)


% writeDigitalPin(obj.ard, pin9, 0);
% 
% for i=1:50
% rxData = obj.write([128 2 91 30]);
% 
% % rxData = obj.write([128 2 91 30])
% 
% % rxData = obj.write(255)
% 
% rxData = obj.read(8)
% pause(0.5);
% end
% writeDigitalPin(obj.ard, pin9, 1)


% txCmd11 = uint8([135 33 84 166]);
% txCmd12 = uint8([106 8 0 8 14 8 110 144]);
% 
% txCmd21 = uint8([135 35 201 240]);
% txCmd22 = uint8([255 255 255 255 255 255 255 255 255]);
% 
% txCmd31 = uint8([135 33 84 166]);
% txCmd32 = uint8([106 26 15 240 15 240 71 56]);
% 
% txCmd41 = uint8([135 35 201 240]);
% txCmd42 = uint8([255 255 255 255 255 255 255 255 255]);
% 
% txCmd51 = uint8([135 34 66 194]);
% 
% rxData11 = obj.write(txCmd11);
% rxData12 = obj.write(txCmd12);
% 
% rxData21 = obj.write(txCmd21);
% rxData22 = obj.write(txCmd22);
% 
% rxData31 = obj.write(txCmd31);
% rxData32 = obj.write(txCmd32);
% 
% rxData41 = obj.write(txCmd41);
% rxData42 = obj.write(txCmd42);
% 
% rxData51 = obj.write(txCmd51)
% rxData = obj.read(8)


clear('obj')
%%
obj = LTC6804();
% wakeup(obj);
[success, revision] =  obj.Refon_Get(LTC6804.BROADCAST)
% 
% obj.quit();

%% ParPool Test

f = parfeval(@do,1,1000);
% afterAll(f, @disp, 0);
mf = afterAll(f, @do_2, 1);
v = fetchOutputs(mf)
disp(" There")


%% Test Serial communication with STM Nucleo
s = serialport('COM6',9600);
writeline(s,"1");
writeline(s,"0");

delete(s);

%% TearDown
script_resetDevices; % Run script

%% Functions
function s = do(val)
    for i=1:val 
    end
    s = "Hello";
end

function n = do_2(s)
    disp (s);
    n = true;
end