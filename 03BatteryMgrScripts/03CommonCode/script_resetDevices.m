% Disconnects both charger and discharger FIRST(This is IMPORTANT!!) before the relays
% if exist('psu','var')
%     if strcmpi(psu.SerialObj.Status, 'open')
%         psu.disconnect();
%     end
% end

if caller == "gui"
%% Caller == GUI
    
    if exist('psu','var')
        if isvalid(psu)
            psu.disconnect();
            psu.SerialObj = [];
            clear('psu');
        end
    end
    
    
    if exist('eload','var')
        if isvalid(eload)
            eload.Disconnect();
            eload.SerialObj = [];
            clear('eload');
        end
    end
    
    if exist('ljasm','var')
        relayState = false;
        if (isempty(ljasm) == 0)
            script_switchRelays;
            ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4, 0, 0, 0);
            ljudObj.GoOne(ljhandle);
            ljudObj.Close();
            clear('ljudObj', 'ljasm');
        end
    end
    
    
    if exist('thermo','var')
        clear ('thermo');
    end

    disp("Devices Reset" + newline);

    
else
%% Caller == Command Window

if exist('psu','var')
    if strcmpi(psu.serialStatus, 'Connected')
        psu.disconnect();
        [alarmState, alarm] = psu.getAlarmCode();
        if alarmState == true
           warning("PSU Alarm state is True" + newline +...
               "Alarm code is %s", alarm);
           disp ("Attempting to clear alarm...")
           reply = psu.ClearAlarmCode();
           % If alarm is not cleared after an attempt notify user
           if ~strcmpi("Alarm Cleared", reply)
               notifyOwnerEmail("ATTENTION! Unable to clear PSU Alarm. Manual Override Required!!!")
           else
              disp(reply) 
           end
        end
        psu.disconnectSerial();
        clear('psu');
    end
end

if exist('eload','var')
    if strcmpi(eload.serialStatus, 'Connected')
        eload.Disconnect();
        [alarmState, alarm] = eload.getAlarmCode();
        if alarmState == true
           warning("ELoad Alarm state is True" + newline +...
               "Alarm code is %s", alarm);
           disp ("Attempting to clear alarm...")
           reply = eload.ClearAlarmCode();
           % If alarm is not cleared after an attempt notify user
           if ~strcmpi("Alarm Cleared", reply)
               notifyOwnerEmail("ATTENTION! Unable to clear ELoad Alarm. Manual Override Required!!!")
           else
              disp(reply) 
           end
        end
        eload.disconnectSerial();
        clear('eload');
    end
end


if exist('ljasm','var')
    relayState = false;
    if (isempty(ljasm) == 0)
        script_switchRelays;
        ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4, 0, 0, 0); % Turn off Trigger Pin
        ljudObj.GoOne(ljhandle);
        ljudObj.Close();
        clear('ljudObj', 'ljasm');
    end
end


if exist('thermo','var')
    clear ('thermo');
end

disp("Devices Reset" + newline);

end