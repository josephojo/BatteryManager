function battTS = waitTillTemp(temp, varargin)
%waitTillTemp Pauses the program from running until the surf Temp decreases
%   Halts the program while surf Temp decreases

% clearvars;

if nargin > 1
    cellID = varargin{1};
end
    

script_initializeDevices;
script_initializeVariables;

battState = "idle";
script_idle;

script_queryData;

disp("Waiting for SurfTemp to Decrease from: " + thermoData(2) + "ºC To: " + temp);


% Wait till temp including core temp
%   while (round(abs(thermoData(2) - thermoData(3))/10,1) > 0)

% Waits until thermoData(2)[surf Temp] = 25ºC
while (thermoData(2) > temp)
    if toc - timerPrev(3) >= readPeriod
        timerPrev(3) = toc;
        script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
    end
end

disp("Waiting Done" + newline);

script_resetDevices;
% clearvars;
end
