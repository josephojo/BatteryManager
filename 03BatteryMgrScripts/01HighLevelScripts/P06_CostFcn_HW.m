function J = P06_CostFcn_HW(X, U, e, data, p1, p2, p3, p4)
%P06_COSTFCN_HW Calculates the Costs for the P06 HCFC/Bal Algorithm
%   This function calculates the cost that is used in the optimization of 
%   the health-conscious fast charging and active balancing algorithm (Project 06)

% Parameters (p#)
% dt          = p1;   % Algorithm sample time
predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x)and OUTPUTS (y) presented as a struts

NUMCELLS = cellData.NUMCELLS;
% allowableSOCDev = cellData.ALLOWABLE_SOCDEV;
% cap = cellData.CAP; % Capacity of all cells

xIND = indices.x;

socDevType = predMdl.SOC.socDevType;
devMat = predMdl.SOC.devMat;

p = data.PredictionHorizon;
%     for i=1:p+1
%         Y(i,:) = P06_OutputFcn_HW(X(i,:)',U(i,:)',p1, p2)';
%     end

% %%%%%%%%%%% Cell Current Calculation %%%%%%%%%%%
%{
balCurr = U(2:p+1,1:NUMCELLS);
psuCurr =  U(2:p+1, end);

% curr = psuCurr + balCurr;

% % Compute Actual Current Through cells
logicalInd = balCurr' >= 0;
balActual_dchrg = predMdl.Curr.T_dchrg * (balCurr' .* (logicalInd));
balActual_chrg = predMdl.Curr.T_chrg * (balCurr' .* (~logicalInd));
balActual = balActual_chrg + balActual_dchrg;
curr = psuCurr + (predMdl.Curr.balWeight*balActual'); % Actual Current in each cell
%}

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% References for each objective
% ---------------------------------------------------------------------
ref = data.References;


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get the Objective vectors in pred horizon (2:p+1)
% ( SOC, SOCdev, Chg Time, Temp. Rate, Anode Potential)
% --------------------------------------------------------------------------------

% %%%%%%%%%%%%%%%%%%%%%%%%%%%  Charge SOC  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
chrgSOC = X(2:p+1, xIND.SOC);
socTracking = ref(:, 1:NUMCELLS) - chrgSOC;


% %%%%%%%%%%%%%%%%%%%%%%%%%%%  SOC Deviation  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
if strcmpi(socDevType, "devMat")
    socDev = devMat * chrgSOC';
else
    socDev = mean(chrgSOC, 2) - chrgSOC;
end

% %%%%%%%%%%%%%%%%%%  Charge time calculation  %%%%%%%%%%%%%%%%%%%%%%%%
%{
    % Chg Time = (Change in SOC between each timestep x capacity) / current
    futureSOCs = chrgSOC; % SOCs only in the pred horizon
    currentSOCs = X(1:p, xIND.SOC); % SOCs in the current time and pred horizon minus furthest SOC
%     chrgTime = zeros(size(futureSOCs)); % Initialize chag time to zeros
    futureCurr = curr;
    idx = futureCurr <= MIN_CHRG_CURR; % Make members of U a small value if it is zero
    curr = futureCurr .* (~idx) + MIN_CHRG_CURR .*idx;
    chrgTime = ( (futureSOCs - currentSOCs) .* cap' * 3600 )./ abs(curr); % Sum each column (i.e. each value in pred horizon)
%}

% %%%%%%%%%%%%%%%%%%  Temp Rise Rate calculation  %%%%%%%%%%%%%%%%%%%%%
%{
    % Using Surf Temp since it is what we can measure
    futureTs = X(2:p+1, xIND.Ts); % Ts representing future single timestep SOC
    currentTs = X(1:p, xIND.Ts);
%     tempRate = zeros(size(futureTs)); % Initialize temp. rate to zeros
    tempRate = futureTs - currentTs; % Sum each column (i.e. each value in pred horizon)
%}

% %%%%%%%%%%%%%%%%%%%%%%%  Anode Potential   %%%%%%%%%%%%%%%%%%%%%%%%%%
%{
    curr = X(2:p+1, xIND.Curr);
    anPotMdl = predMdl.ANPOT;
    ANPOTind = curr < 0;
    interpCurr = curr .* (ANPOTind);
    AnodePot = qinterp2(-anPotMdl.Curr, anPotMdl.SOC, anPotMdl.ANPOT,...
                    interpCurr, X(2:p+1, xIND.SOC));
    
%     AnodePot = lookup2D(-anPotMdl.Curr, anPotMdl.SOC, anPotMdl.ANPOT,...
%                     interpCurr, X(2:p+1, xIND.SOC));
%     AnodePot = reshape(AnodePot, size(curr));
%}
% AnodePot = X(2:p+1, xIND.ANPOT);


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Objective Function Weights (0, 1, 5, 20 etc))
% ---------------------------------------------------------------------
A = 100; % 5; % SOC Tracking
% If SOC is past the set balance SOC range, then don't let the SOC dev
% affect the cost function.
A_dev =200 * predMdl.Curr.balWeight; % 10


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Scaling Factors for each objective
% ---------------------------------------------------------------------
% scale_soc = 0.004; 
% scale_socDev = 0.07;
scale_soc = 1; 
scale_socDev = 1;

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Cost Function
% ---------------------------------------------------------------------
fastChargingCost = sum( ( (A/scale_soc) .* (socTracking) ) .^2);
socBalancingCost = sum( ( (A_dev/scale_socDev) .* (0 - socDev) ) .^2);
J = sum([...
    fastChargingCost,  ... % avgSOC) ) .^2),  ... %
    socBalancingCost,  ...
    ... % sum( ( (D/scale_ANPOT) .* (ref(:, 1*NUMCELLS+1:2*NUMCELLS) - AnodePot) ) .^2),  ...
    ... % sum( ( (C./scale_TR) .* (ref(:, 2*NUMCELLS+1:3*NUMCELLS) - tempRate) ) .^2),  ...
    ... % sum( ( (E/1) .* (0 - U(2:p+1,1:NUMCELLS)) ) .^2),  ...
    e.^2, ...
    ], 'all');

end

