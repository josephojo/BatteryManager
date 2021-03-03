function C = P06_OutputJac_HW(x, u, p1, p2, p3, p4)
%P06_OUTPUTJAC_HW Calculates the Output Jacobians for the P06 HCFC/Bal Algorithm
%   This function calculates the jacobians for the output function
%   that are used in the optimization of the health-conscious fast charging 
%   and active balancing algorithm (Project 06)

% Parameters (p#)
% dt          = p1;   % Algorithm sample time
% predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x) and OUTPUTS (y) presented as a struts

NUMCELLS = cellData.NUMCELLS;

xIND = indices.x;
yIND = indices.y;

nx = indices.nx; % Number of states
ny = indices.ny; % Number of states
C = zeros(ny, nx);

C(yIND.Volt, xIND.V1)   = -1.00 * eye(NUMCELLS);
C(yIND.Volt, xIND.V2)   = -1.00 * eye(NUMCELLS);
C(yIND.Ts, xIND.Ts)     =  1.00 * eye(NUMCELLS);

parameters = {p1, p2, p3, p4};

x0 = x;
u0 = u;

f0 = P06_OutputFcn_HW(x0, u0, parameters{:});
vec = [xIND.SOC, xIND.Curr];

% Perturb each variable by a fraction (dv) of its current absolute value.
dv = 1e-6;
%% Get Jx
xa = abs(x0);
xa(xa < 1) = 1;  % Prevents perturbation from approaching eps.
for j = vec %1:nx
    dx = dv*xa(j);
    x0(j) = x0(j) + dx;
    f = P06_OutputFcn_HW(x0,u0,parameters{:});
    x0(j) = x0(j) - dx;
    C(:,j) = (f - f0)/dx;
end

end

