%% Initialize
clc;
clearvars;

try
cellID = 'aa5';
script_initializeDevices
script_initializeVariables

curr = 2.0;
script_discharge;
wait(1);

%% Query
queryTimer = tic;
disp("Before Query");
toc(queryTimer)

script_queryData

disp("After Query");
toc(queryTimer)

disp(newline)

catch ME
    script_resetDevices;
    if errorCode ~= 2
        rethrow(ME);
    end
end

%% Tear Down
script_resetDevices;

