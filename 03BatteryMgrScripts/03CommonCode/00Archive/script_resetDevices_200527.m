% Disconnects both charger and discharger FIRST(This is IMPORTANT!!) before the relays
% if exist('psu','var')
%     if strcmpi(psu.SerialObj.Status, 'open')
%         psu.disconnect();
%     end
% end

if ~exist('psuPort','var')
    eloadPort = 'COM2';
    thermoPort = 'COM5';
    psuPort = 'COM7';
%     ardPort = 'COM8';
end

psuSerial = instrfind('Port',psuPort, 'Status', 'open');
if exist('psu','var')
    if strcmpi(psu.SerialObj.Status, 'open')
        psu.disconnect();
        [alarmState, alarm] = psu.getAlarmCode();
        if alarmState == true
           warning("PSU Alarm state is True" + newline +...
               "Alarm code is %s", alarm);
           disp ("Attempting to clear alarm...")
           reply = psu.ClearAlarmCode();
           % If alarm is not cleared after an attempt notify user
           if ~strcmpi("Alarm Cleared", reply)
               notifyOwnerEmail("ATTENTION! Unable to clear PSU Alarm. Manual Override needed!!!")
           else
              disp(reply) 
           end
        end
        fclose(psu.SerialObj);
        delete(psu.SerialObj);
        disp('psu')
        clear('psu');
    end
elseif ~exist('psu','var') && ~isempty(psuSerial)
    psu = APM_PSU('serialObj', psuSerial);
    psu.disconnect();
    fclose(psu.SerialObj);
    delete(psu.SerialObj);
    disp('psuSerial')
    clear('psu');
end

% if exist('eload','var')
%     if strcmpi(eload.SerialObj.Status, 'open')
%         eload.Disconnect();
%     end   
% end

eloadSerial = instrfind('Port',eloadPort, 'Status', 'open');
if exist('eload','var')
    if strcmpi(eload.SerialObj.Status, 'open')
        eload.Disconnect();
        fclose(eload.SerialObj);
        delete(eload.SerialObj);
        clear('eload');
    end
elseif ~exist('eload','var') && ~isempty(eloadSerial)
    eload = Array_ELoad('serialObj', eloadSerial);
    eload.Disconnect();
    fclose(eload.SerialObj);
    delete(eload.SerialObj);
    clear('eload');
end

% ardSerial = instrfind('Port',ardPort, 'Status', 'open');
% if exist('ard','var')
%     if strcmpi(ard.Status, 'open')
%         fclose(ard);
%         delete(ard);
%         clear ard;
%     end
% elseif ~exist('ard','var') && ~isempty(ardSerial)
%     ard = ardSerial;
%     fclose(ard);
%     delete(ard);
%     clear ard;
% end

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

% if exist('psu','var')
%     if ~strcmpi(psu.SerialObj.Status, 'closed')
%         fclose(psu.SerialObj);
%     end
% end
% 
% if exist('eload','var')
%     if ~strcmpi(eload.SerialObj.Status, 'closed')
%         fclose(eload.SerialObj);
%     end
% end

if exist('thermo','var')
    clear ('thermo');
end

disp("Devices Reset" + newline);
