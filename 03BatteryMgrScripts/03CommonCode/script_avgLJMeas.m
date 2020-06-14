
% Due to the imprecision of the Labjack ADC (12bit)or 5mV variation
% This section averages 50 individual values from 2 analog ports
% vBattp (Vbatt+) and vBattn(Vbatt-) to stabilize the voltage
% difference and attain a variation of ±0.001 V or ±1 mV
while adcAvgCounter < adcAvgCount
%      v = v + readVoltage(ard, 'A0');
     
    % Request a single-ended reading from AIN4 (VShunt+).
%     ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN_DIFF', 0, 0, 1, 0); %4, 0,5, 0);

%     % Request a single-ended reading from AIN0 (C1+). first current sense
%     ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN', 0, 0, 0, 0);
%     
%     % Request a single-ended reading from AIN7 (C2+). second current sense
%     ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN', 1, 0, 0, 0);
%     
%     % Request a single-ended reading from AIN1 (C-).
%     ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN', 7, 0, 0, 0);

    if ismember("curr", testSettings.data2Record) && strcmpi(testSettings.currMeasDev, "mcu") 
        % Request a single-ended reading from AIN0 (C1+). first current sense
        ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN', currPinPos, 0, 0, 0);

        % Request a single-ended reading from AIN1 (C-).
        ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN', currPinNeg, 0, 0, 0);
    end
    
    if ismember("volt", testSettings.data2Record) && strcmpi(testSettings.voltMeasDev, "mcu") 
        % Request a single-ended reading from AIN2 (VBatt+).
        ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN', voltPinPos, 0, 0, 0);

        % Request a single-ended reading from AIN3 (VBatt-).
        ljudObj.AddRequestS(ljhandle, 'LJ_ioGET_AIN', voltPinNeg, 0, 0, 0);
    end
    
    % Execute the requests.
    ljudObj.GoOne(ljhandle);
    
    [ljerror, ioType, channel, dblValue, dummyInt, dummyDbl] = ljudObj.GetFirstResult(ljhandle, 0, 0, 0, 0, 0);
    
    finished = false;
    while finished == false
        switch ioType
            case LJ_ioGET_AIN
                switch int32(channel)
                    case currPinPos
                        currPos = currPos + dblValue;
                    case currPinNeg
                        currNeg = currNeg + dblValue;
                    case 1
                        ain1 = ain1 + dblValue;
                    case voltPinPos
                        voltPos = voltPos + dblValue;
                    case voltPinNeg
                        voltNeg = voltNeg + dblValue;
                    
                end
            case LJ_ioGET_AIN_DIFF
                switch int32(channel)
                    case 0
                        currPos = currPos + dblValue;
                    case 1
                        ain1 = ain1 + dblValue;
                end
        end
        
        % Try to get the next results. If no results (through exception), 
        % cancel data collection process
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