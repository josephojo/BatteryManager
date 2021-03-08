function battTS = heatTillTime(targTime, heatPad, varargin)
%heatTillTime Turns on the heatpad until the specified number of seconds

% clearvars;
try
cellID = 'AA5';

heatPadStartTime = targTime * 0.2; %100.0;
if nargin > 2 && strcmpi(class(varargin{1}),'double')
    heatPadEndTime = heatPadStartTime + varargin{1}; %220.0;
elseif nargin == 2 && targTime < 10
    heatPadEndTime = heatPadStartTime + targTime - 2;
else
    heatPadEndTime = heatPadStartTime + 10;
end
heatPadTimeTol = 0.5;


script_initializeDevices;
script_initializeVariables;

verbose = 1;

script_queryData;
script_idle;



testTimer = tic; % Start Timer for read period

disp("Waiting for " + num2str(targTime) + " Seconds!");
heatTimer = tic; % heatTillTime Timer
ticker = 0;

while (ticker < targTime)    
    ticker = toc(heatTimer);

    if toc(testTimer) - timerPrev(3) >= readPeriod
        timerPrev(3) = toc(testTimer);
        script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
         % HEATING PAD
        if heatPad==true
            % The Relay that was origninally used for an LED has been repurposed
            % for the heating pad. The pad switches on heatPadStartTime (+5s)
            % and switches OFF heatPadEndTime (+5s)
            if ticker >= heatPadStartTime && ticker < heatPadStartTime + heatPadTimeTol
                disp("Heat Pad Turned ON - " + num2str(tElasped))
                % Make sure the heating pad is ON
                ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4, true, 0, 0);
                ljudObj.GoOne(ljhandle);
            elseif ticker >= heatPadEndTime && ticker < heatPadEndTime + heatPadTimeTol
                disp("Heat Pad Turned OFF" + num2str(tElasped))
                % Make sure the heating pad is ON
                ljudObj.AddRequestS(ljhandle,'LJ_ioPUT_DIGITAL_BIT', 4, false, 0, 0);
                ljudObj.GoOne(ljhandle);
            end
        end
    end
    
end


catch MEX
    script_resetDevices;
    if caller == "cmdWindow"
        rethrow(MEX);
    else
        send(errorQ, MEX)
    end
end
% clearvars;

script_resetDevices;

end
