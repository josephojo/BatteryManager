if (( toc(testTimer)- prevStateTime ) >= readPeriod ) && ~isempty(mpcinfo)
    prevStateTime = toc(testTimer);
    
    % Allows the test data related to the MPC to be displayed right
    % after the battery information regardless of what the
    % verbosity is.
    if verbosity == 1
        printNow = true;
    elseif verbosity == 0
        if dotCounter < 59 % dotCounter is from [script_queryData]
            printNow = false;
        else
            printNow = true;
        end
    else
        printNow = false;
    end
    
    % Collect Measurements
    script_queryData;
    
    ANPOTind = testData.cellCurr(end, :)' < 0;
    interpCurr = testData.cellCurr(end, :)' .* (ANPOTind);
    ANPOT = qinterp2(-predMdl.ANPOT.Curr, predMdl.ANPOT.SOC, predMdl.ANPOT.ANPOT,...
        interpCurr , testData.cellSOC(end, :)' );
    
    %             % Show capability of models to measurement
    %             prevStates = [testData.cellSOC(end-1, :)'; mdl_X([xIND.V1, xIND.V2]);...
    %                 testData.temp(end-1, 2:end)'; ANPOT];
    %             mdl_X = P06_BattStateFcn_HW(prevStates, testData.cellCurr(end, :)', readPeriod, p2, p3, p4);
    %             mdl_Y = P06_OutputFcn_HW(mdl_X, testData.cellCurr(end, :)', readPeriod, p2, p3, p4)';
    
    testData.AnodePot(end+1, :)      = ANPOT(:)';
    testData.SOC_Traj(end+1, :)      = SOC_Traj';
    testData.predOutput(end+1, :)    = mdl_Y;
    testData.predStates(end+1, :)    = mdl_X; % xk(:)';
    testData.optBalCurr(end+1, :)    = optBalCurr'; % "optimized" balance current
    testData.optPSUCurr(end+1, :)    = optPSUCurr;
    testData.Cost(end+1, :)          = cost;
    testData.Iters(end+1, :)         = iters;
    testData.ExitFlag(end+1, :)      = mpcinfo.ExitFlag; ExitFlag = mpcinfo.ExitFlag;
    sTime = [sTime; actual_STime];
    testData.sTime(end+1, :)         = actual_STime;
    
    if printNow == true
        MPCStr = ""; ANPOTStr = ""; balStr = "";
        MPCStr = MPCStr + sprintf("ExitFlag = %d\tCost = %e\t\tIters = %d\n", mpcinfo.ExitFlag, cost, iters);
        
        for i = 1:NUMCELLS-1
            ANPOTStr = ANPOTStr + sprintf("ANPOT %d = %.3f A/m^2\t", i, testData.AnodePot(end,i));
            balStr = balStr + sprintf("Bal %d = %.4f A\t", i, testData.balCurr(end,i));
        end
        
        for i = i+1:NUMCELLS
            ANPOTStr = ANPOTStr + sprintf("ANPOT %d = %.3f A/m^2\n", i, testData.AnodePot(end,i));
            balStr = balStr + sprintf("Bal %d = %.4f A\n", i, testData.balCurr(end,i));
        end
        
        fprintf(ANPOTStr + newline);
        fprintf(balStr + newline);
        fprintf(MPCStr + newline);
        
        timingStr = sprintf("Prev Opt Time: %.3f Secs", sTime(end, 1));
        if BalanceCellsFlag == true
            balStatusStr = "Balancing";
        else
            balStatusStr = "NOT Balancing";
        end
        fprintf(timingStr + "\t\t Bal Status: " + balStatusStr + newline);
        
        fprintf("Predicted Voltage =\t"); disp(testData.predOutput(end, yIND.Volt))
        fprintf("Predicted SOC =\t"); disp(testData.predStates(end, xIND.SOC))
    end
    
    script_failSafes; %Run FailSafe Checks
    script_checkGUICmd; % Check to see if there are any commands from GUI
    % if limits are reached, break loop
    if strcmpi(testStatus, "stop")
        script_idle;
    end
end
