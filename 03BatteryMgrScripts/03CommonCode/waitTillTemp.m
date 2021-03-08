function [testData, metadata, testSettings]  = waitTillTemp(tcChnl, varargin)
%waitTillTemp Pauses the program from running until the surf Temp decreases
%   Halts the program while surf or Core Temp decreases or they both equal
%   each other

% clearvars;

%% Parse Input Argument or set Defaults
param = struct('battID',        [],...
    'targTemp',            25);

% read the acceptable names
paramNames = fieldnames(param);

% Ensure variable entries are pairs
nArgs = length(varargin);
if round(nArgs/2)~=nArgs/2
    error('runProfile needs propertyName/propertyValue pairs')
end

for pair = reshape(varargin,2,[]) %# pair is {propName;propValue}
    inpName = pair{1}; %# make case insensitive
    
    if any(strcmpi(inpName,paramNames))
        %# overwrite options. If you want you can test for the right class here
        %# Also, if you find out that there is an option you keep getting wrong,
        %# you can use "if strcmp(inpName,'problemOption'),testMore,end"-statements
        param.(inpName) = pair{2};
    else
        error('%s is not a recognized parameter name',inpName)
    end
end

% ---------------------------------

%% Start Routine
battID = param.battID;

script_initializeVariables;
script_initializeDevices;
script_failSafes; %Run FailSafe Checks
if errorCode == 1 || strcmpi(testStatus, "stop")
    script_idle;
    return;
end

battState = "idle";
script_idle;

script_queryData;

tcChnl = sort(tcChnl); % Sort TC Channels in Ascending order
tcInd = tcChnl == readChnls; % Get the index from what is being measured
targTemp = param.targTemp;

fprintf("Waiting for battery to cool down: " + newline + ...
        "TC %d = %.2fºC" + newline, tcChnl, testData.temp(end, tcInd));
    
while max(round(testData.temp(end, tcInd)) > targTemp) == 1
    if toc(testTimer) - timerPrev(3) >= readPeriod
        timerPrev(3) = toc(testTimer);
        script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
    end
end

disp("Waiting Done" + newline);

script_resetDevices;
% clearvars;
end
