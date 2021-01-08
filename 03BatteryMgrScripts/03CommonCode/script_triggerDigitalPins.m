%% Triggers (GPIO from LabJack)
        if trigAvail == true
            % The trigger is activated on trig1StartTime
            % and switches OFF trig1EndTime
            
            %{
                 if tElasped >= triggers.startTimes(trig_Ind) && ...
                        tElasped < triggers.startTimes(trig_Ind) + trigTimeTol && ...
                        trig_On(trig_Ind) == false
            %}
            trig_Ind = tElasped >= triggers.startTimes & ...
                tElasped < triggers.startTimes + trigTimeTol;
            if max(trig_On(trig_Ind) == false)
                disp("Trigger ON - " + num2str(timerPrev(3))+ newline)
                if strcmpi(caller, "gui")
                    err.code = ErrorCode.WARNING;
                    err.msg = "Trigger ON - " + num2str(timerPrev(3))+ newline;
                    send(errorQ, err);
                end
                pinVal = ~(true & triggers.inverts(trig_Ind)); % Flips the pinVal if invert is true
                % Trigger Device ON
                [ljudObj,ljhandle] = MCU_digitalWrite(ljudObj, ljhandle, triggers.pins(trig_Ind), pinVal);
                trig_On(trig_Ind) = true;
                %                             trig_Ind = trig_Ind + 1;
            end
            
            %{
                if tElasped >= triggers.endTimes(trig_Ind) && ...
                        tElasped < triggers.endTimes(trig_Ind) + trigTimeTol && ...
                        trig_On(trig_Ind) == true
            %}
            trig_Ind = tElasped >= triggers.endTimes & ...
                tElasped < triggers.endTimes + trigTimeTol;
            if max(trig_On(trig_Ind) == true)
                disp("Trigger OFF - " + num2str(timerPrev(3))+ newline)
                if strcmpi(caller, "gui")
                    err.code = ErrorCode.WARNING;
                    err.msg = "Trigger OFF - " + num2str(timerPrev(3))+ newline;
                    send(errorQ, err);
                end
                pinVal = ~(false & triggers.inverts(trig_Ind)); % Flips the pinVal if invert is true
                % Trigger Device OFF
                [ljudObj,ljhandle] = MCU_digitalWrite(ljudObj, ljhandle, triggers.pins(trig_Ind), pinVal);
                trig_On(trig_Ind) = false;
                %                             if length(trigStartTimes) > 1 && trig_Ind ~= length(trigStartTimes)
                %                                 trig_Ind = trig_Ind + 1;
                %                             end
            end
        end