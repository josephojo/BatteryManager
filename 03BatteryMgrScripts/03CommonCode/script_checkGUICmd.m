
if strcmpi(caller, "gui")
   if ~isempty(cmdQ) && cmdQ.QueueLength > 0
       reply2Q = "Failed";
       valComdQ = poll(cmdQ);
       switch valComdQ
           case "stop"
               testStatus = "stop";
               trigAvail = false;
               reply2Q = "stopped";
           case "pause"
               testStatus = "pause";
               reply2Q = "paused";
               send(randQ, reply2Q);
               
               tempTime = toc(testTimer);
               state = battState; % get charging state
               script_idle;
               while ~strcmpi(testStatus, "running") || ~strcmpi(testStatus, "stop")
                   if toc(testTimer) - timerPrev(3) >= readPeriod
                        timerPrev(3) = toc(testTimer);
                        script_queryData; % Run Script to query data from devices
                        script_failSafes; %Run FailSafe Checks
                        script_checkGUICmd; % Check to see if there are any commands from GUI
                   end
               end
               if strcmpi(testStatus, "running") % If new command is to unpause
                   pauseDuration = toc(testTimer) - tempTime;
                   % Since triggers are based on times since program started,
                   % need to compensate them with the pause duration
                   if trigAvail == true
                       triggers.startTimes = trigger.startTimes + pauseDuration;
                       triggers.endTimes = trigger.endTimes + pauseDuration;
                   end
                   
                   if strcmp(state, "charging")
                       script_charge;
                   elseif strcmp(state, "discharging")
                       script_discharge;
                   end
               end
           case "unpause"
               testStatus = "running";
               reply2Q = "unpaused";
           otherwise
%                reply2Q = "Unrecognized Command: " + string(valComdQ);
       end
       
       if ~strcmpi(valComdQ, "pause")
           send(randQ, reply2Q);
       end
   end
end