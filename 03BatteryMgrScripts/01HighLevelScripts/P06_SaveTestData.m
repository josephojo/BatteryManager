    % Save Battery Parameters
    save(dataLocation + "007BatteryParam.mat", 'batteryParam');
    
    if strcmpi(testStatus, "stop")
        % Save Test Data
        testSettings.saveDir = testSettings.saveDir + metadata.startDate...
            +"_"+ metadata.startTime + "_" + ExpName +"_ErroredOut_" ...
            + strjoin(string(errorCode(errorCode ~= ErrorCode.NO_ERROR)), "_")...
            +"\";
        testData.errCode = errorCode;
    elseif strcmpi(testStatus, "running")
        % Save Test Data
        testSettings.saveDir = testSettings.saveDir + metadata.startDate...
            +"_"+ metadata.startTime + "_" + ExpName +"_Successful\";
    else 
        % Save Test Data
        testSettings.saveDir = testSettings.saveDir + metadata.startDate...
            +"_"+ metadata.startTime + "_" + ExpName +"_Failed\";
        testData.errCode = errorCode;
    end
    % Save Data
    [saveStatus, saveMsg] = saveTestData(testData, metadata, testSettings);
    
    if saveStatus == false
        warning(saveMsg);
    else
        eventLog.SaveLogs(char(extractBefore(...
        testSettings.saveDir,...
        strlength(testSettings.saveDir)...
                                            )));
                                        
        [status,msg,msgID] = copyfile(codeFilePath + ".m", testSettings.saveDir);
        copyfile(codePath + "\" + "P06_Constants.m", testSettings.saveDir);
        copyfile(codePath + "\" + "P06_PredMdl.m", testSettings.saveDir);
        copyfile(codePath + "\" + "P06_PrepareMPCInput.m", testSettings.saveDir);
        copyfile(codePath + "\" + "P06_BattStateFcn_HW.m", testSettings.saveDir);
        copyfile(codePath + "\" + "P06_OutputFcn_HW.m", testSettings.saveDir);
        copyfile(codePath + "\" + "P06_CostFcn_HW.m", testSettings.saveDir);

    end
    