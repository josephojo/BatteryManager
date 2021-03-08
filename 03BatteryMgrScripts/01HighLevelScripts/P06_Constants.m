
NUMCELLS = numCells_Ser;

sampleTime = 5; testSettings.sampleTime = sampleTime;% 0.5; % Sample time [s]
readPeriod = 0.25; testSettings.readPeriod = readPeriod;% How often to read from plant
prevTime = 0; prevElapsed = 0;

USE_PARALLEL = true;
% USE_PARALLEL = false;
testSettings.USE_PARALLEL = USE_PARALLEL;


MIN_BAL_CURR = -2; %[-0.5, -0.5, -0.5, -0.5]';
MAX_BAL_CURR = 2; % [0.5, 0.5, 0.5, 0.5]';
MAX_CELL_CURR = batteryParam.maxCurr(battID); % /numCells_Par; % This should be for each single/parallel cells connected in series
MIN_CELL_CURR = batteryParam.minCurr(battID); % /numCells_Par;
MAX_CHRG_VOLT = batteryParam.chargedVolt(battID)/numCells_Ser;
MIN_DCHRG_VOLT = batteryParam.dischargedVolt(battID)/numCells_Ser;
MAX_CELL_VOLT = batteryParam.maxVolt(battID)/numCells_Ser;
MIN_CELL_VOLT = batteryParam.minVolt(battID)/numCells_Ser;
MAX_BAL_SOC = 0.60; % Maximum SOC that that balancers will be active and the mpc will optimize for balance currents
MIN_BAL_SOC = 0.05; % Minimum SOC that that balancers will be active and the mpc will optimize for balance currents
BAL_SOC = [MIN_BAL_SOC];% Balancing is only allowed to startup again at these SOCs
ALLOWABLE_SOCDEV = 0.002; % The allowable SOC deviation 
RATED_CAP = batteryParam.ratedCapacity(battID);
MIN_PSUCURR_4_HIVOLTBAL = -(RATED_CAP/30); % The largest amount of current to use while balancing


% battery capacity
CAP = batteryParam.cellCap{battID};  % battery capacity

cellData.NUMCELLS = NUMCELLS;
cellData.MAX_BAL_CURR = MAX_BAL_CURR;
cellData.MAX_BAL_CURR = MAX_BAL_CURR;
cellData.MIN_BAL_CURR = MIN_BAL_CURR;
cellData.MAX_CELL_CURR = MAX_CELL_CURR;
cellData.MAX_CHRG_VOLT = MAX_CHRG_VOLT;
cellData.MIN_DCHRG_VOLT = MIN_DCHRG_VOLT;
cellData.MAX_BAL_SOC = MAX_BAL_SOC;
cellData.MIN_BAL_SOC = MIN_BAL_SOC;
cellData.CAP = CAP;
cellData.ALLOWABLE_SOCDEV = ALLOWABLE_SOCDEV;


xSOC    = 1;
xV1     = 2;
xV2     = 3;
xTc     = 4;
xTs     = 5;
xCurr   = 6;

yVolt   = 1;
yTs     = 2;
yANPOT    = 3;

xIND.SOC    = 1+(xSOC-1)*NUMCELLS:xSOC*NUMCELLS;
xIND.V1     = 1+(xV1-1)*NUMCELLS:xV1*NUMCELLS;
xIND.V2     = 1+(xV2-1)*NUMCELLS:xV2*NUMCELLS;
xIND.Tc     = 1+(xTc-1)*NUMCELLS:xTc*NUMCELLS;
xIND.Ts     = 1+(xTs-1)*NUMCELLS:xTs*NUMCELLS;
xIND.Curr   = 1+(xCurr-1)*NUMCELLS:xCurr*NUMCELLS; % Passing the curr back in to the state to prevent using current in output function

yIND.Volt   = 1+(yVolt-1)*NUMCELLS:yVolt*NUMCELLS;
yIND.Ts     = 1+(yTs-1)*NUMCELLS:yTs*NUMCELLS;
yIND.ANPOT    = 1+(yANPOT-1)*NUMCELLS:yANPOT*NUMCELLS;

indices.x = xIND;
indices.y = yIND;


TARGET_SOC = 0.9; % 0.85; %0.98;
testSettings.TARGET_SOC = TARGET_SOC;

ANPOT_Target = 0.002;  % Anode Potential has to be greater than 0 to ensure no lithium deposition
ANPOT_Target_BAL = 0.01;  % Anode Potential has to be greater than 0 to ensure no lithium deposition

% Balance Efficiencies
chrgEff = 0.774; 
dischrgEff = 0.651; 

numStatesPerCell = length(fields(xIND));
numOutputsPerCell = length(fields(yIND));


nx = numStatesPerCell*NUMCELLS; % Number of states
ny = numOutputsPerCell*NUMCELLS; % Number of outputs
nu = NUMCELLS + 1; % Number of inputs. In this case, current for each cell + PSU current

indices.nx = nx;
indices.ny = ny;
indices.nu = nu;

PH = 5;  % Prediction horizon
CH = 2;  % Control horizon