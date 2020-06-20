
% Send the command Queue object back to the caller so that commands such as
% "stop" and "pause" can be sent to the program as it runs
if strcmpi(caller, "gui")
   cmdQ = parallel.pool.PollableDataQueue; 
   if ~isempty(randQ)
       send(randQ, cmdQ);
   end
end

%% Gets the full path for the current file and changes directory
if caller == "gui"
    dataLocation = testSettings.dataLocation + "\";
else
    currFilePath = mfilename('fullpath');
    % Seperates the path directory and the filename
    [path, filename, ~] = fileparts(currFilePath);
    
    newStr = extractBetween(path,"",...
                   "03DataGen","Boundaries","inclusive");
    dataLocation = newStr + "\01CommonDataForBattery\";
  
    %{
%     % goes to path
%     cd(path + "\..\..")
% 
%     % Retreives current directory
%     path = pwd;
%     dataLocation = path + "\01CommonDataForBattery\";
    %}
end

%% Battery Connection Info

% If for some reason the variable does not exist.
if ~exist("cellIDs", 'var') || isempty(cellIDs)
%     cellID_In = upper(input('Please enter the cellID for the battery being tested: ','s')); % ID in Cell Part Number (e.g BAT11-FEP-AA1)
    prompt = {'Enter a space-separated list of cellID for the battery being tested: '};
    dlgtitle = 'Cell ID Input';
    dims = [1 50];
    definput = {'AB1 AB2 ... or ab1 ab2'};
    cellIDs_In = upper(inputdlg(prompt,dlgtitle,dims,definput));
    cellIDs = string(split(cellIDs_In{1},[" ",",", ", "]))';
    cellIDs(cellfun('isempty',cellIDs)) = []; % remove empty cells from cellIDs_In
end

% Number of cells
numCells = length(cellIDs);

%Load PrevSOC
load(dataLocation + "007BatteryParam.mat", 'batteryParam');

if caller == "cmdWindow"
    % Input data for new battery into database.
    for cellID = cellIDs
        if max(ismember(batteryParam.Row, cellID)) == 0

            answer = questdlg(['Parameters for ' char(cellID) ' does not exist in storage.'...
                newline newline 'Would you like to create them now?' newline], ...
            ['Cell with name ' char(cellID) ' does not exist in database'], ...
            'Yes, Create Now','No, Quit Program','No, Quit Program');
            % Handle response
            switch answer
                case 'Yes, Create Now'
                    disp(newline + "Here we go ...");
                case 'No, Quit Program'
                    errorCode = 2;
                    error(newline + "Rerun the program to try again." + newline +...
                        "Quitting  now."  + newline);
            end

            prompt = {'Chemistry?: ','Capacity (Ah)?: ', 'ChargeTo Voltage (V)?: ', 'DishargeTo Voltage (V)?: ',...
                 'CV charge stop current (A)?: ', 'Maximum Voltage Limit (V)?: ',...
                'Minimum Voltage Limit (V)?: ', 'Maximum Charge Current Limit (A)?: ', ...
                'Maximum Discharge Current Limit (A)?: ', 'Rated Capacity from Manufacturer (Ah)?: ',...
                'Maximum Surface Temp Limit (°C)?: ', 'Maximum Core Temp Limit (°C)?: '};
            dlgtitle = ['Parameter input for Cell ID ' char(cellID)];
            dims = [1 50];
            definput = {'LFP', '2.5', '3.6', '2.5', '0.125', '3.61', '2.49', '16',...
                '-30', '2.5', '50', '55'};
            params = inputdlg(prompt,dlgtitle,dims,definput);

            chemistry       = upper(string(params{1}));
            capacity        = str2double(params{2});
            soc             = 1;
            chargedVolt     = str2double(params{3});
            dischargedVolt  = str2double(params{4});
            cvStopCurr      = str2double(params{5});
            maxVolt         = str2double(params{6});
            minVolt         = str2double(params{7});
            maxCurr         = str2double(params{8});
            minCurr         = -abs(str2double(params{9}));
            ratedCapacity   = str2double(params{10});
            maxSurfTemp     = str2double(params{11});
            maxCoreTemp     = str2double(params{12});

            %{
            chemistry = upper(string(input('Chemistry?: ', 's')));
            chargedVolt = input('ChargeTo Voltage (V)?: ');
            dischargedVolt = input('DishargeTo Voltage (V)?: ');
            capacity = input('Capacity (Ah)?: ');
            soc = 1;
            cvStopCurr = input('CV charge stop current (A)?: ');
            maxVolt = input('Maximum Voltage Limit (V)?: ');
            minVolt = input('Minimum Voltage Limit (V)?: ');
            maxCurr = input('Maximum Current Limit (A)?: ');
            minCurr = input('Minimum Current Limit (A)?: ');
            maxSurfTemp = input('Maximum Surface Temp Limit (°C)?: ');
            maxCoreTemp = input('Maximum Core Temp Limit (°C)?: ');
            ratedCapacity = input('Rated Capacity from Manufacturer (Ah)?: ');
            %}

            Tnew = table(chemistry,chargedVolt,dischargedVolt,capacity,soc,...
                cvStopCurr, maxVolt,minVolt,maxCurr,minCurr,maxSurfTemp,...
                maxCoreTemp,ratedCapacity, 'RowNames', { char(cellID)});

            batteryParam = [batteryParam;Tnew];
        end
    end
    save(dataLocation + "007BatteryParam.mat", 'batteryParam');
end


%% Choose Battery Connection Configuration

if caller == "gui"
    cellConfig = testSettings.cellConfig;
else
    %     try
    %        cellConfig = evalin('base', 'cellConfig');
    %     catch
    %     end
    
    if ~isempty(testSettings) && isfield(testSettings, 'cellConfig')
        cellConfig = testSettings.cellConfig;
    end
    
    if ~exist('cellConfig', 'var')
        if numCells == 1
            cellConfig = "single";
        else
            answer = questdlg('What is the stack configuration of the cells connected?', ...
                'Cell Connection Configuration', ...
                'Series Stack','Parallel Stack','Series-Parallel','Parallel Stack');
            % Handle response
            switch answer
                case 'Series Stack'
                    disp(['Configuring for ' answer])
                    cellConfig = 'series';
                case 'Parallel Stack'
                    disp(['Configuring for ' answer])
                    cellConfig = 'parallel';
                case 'Series-Parallel'
                    disp('Configuring for Series-Parallel Stack.')
                    cellConfig = 'SerPar';
            end
        end
    end
end
%% TC Info
if caller == "gui"
    tempChnls = testSettings.tempChnls;
%     ambTemp = 0;
else
%     try
%         numThermo = evalin('base', 'numThermo');
%         firstTCchnl = evalin('base', 'firstTCchnl');
%     catch
%     end
    
    if ~isempty(testSettings) && isfield(testSettings, 'tempChnls')
        tempChnls = testSettings.tempChnls;
    else
        tempChnls = [];
    end
    
    if ~exist("tempChnls", 'var')
        prompt = {'What channels have the temperature sensors been connected to? (Seperate by commas)'};
        dlgtitle = 'Info on Temp. Sensors';
        dims = [1 50];
        definput = {'9, 10, 11, 13'};
        answer = inputdlg(prompt,dlgtitle,dims,definput);
        if ~isempty(answer)
            tempVal = str2double(strsplit(answer{1},','));
            tempChnls = tempVal(~isnan(tempVal));
            disp("You have entered the following channels : " + strjoin(string(tempChnls), ', '))
        end
    end
end

%% Individual cell related variables
cells = table;
for cellID = cellIDs
    prevSOC = batteryParam.soc(cellID);
    volt = 0; curr = 0; AhCap = 0; SOC = prevSOC; coulomb = batteryParam.capacity(cellID)*3600;
    
    
    tnew = table(volt, curr, AhCap, SOC, prevSOC,...
            coulomb, 'RowNames', {char(cellID)});
    
    cells = [cells;tnew];
end

%% Battery Stack Related Variables
% Initializes the Constants used in Data Generation
psuData = zeros(1, 2); % Container for storing PSU Data
eloadData = zeros(1, 2); % Container for storing Eload Data
thermoData = zeros(1, length(tempChnls)); % Container for storing TC Data
% ambTemp = 0;



if ismember("curr", testSettings.data2Record) && strcmpi(testSettings.currMeasDev, "mcu") 
    if ~isempty(sysMCUArgs) && isfield(sysMCUArgs, 'currMeasPins')
        currPinPos = sysMCUArgs.currMeasPins(1);
        currPinNeg = sysMCUArgs.currMeasPins(2);
    else
        currPinPos = 0;
        currPinNeg = 7;
    end
    currNeg = []; currPos = []; adcAvgCounter = 0; % Variables used for labjack(LJ) averaging
    adcAvgCount = 10; %20;

end
if ismember("volt", testSettings.data2Record) && strcmpi(testSettings.voltMeasDev, "mcu") 
    if ~isempty(sysMCUArgs) && isfield(sysMCUArgs, 'voltMeasPins')
        voltPinPos = sysMCUArgs.voltMeasPins(1);
        voltPinNeg = sysMCUArgs.voltMeasPins(2);
    else
        voltPinPos = 2;
        voltPinNeg = 3;
    end
    voltNeg = 0; voltPos = 0; adcAvgCounter = 0; 
    adcAvgCount = 10; %20;

end

              

% Creates an container that will be used to record previous time measurements
timerPrev = zeros(5, 1); 
% timerPrev(1): For Total Elapsed Time 
% timerPrev(2): For Profile period
% timerPrev(3): For Measurement Period
% timerPrev(4): For BattSOC Estimation
% timerPrev(5): For Progress dot (Dot that shows while code runs)

if caller == "gui"
    battProp = stackArgs; % Battery Properties
else
    battProp = batteryParam(cellIDs, :); % Battery Properties
end

%if in series, add all the limit voltages
if strcmpi(cellConfig, 'series')
    % Fully charged voltage
    highVoltLimit = sum(battProp.chargedVolt(cellIDs));  % sum(batteryParam.chargedVolt(cellIDs)); 
    % Fully Discharged Voltage
    lowVoltLimit  = sum(battProp.dischargedVolt(cellIDs)); 
else
    % If in parallel or single cell
    highVoltLimit = mean(battProp.chargedVolt(cellIDs)); % Fully charged voltage
    lowVoltLimit  = mean(battProp.dischargedVolt(cellIDs)); % Fully Discharged Voltage
end

chargeReq = 0; % Charge Request - true/1 = Charging, false/0 = discharging
chargeVolt = highVoltLimit + 0.005; % Due to the small resistance in the wiring

% batt is regarded as the battery stack series or parallel
% cell is the individual cells

prevSOC = mean(battProp.soc(cellIDs));
AhCap = 0;
battState = ""; % State of the battery ("charging", "discharging or idle")
battVolt = 0; % Measured Voltage of the battery stack
battCurr = 0; % Current from either PSU or ELOAD depending on the battState
battSOC = prevSOC; % Estimated SOC of the battery is stored here
if strcmpi(cellConfig, 'series')
    maxBattVoltLimit = sum(battProp.maxVolt(cellIDs)); % Maximum Voltage limit of the operating range of the battery stack
    minBattVoltLimit = sum(battProp.minVolt(cellIDs)); % Minimum Voltage limit of the operating range of the battery stack
    coulombs = mean(battProp.capacity(cellIDs)*3600); % Convert Ah to coulombs
else
    coulombs = sum(battProp.capacity(cellIDs)*3600); % Convert Ah to coulombs
    maxBattVoltLimit = mean(battProp.maxVolt(cellIDs)); % Maximum Voltage limit of the operating range of the battery stack
    minBattVoltLimit = mean(battProp.minVolt(cellIDs)); % Minimum Voltage limit of the operating range of the battery stack
end
if strcmpi(cellConfig, 'parallel')
    cvMinCurr = sum(batteryParam.cvStopCurr(cellIDs)); %10% of 1C
    maxBattCurrLimit = sum(battProp.maxCurr(cellIDs)); % Maximum Specified (by us) Current limit of the operating range of the battery
    minBattCurrLimit = sum(battProp.minCurr(cellIDs)); % Minimum Specified (by us) Current limit of the operating range of the battery
else
    cvMinCurr = mean(battProp.cvStopCurr(cellIDs)); %10% of 1C
    maxBattCurrLimit = mean(battProp.maxCurr(cellIDs)); % Maximum Specified (by us) Current limit of the operating range of the battery
    minBattCurrLimit = mean(battProp.minCurr(cellIDs)); % Minimum Specified (by us) Current limit of the operating range of the battery
end
battSurfTempLimit = mean(battProp.maxSurfTemp(cellIDs)); % Maximum Surface limit of the battery
battCoreTempLimit = mean(battProp.maxCoreTemp(cellIDs)); % Maximum Core limit of the battery
errorCode = 0;


% verbose = 0; % How often to display (stream to screen). 1 = constantly, 0 = once a while
if ~exist("verbose", 'var')
    verbose = 1;
end

dotCounter = 0;
tElasped = 0;

if caller == "gui"
    readPeriod = testSettings.readPeriod;
else
    readPeriod = 0.25; %0.25; % Number of seconds to wait before reading values from devices
end

plotFigs = false;

% Track SOC FailSafe (if it goes above or below rated SOC
if ~exist("trackSOCFS", 'var')
    trackSOCFS = true;
end

battTS = timeseries();
battData = struct;

testStatus = "running";
