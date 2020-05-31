function battTS = waitTillTime(seconds, heatPad)
%waitTillTemp Pauses the program from running until the Core Temp equals the surf
%Temp
%   Halts the program while Temp and Core Temp values converge
% clearvars;
try
disp("Waiting for " + num2str(seconds) + " Seconds!");

script_initializeDevices;
script_initializeVariables;

battState = "idle";

script_queryData;

t1 = toc;
t = 0;

heatPadStartTime = 100.0;
heatPadEndTime = 220.0;
heatPadTimeTol = 0.5;

while (t < seconds)
    t2 = toc;
    t = t2 - t1;
    
    if toc - timerPrev(3) >= readPeriod
        timerPrev(3) = toc;
        script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
         % HEATING PAD
        if heatPad==true
            % The Relay that was origninally used for an LED has been repurposed
            % for the heating pad. The pad switches on heatPadStartTime (+5s)
            % and switches OFF heatPadEndTime (+5s)
            if tElasped >= heatPadStartTime && tElasped < heatPadStartTime + heatPadTimeTol
                disp("Heat Pad Turned ON - " + num2str(tElasped))
                % Make sure the heating pad is ON
                ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4, false, 0, 0);
                ljudObj.GoOne(ljhandle);
            elseif tElasped >= heatPadEndTime && tElasped < heatPadEndTime + heatPadTimeTol
                disp("Heat Pad Turned OFF" + num2str(tElasped))
                % Make sure the heating pad is ON
                ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4, true, 0, 0);
                ljudObj.GoOne(ljhandle);
            end
        end
    end
end

t1 = t2;
t=0;

disp("Waiting Done" + newline);

script_resetDevices;

catch ME
    script_resetDevices;
    rethrow(ME);
end
% clearvars;
end
