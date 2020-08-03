function xk1 = P06_BattStateFcn_HW(x, u, p1, p2, p3, p4)
%P06_BATTSTATEFCN_HW Computes the next states of a Li-ion Predictive Model
%   Unlike a State space equation, this function takes a less analytical
%   approach to compute x(t+1) given x(t) and some other parameters
%
%   Inputs:
%       x   = previous states to be converted to current states
%               x includes: [SOC(1:N); Vrc1(1:N); Vrc2(1:N); Tc(1:N);
%                               Ts(1:N)] for all cells.
%               N is the number of cells.
%
%       u   = current states to be converted to outputs
%               u includes: [u(cell 1); u(cell 2); ... u(cell N); u(PSU)]
%               u < 0 is charging, u > 0 is discharging
%
%       p1  = Controller sample time
%       p2  = Predictive Battery Model Structure
%       p3  = Cell Data Constants
%       p4  = Indices for the STATES (x) and OUTPUTS (y)

dt          = p1;   % Algorithm sample time
predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x) and OUTPUTS (y) presented as a struts

NUMCELLS = cellData.NUMCELLS;
% cap = cellData.CAP; % Capacity of all cells

xIND = indices.x;

balCurr = u(1:NUMCELLS, 1);
psuCurr = u(end, 1);

% curr = psuCurr + balCurr;

% Compute Actual Current Through cells
logicalInd = balCurr(:) >= 0;
balActual_dchrg = predMdl.Curr.T_dchrg * (balCurr(:) .* (logicalInd));
balActual_chrg = predMdl.Curr.T_chrg * (balCurr(:) .* (~logicalInd));
balActual = balActual_chrg + balActual_dchrg;
curr = psuCurr + balActual(:); % Actual Current in each cell

Tf = predMdl.Temp.Tf;

prevSOC = x(xIND.SOC, 1);
prevTemp = [x(xIND.Tc, 1), x(xIND.Ts, 1)]';
prevV1 =  x(xIND.V1, 1);
prevV2 =  x(xIND.V2, 1);

%% SOC State Update
% Change in SOC as a result of series pack charging/discharging

SOC = predMdl.SOC.A * prevSOC + (predMdl.SOC.B1 .* (curr(:) * dt));

% soc_pack_chg = (predMdl.SOC.B1 * (u(end, 1) * dt));
%
% % Change in SOC as a result of balancing
% soc_bal_chg = (predMdl.SOC.B2 * (u(1:NUMCELLS, 1) * dt));
%
% % Total SOC for current step
% SOC = predMdl.SOC.A * prevSOC + (soc_bal_chg + soc_pack_chg);

%% RC Voltage Updates
% [V1, V2] = getRC_Volt(predMdl, dt, curr(:), SOC(:), mean(prevTemp)', ...
%    prevV1, prevV2); % Current should be a negative row vector for each cell using this voltage model

prevVRc = [prevV1(:)'; prevV2(:)'];
prevVRc = prevVRc(:);
in_U = repmat(curr(:)', 2, 1);
in_U = in_U(:); % Force vector to column
Vrc = predMdl.Volt.A * prevVRc + predMdl.Volt.B .* in_U;
Vrc = reshape(Vrc, 2, NUMCELLS);
V1 = Vrc(1, :); % Voltage drop across in RC pair 1
V2 = Vrc(2, :); % Voltage drop across in RC pair 2 


%% Temperature Update
Temp = predMdl.Temp.A * prevTemp + ...
    predMdl.Temp.B * [(curr(:)'.^2); repmat(Tf, 1, NUMCELLS)];

%% Tie it off
xk1 = [SOC; V1(:); V2(:); Temp(1, :)'; Temp(2, :)'];

end

function [Vrc1, Vrc2] =  getRC_Volt(mdl, dt, curr, SOC, prevTemp, prevV1, prevV2)
%getRC_Volt Calculates the next state of the RC voltages

NUMCELLS = length(curr);

RC = lookupRCs(mdl.lookupTbl, SOC, prevTemp, curr(:)');

% Creates a row of repeating A Matrices
A11 = -1./(RC.R1 .* RC.C1);
A12 = zeros(1, length(A11));
A1 = [A11; A12];
A1 = A1(:)';

A21 = -1./(RC.R2 .* RC.C2);
A22 = zeros(1, length(A21));
A2 = [A22; A21];
A2 = A2(:)';

A_cont = [A1; A2];

% Creates a row of repeating vectors cols i.e[x1, x2, ...; y1, y2;...]
B_cont = [1./RC.C1 ; 1./RC.C2];

A_tempo = repmat(A_cont, NUMCELLS, 1) .* eye(NUMCELLS * 2);
A = expm(A_tempo * dt);

B = A_tempo\(A - eye(size(A))) * B_cont(:);

x = [prevV1(:)'; prevV2(:)'];
x = x(:);

u = repmat(curr(:)', 2, 1);
u = u(:); % Force vector to column

Vrc = A*x + B.*u;
Vrc = reshape(Vrc, 2, NUMCELLS);

Vrc1 = Vrc(1, :); % Voltage drop across in RC pair 1
Vrc2 = Vrc(2, :); % Voltage drop across in RC pair 2

end