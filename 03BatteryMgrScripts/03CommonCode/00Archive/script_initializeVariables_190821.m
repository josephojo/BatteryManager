tic;

% If for some reason the variable does not exist.
if ~exist("cellID", 'var')
    cellID = upper(input('Please enter the cellID for the battery being tested: ','s')); % ID in Cell Part Number (e.g BAT11-FEP-AA1)
end

cellID = upper(cellID);

% Gets the full path for the current file
currFilePath = mfilename('fullpath');
% Seperates the path directory and the filename
[path, filename, ~] = fileparts(currFilePath);
% goes to path
cd(path + "\..\..")

% Retreives current directory
path = pwd;
dataLocation = path + "\01CommonDataForBattery\";

%Load PrevSOC
% load(dataLocation + "prevSOC.mat");
load(dataLocation + "007BatteryParam.mat", 'batteryParam');

if max(ismember(batteryParam.Row, cellID)) == 0
   disp(newline + "Parameters for '" + cellID + "' do not exist in storage.");
   response = input('Would you like to create them now? (y/n) : ', 's');
   if strcmpi(response, "y")
       disp("Here we go ...");
       
   elseif strcmpi(response, "n")
       errorCode = 2;
       error(newline + "Cannot Proceed without those parameters." + newline +...
           "Quitting program now.");
%        return;
   else
       disp(newline + newline + "Invalid Entry. Please try again." + newline)
       response = input('Would you like to create them now? (y/n) : ', 's');
       if strcmpi(response, "y")
        disp("Here we go ...");
       else
           errorCode = 2;
           error(newline + "Rerun the program to try again." + newline +...
           "Quitting  now."  + newline);
%            return;
       end
   end
   
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
   maxCoreTemp = input('Minimum Core Temp Limit (°C)?: ');
   ratedCapacity = input('Rated Capacity from Manufacturer (Ah)?: ');
   
   Tnew = table(chemistry,chargedVolt,dischargedVolt,capacity,soc,...
       cvStopCurr, maxVolt,minVolt,maxCurr,minCurr,maxSurfTemp,...
       maxCoreTemp,ratedCapacity, 'RowNames', {cellID});
   
   batteryParam = [batteryParam;Tnew];
   save(dataLocation + "007BatteryParam.mat", 'batteryParam');
end

coulombs = batteryParam.capacity(cellID)*3600; % Convert Ah to coulombs
prevSOC = batteryParam.soc(cellID);

AhCap = 0;

% Initializes the Constants used in Data Generation
psuData = zeros(1, 2); % Container for storing PSU Data
eloadData = zeros(1, 2); % Container for storing Eload Data
thermoData = zeros(1, 2); % Container for storing TC Data
ain3 = 0; ain2 = 0; ain1 = 0; ain0 = 0; adcAvgCounter = 0; % Variables used for labjack(LJ) averaging
adcAvgCount = 10; %20;

% % 0 = Don't Use Temp from Arduino. Only from 16Ch module
% % 1 = Only use Hot Junction (Actual TC - Surf Temp), Ambient From 16Ch
% Mod
% useArd4Temp = 1;
if ~exist("useArd4Temp", 'var')
    useArd4Temp = 0;
end


% Creates an container that will be used to record previous time measurements
timerPrev = zeros(5, 1); 
% timerPrev(1): For Total Elapsed Time 
% timerPrev(2): For Profile period
% timerPrev(3): For Measurement Period
% timerPrev(4): For BattSOC Estimation
% timerPrev(5): For Progress dot (Dot that shows while code runs)

highVoltLimit = batteryParam.chargedVolt(cellID); % Fully charged voltage
lowVoltLimit  = batteryParam.dischargedVolt(cellID); % Fully Discharged Voltage
cvMinCurr = batteryParam.cvStopCurr(cellID); %10% of 1C

chargeReq = 0; % Charge Request - true/1 = Charging, false/0 = discharging
chargeVolt = highVoltLimit+0.01; %6;
circuitImp = 0.134;

battState = ""; % State of the battery ("charging", "discharging or idle")
battVolt = 0; % Measured Voltage of the battery
battCurr = 0; % Current from either PSU or ELOAD depending on the battState
battSOC = prevSOC; % Estimated SOC of the battery is stored here
maxBattVoltLimit = batteryParam.maxVolt(cellID); % Maximum Voltage limit of the operating range of the battery
minBattVoltLimit = batteryParam.minVolt(cellID); % Minimum Voltage limit of the operating range of the battery
maxBattCurrLimit = batteryParam.maxCurr(cellID); % Maximum Specified (by us) Current limit of the operating range of the battery
minBattCurrLimit = batteryParam.minCurr(cellID); % Minimum Specified (by us) Current limit of the operating range of the battery
battSurfTempLimit = batteryParam.maxSurfTemp(cellID); % Maximum Surface limit of the battery
errorCode = 0;

verbose = 0; % How often to display (stream to screen). 1 = constantly, 0 = once a while
if ~exist("verbose", 'var')
    verbose = 1;
end

dotCounter = 0;
tElasped = 0;

readPeriod = 0.5; %0.25; % Number of seconds to wait before reading values from devices

plotFigs = false;

if ~exist("trackSOCFS", 'var')
    trackSOCFS = true;
end

battTS = timeseries();
