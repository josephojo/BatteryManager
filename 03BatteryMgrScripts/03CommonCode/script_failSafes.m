% Checks to see if limits are reached
for cellID = cellIDs
%     if cells.coreTemp(cellID) > battCoreTempLimit
%         error = sprintf("Core TEMP for " + cellID + " has Exceeded Limit:  %.2f ",...
%             cells.coreTemp(cellID));
%         warning(error);
%         clear('thermo');
%         save(dataLocation + "007BatteryParam.mat", 'batteryParam');
%         script_resetDevices
%         waitTS = waitTillTemp('core','cellIDs', cellID, 'temp', 35);
%         battTS = appendBattTS2TS(battTS, waitTS);
%         script_initializeDevices;
%         %     errorCode = 1;
%     elseif cells.surfTemp(cellID) > batteryParam.maxSurfTemp(cellID)
%         error = sprintf("Surface TEMP for " + cellID + " has Exceeded Limit:  %.2f ", cells.surfTemp(cellID));
%         warning(error);
%         clear('thermo');
%         save(dataLocation + "007BatteryParam.mat", 'batteryParam');
%         script_resetDevices;
%         waitTS = waitTillTemp('surf','cellIDs', cellID, 'temp', 35);
%         battTS = appendBattTS2TS(battTS, waitTS);
%         script_initializeDevices;
%         %     errorCode = 1;
%     else
    if cells.volt(cellID) <= batteryParam.minVolt(cellID)
        script_queryData;
        if cells.volt(cellID) <= batteryParam.minVolt(cellID)
            error = sprintf("Battery VOLTAGE for " + cellID + " is Less than Limit: %.2f V", cells.volt(cellID));
            warning(error);
            errorCode = 1;
        end
    elseif cells.volt(cellID) >= batteryParam.maxVolt(cellID)
        error = sprintf("Battery VOLTAGE for " + cellID + " is Greater than Limit: %.2f V", cells.volt(cellID));
        warning(error);
        errorCode = 1;
    elseif cells.curr(cellID) <= batteryParam.minCurr(cellID)
        error = sprintf("Battery CURRENT for " + cellID + " is Less than Limit: %.2f V", battCurr);
        warning(error);
        errorCode = 1;
    elseif cells.curr(cellID) >= batteryParam.maxCurr(cellID)
        error = sprintf("Battery CURRENT for " + cellID + " is Greater than Limit: %.2f V", battCurr);
        warning(error);
        errorCode = 1;
    elseif cells.SOC(cellID) > 1.05 && trackSOCFS == true
        warning("Battery SOC for " + cellID + " is Greater than 100%%:  %.2f%%",cells.SOC(cellID)*100);
    elseif cells.SOC(cellID) <= -0.005  && trackSOCFS == true
        warning("Battery SOC for " + cellID + " is Less than 0%%:  %.2f%%",cells.SOC(cellID)*100);
    end
end

[alarmState, alarm] = psu.getAlarmCode();
al = 0;
if alarmState == true
    al = al+1;
    if al <= 5
        warning("PSU AlarmState is True. Cause: " + alarm);
    end
    if al == 1
        notifyOwnerEmail("PSU AlarmState is True. Cause: " + alarm)
    end
end

[alarmState, alarm] = psu.getAlarmCode();
al = 0;
if alarmState == true
    al = al+1;
    if al <= 5
        warning("PSU AlarmState is True. Cause: " + alarm);
    end
    if al == 1
        notifyOwnerEmail("PSU AlarmState is True. Cause: " + alarm)
    end
end

if errorCode == 1
    notifyOwnerEmail(error)
end

