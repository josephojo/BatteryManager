% Checks to see if limits are reached
if thermoData(2)/10 > battSurfTempLimit
    error = sprintf("Surface TEMP Exceeded Limit:  %.2f ", thermoData(2)/10);
    warning(error);
    clear('thermo');
    waitTS = waitTillTemp(35, cellID);
    battTS = appendBattTS2TS(waitTS, battTS);
%     errorCode = 1;
elseif battVolt <= minBattVoltLimit
    script_queryData;
    if battVolt <= minBattVoltLimit
        error = sprintf("Battery VOLTAGE is Less than Limit: %.2f V", battVolt);
        warning(error);
        errorCode = 1;
    end
elseif battVolt >= maxBattVoltLimit
    error = sprintf("Battery VOLTAGE is Greater than Limit: %.2f V", battVolt);
    warning(error);
    errorCode = 1;
elseif battCurr <= minBattCurrLimit
    error = sprintf("Battery CURRENT is Less than Limit: %.2f V", battCurr);
    warning(error);
    errorCode = 1;
elseif battCurr >= maxBattCurrLimit
    error = sprintf("Battery CURRENT is Greater than Limit: %.2f V", battCurr);
    warning(error);
    errorCode = 1;
elseif battSOC > 1.05 && trackSOCFS == true
    warning("Battery SOC is Greater than 100%%:  %.2f%%",battSOC*100);
elseif battSOC <= -0.005  && trackSOCFS == true
    warning("Battery SOC is Less than 0%%:  %.2f%%",battSOC*100);
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