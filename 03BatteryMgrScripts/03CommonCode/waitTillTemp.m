function [battTS, cells] = waitTillTemp(tempSrc, varargin)
%waitTillTemp Pauses the program from running until the surf Temp decreases
%   Halts the program while surf or Core Temp decreases or they both equal
%   each other

% clearvars;

param = struct('cellIDs',        [],...
                'temp',            25);


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
cellIDs = param.cellIDs;


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

if strcmpi(tempSrc, 'surfcore')
    fprintf("Waiting for CoreTemp to equal surfTemp: " + newline + ...
        "Surf Temp = %.2fºC \t\t\t" + ...
        "Core Temp = %.2fºC " + newline, mean(cells.surfTemp(cellIDs)), mean(cells.coreTemp(cellIDs)));

%     Wait till surfTemp and coreTemp are 0.2 degs apart
    while (round(abs(mean(cells.coreTemp(cellIDs)) - mean(cells.surfTemp(cellIDs))),2)...
            > 2.0)
        if toc(testTimer) - timerPrev(3) >= readPeriod
            timerPrev(3) = toc(testTimer);
            script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
        end
    end
elseif strcmpi(tempSrc, 'core')
    temp = param.temp;
    disp("Waiting for CoreTemp to Decrease from: " + mean(cells.coreTemp(cellIDs)) + "ºC To: " + temp);


    % Waits until mean(cells.coreTemp(cellIDs)) = 25ºC
    while (mean(cells.coreTemp(cellIDs)) > temp)
        if toc(testTimer) - timerPrev(3) >= readPeriod
            timerPrev(3) = toc(testTimer);
            script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
        end
    end
elseif strcmpi(tempSrc, 'surf')
    temp = param.temp;
    disp("Waiting for SurfTemp to Decrease from: " + mean(cells.surfTemp(cellIDs)) + "ºC To: " + temp);

    % Waits until mean(cells.surfTemp(cellIDs)) = 25ºC
    while (mean(cells.surfTemp(cellIDs)) > temp)
        if toc(testTimer) - timerPrev(3) >= readPeriod
            timerPrev(3) = toc(testTimer);
            script_queryData; % Runs the script that queries data from the devices. Stores the results in the [dataCollection] Variable
        end
    end
end
disp("Waiting Done" + newline);

script_resetDevices;
% clearvars;
end
