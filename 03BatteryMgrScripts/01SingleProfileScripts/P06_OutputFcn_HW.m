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
soc_indx = 1+(xIND.SOC-1)*NUMCELLS:xIND.SOC*NUMCELLS;
v1_ind = 1+(xIND.V1-1)*NUMCELLS:xIND.V1*NUMCELLS;
v2_ind = 1+(xIND.V2-1)*NUMCELLS:xIND.V2*NUMCELLS;

% Useful for when model has changing Rs wrt temp and SOC
% tc_ind = 1+(xIND.Tc-1)*NUMCELLS:xIND.Tc*NUMCELLS;
% ts_indx = 1+(xIND.Ts-1)*NUMCELLS:xIND.Ts*NUMCELLS;

yIND = indices.y;
soc_indy = 1+(yIND.SOC-1)*NUMCELLS:yIND.SOC*NUMCELLS;
volt_ind = 1+(yIND.Volt-1)*NUMCELLS:yIND.Volt*NUMCELLS;
ts_indy = 1+(yIND.Ts-1)*NUMCELLS:yIND.Ts*NUMCELLS;

numOutputsPerCell = length(fields(yIND));
ny = numOutputsPerCell*NUMCELLS; % Number of outputs

y = zeros(ny, 1);

SOC = x(soc_indx, 1);
V1 = x(v1_ind, 1);
V2 = x(v2_ind, 1);

% Useful for when model has changing Rs wrt temp and SOC
% Tc = x(tc_ind, 1);
% Ts = x(ts_indx, 1);
% T_avg = (Tc + Ts)/2;

% Pass the unchanged states through
y(soc_indy, 1) = SOC;
y(ts_indy, 1) = Ts;

% Compute Voltage
% Get Actual Current Through cells
balCurr = u(1:NUMCELLS, 1);
psuCurr = u(end, 1);
balActual_dchrg = predMdl.Curr.T_dchrg * (balCurr(:) .* (balCurr(:) > 0));
balActual_chrg = predMdl.Curr.T_chrg * (balCurr(:) .* (balCurr(:) < 0));
balActual = balActual_chrg + balActual_dchrg;
curr = psuCurr + balActual(:); % Actual Current in each cell
% curr = psuCurr + balCurr;


% Useful for when model has changing Rs wrt temp and SOC
% Z = lookupRS_OCV(predMdl.lookupTbl, SOC(:), T_avg(:), curr(:)); % "(:)" forces vector to column vector
% OCV = reshape(Z.OCV, size(SOC));
% rs = reshape(Z.Rs, size(SOC));

OCV = lookup1D(predMdl.Volt.SOC, predMdl.Volt.OCV, SOC(:));
Vt = OCV - V1 - V2 -(curr .* predMdl.Volt.Rs); 

y(volt_ind, 1) = Vt(:);

end

