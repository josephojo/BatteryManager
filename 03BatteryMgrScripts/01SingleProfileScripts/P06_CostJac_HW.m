function [G, Gmv, Ge] = P06_CostJac_HW(X, U, e, data, p1, p2, p3, p4)
%P06_COSTJAC_HW Calculates the Cost Jacobians for the P06 HCFC/Bal Algorithm
%   This function calculates the jacobian for the cost function (P06_CostFcn)
%   that is used in the optimization of the health-conscious fast charging 
%   and active balancing algorithm (Project 06)

% Parameters (p#)
% dt          = p1;   % Algorithm sample time
% predMdl     = p2;   % Predictive Battery Model Structure
% cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x)and OUTPUTS (y) presented as a struts

% NUMCELLS = cellData.NUMCELLS;
xIND = indices.x;

parameters = {p1, p2, p3, p4};
p = data.PredictionHorizon;


%% Get sizes
x0 = X;
u0 = U;
e0 = e;
nx = size(x0,2);
imv = data.MVIndex;
nmv = length(imv);
Jx  = zeros(nx, p);
Jmv = zeros(nmv, p);
% Perturb each variable by a fraction (dv) of its current absolute value.
dv = 1e-6;

f0 = P06_CostFcn_HW(x0, u0, e0, data, parameters{:});

%% Get Jx
xa = abs(x0);
xa(xa < 1) = 1;  % Prevents perturbation from approaching eps.
for i = 1:p
    for j = xIND.SOC % Only calculating wrt soc here since it is the only one used in the cost func % 1:nx
        ix = i + 1; % Starts iterating from the second state
        dx = dv*xa(j);
        x0(ix,j) = x0(ix,j) + dx;
        
        f = P06_CostFcn_HW(x0, u0, e0, data, parameters{:});
        
        x0(ix,j) = x0(ix,j) - dx;
        df = (f - f0)/dx;
        Jx(j, i) = df;
    end
end

%% Get Ju - How does the cost change wrt to each input
ua = abs(u0);
ua(ua < 1) = 1;
for i = 1:p-1
    for j = 1:nmv
        k = imv(j);
        du = dv*ua(k);
        u0(i,k) = u0(i,k) + du;
        f = P06_CostFcn_HW(x0, u0, e0, data, parameters{:});
        u0(i,k) = u0(i,k) - du;
        df = (f - f0)/du;
        Jmv(j,i) = df;
    end
end
% special handling of p to account for mv(p+1,:) = mv(p,:)
for j = 1:nmv
    k = imv(j);
    du = dv*ua(k);
    u0(p,k) = u0(p,k) + du;
    u0(p+1,k) = u0(p+1,k) + du;
    f = P06_CostFcn_HW(x0, u0, e0, data, parameters{:});
    u0(p,k) = u0(p,k) - du;
    u0(p+1,k) = u0(p+1,k) - du;
    df = (f - f0)/du;
    Jmv(j,p) = df;
end

%% Get Je
% Use central difference in this case as large default ECR magnifies
% error in forward difference formula
ea = max(1e-6, abs(e0)); 
de = ea*dv;
f1 = P06_CostFcn_HW(x0, u0, e0+de, data, parameters{:});
f2 = P06_CostFcn_HW(x0, u0, e0-de, data, parameters{:});
Je = (f1 - f2)/(2*de);

G = Jx';
Gmv = Jmv';
Ge = Je;

end

