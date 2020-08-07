function y = P06_OutputFcn_HW(x, u, p1, p2, p3, p4)
%P06_OUTPUTFCN_HW Computes the outputs of a Li-ion Predictive Model
%   Unlike a State space equation, this function takes a less analytical
%   approach to compute y given x(t+1) and some other parameters
%
%   Inputs:
%       x   = current states to be converted to outputs
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



% dt          = p1;   % Algorithm sample time
predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x) and OUTPUTS (y) presented as a struts

NUMCELLS = cellData.NUMCELLS;
% cap = cellData.CAP; % Capacity of all cells

xIND = indices.x;
yIND = indices.y;

ny = indices.ny; % Number of outputs

y = zeros(ny, 1);

SOC = x(xIND.SOC, 1);
V1 = x(xIND.V1, 1);
V2 = x(xIND.V2, 1);
Tc = x(xIND.Tc, 1);
Ts = x(xIND.Ts, 1);
T_avg = (Tc + Ts)/2;

% Pass the unchanged states through
y(yIND.SOC, 1) = SOC;
y(yIND.Ts, 1) = Ts;

balCurr = u(1:NUMCELLS, 1);
psuCurr = u(end, 1);

% curr = balCurr + psuCurr; 

% % Compute Actual Current Through cells
logicalInd = balCurr(:) >= 0;
balActual_dchrg = predMdl.Curr.T_dchrg * (balCurr(:) .* (logicalInd));
balActual_chrg = predMdl.Curr.T_chrg * (balCurr(:) .* (~logicalInd));
balActual = balActual_chrg + balActual_dchrg;
curr = psuCurr + balActual(:); % Actual Current in each cell


% Useful for when model has changing Rs wrt temp and SOC
% Z = lookupRS_OCV(predMdl.lookupTbl, SOC(:), T_avg(:), curr(:)); % "(:)" forces vector to column vector
% OCV = reshape(Z.OCV, size(SOC));
% rs = reshape(Z.Rs, size(SOC));

OCV = interp1qr(predMdl.Volt.SOC, predMdl.Volt.OCV, SOC(:));
Vt = OCV(:) - V1 - V2 -(curr .* predMdl.Volt.Rs); 

y(yIND.Volt, 1) = Vt(:);

end

