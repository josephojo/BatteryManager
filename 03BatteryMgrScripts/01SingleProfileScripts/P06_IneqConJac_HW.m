function [Geq, Gmv, Ge] = P06_IneqConJac_HW(X, U, e, data, p1, p2, p3, p4)
%P06_INEQCONJAC_HW Calculates the inequality constraint jacobians for the P06_HCFC/Bal Algorithm
%   This function calculates the jacobians for the inequality constraints 
%   that are used in the optimization of the health-conscious fast charging 
%   and active balancing algorithm (Project 06)

% Parameters (p#)
% dt          = p1;   % Algorithm sample time
% predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x)and OUTPUTS (y) presented as a struts

NUMCELLS = cellData.NUMCELLS;
xIND = indices.x;

parameters = {p1, p2, p3, p4};
p = data.PredictionHorizon;

horizonInd = 2:p+1; % Update regularly from "P06_IneqConFcn_HW"

x0 = X;
u0 = U;

%% Get sizes
nx = size(x0,2);
imv = data.MVIndex;
nmv = length(imv);
f0 = P06_IneqConFcn_HW(x0, u0, e, data, parameters{:});
nf = length(f0);    
Jx = zeros(nf, nx, p);
Jmv = zeros(nf, nmv, p);
Je = zeros(nf, 1);
% Perturb each variable by a fraction (dv) of its current absolute value.
dv = 1e-6;

%% Get Jx
xa = abs(x0);
xa(xa < 1) = 1;  % Prevents perturbation from approaching eps.
C = zeros(nf, nx);
for j = xIND.Curr %1:nx
    dx = dv*xa(horizonInd(1), j);
    x0(horizonInd(1), j) = x0(horizonInd(1), j) + dx;
    f = P06_IneqConFcn_HW(x0, U, e, data, parameters{:});
    x0(horizonInd(1), j) = x0(horizonInd(1), j) - dx;
    C(:,j) = (f - f0)/dx;
end

for ix = 1:length(horizonInd) 
    % Avoid using ix=1 ("how does the ineq change wrt to the previous state changing")
    % since it doesn't change the ineqs
    if horizonInd(ix)==1, continue; end 
    
    %{
    % SOC
    dx = dv*xa(xIND.SOC);
    x0(ix, xIND.SOC) = x0(ix, xIND.SOC) + dx;  % Perturb all states
    f = P06_IneqConFcn_HW(x0, U, e, data, parameters{:});
    x0(ix, xIND.SOC) = x0(ix, xIND.SOC) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, xIND.SOC, ix-1) = dff;
    
    % V1
    dx = dv*xa(xIND.V1);
    x0(ix, xIND.V1) = x0(ix, xIND.V1) + dx;  % Perturb all states
    f = P06_IneqConFcn_HW(x0, U, e, data, parameters{:});
    x0(ix, xIND.V1) = x0(ix, xIND.V1) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, xIND.V1, ix-1) = dff;
    
    % V2
    dx = dv*xa(xIND.V2);
    x0(ix, xIND.V2) = x0(ix, xIND.V2) + dx;  % Perturb all states
    f = P06_IneqConFcn_HW(x0, U, e, data, parameters{:});
    x0(ix, xIND.V2) = x0(ix, xIND.V2) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, xIND.V2, ix-1) = dff;
    
    % Tc
    dx = dv*xa(xIND.Tc);
    x0(ix, xIND.Tc) = x0(ix, xIND.Tc) + dx;  % Perturb all states
    f = P06_IneqConFcn_HW(x0, U, e, data, parameters{:});
    x0(ix, xIND.Tc) = x0(ix, xIND.Tc) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, xIND.Tc, ix-1) = dff;
    
    % Ts
    dx = dv*xa(xIND.Ts);
    x0(ix, xIND.Ts) = x0(ix, xIND.Ts) + dx;  % Perturb all states
    f = P06_IneqConFcn_HW(x0, U, e, data, parameters{:});
    x0(ix, xIND.Ts) = x0(ix, xIND.Ts) - dx;  % Undo pertubation
    dxx = repmat(dx, length(f0)/NUMCELLS, 1);
    df = (f - f0)./ dxx(:);
    dff = zeros(length(f0), NUMCELLS);
    for cellNum = 1:NUMCELLS
        ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
        dff(ind, cellNum) = df(ind);
    end
    Jx(:, xIND.Ts, ix-1) = dff;
    %}
    
    Jx(1+(ix-1)*NUMCELLS:ix*NUMCELLS, xIND.V1, ix) = -1.00 * eye(NUMCELLS);
    Jx(1+(ix-1)*NUMCELLS:ix*NUMCELLS, xIND.V2, ix) = -1.00 * eye(NUMCELLS);
    Jx(1+(ix-1)*NUMCELLS:ix*NUMCELLS, xIND.Curr, ix) = C(1:NUMCELLS, xIND.Curr);% -0.01 * eye(NUMCELLS);
end

%% Get Ju
%{
ua = abs(u0);
ua(ua < 1) = 1;
k = 1:NUMCELLS;


for i = horizonInd(horizonInd <= p-1) 
        du = dv*ua(i, k);
        u0(i,k) = u0(i,k) + du;
        f = P06_IneqConFcn_HW(X, u0, e, data, parameters{:});
        u0(i,k) = u0(i,k) - du;
        duu = repmat(du, length(f0)/NUMCELLS, 1);
        df = (f - f0)./ duu(:);
        dff = zeros(length(f0), NUMCELLS);
        for cellNum = 1:NUMCELLS
            ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
            dff(ind, cellNum) = df(ind);
        end
        Jmv(:, k, i) = dff;
        Jmv(:, nmv, i) = df;
end
if max((horizonInd == p) | (horizonInd == p+1))
        du = dv*ua(k);
        u0(p,k) = u0(p,k) + du;
        u0(p+1,k) = u0(p+1,k) + du;
        f = P06_IneqConFcn_HW(X, u0, e, data, parameters{:});
        u0(p,k) = u0(p,k) - du;
        u0(p+1,k) = u0(p+1,k) - du;
        duu = repmat(du, length(f0)/NUMCELLS, 1);
        df = (f - f0)./ duu(:);
        dff = zeros(length(f0), NUMCELLS);
        for cellNum = 1:NUMCELLS
            ind = 1+(cellNum-1)*length(horizonInd) : cellNum*length(horizonInd);
            dff(ind, cellNum) = df(ind);
        end
        Jmv(:, k, p) = dff;
        Jmv(:, nmv, p) = df;
end
%}
ua = abs(u0);
ua(ua < 1) = 1;

i = horizonInd(1);
for j = 1:nmv
    k = imv(j);
    du = dv*ua(k);
    u0(i,k) = u0(i,k) + du;
    f = P06_IneqConFcn_HW(X, u0, e, data, parameters{:});
    u0(i,k) = u0(i,k) - du;
    df = (f - f0)/du;
    Jmv(:,j,i) = df;
end

%{
% matx = Jmv( 1+(horizonInd(1)-1)*NUMCELLS : horizonInd(1)*NUMCELLS , :, i );
% for x = 2:nmv-1
%     Jmv( 1+(horizonInd(x)-1)*NUMCELLS : horizonInd(x)*NUMCELLS , :, x ) = matx;
% end
% 
% Jmv( 1+(horizonInd(p)-1)*NUMCELLS : horizonInd(p+1)*NUMCELLS , :, p ) = [matx; matx];
%}

matx = Jmv( 1 : NUMCELLS , :, i );
for x = 2:length(horizonInd)-2
%     Jmv( 1+(horizonInd(x)-1)*NUMCELLS : horizonInd(x)*NUMCELLS , :, x ) = matx;
    i = i+1;
    Jmv( 1+(x-1)*NUMCELLS : x*NUMCELLS , :, i ) = matx;
end

Jmv( 1+((length(horizonInd)-1)-1)*NUMCELLS : length(horizonInd)*NUMCELLS , :, p ) = [matx; matx];

%{
% for j = 1:nmv
%     k = imv(j);
%     du = dv*ua(k);
%     u0(p,k) = u0(p,k) + du;
%     u0(p+1,k) = u0(p+1,k) + du;
%     f = P06_IneqConFcn_HW(X, u0, e, data, parameters{:});
%     u0(p,k) = u0(p,k) - du;
%     u0(p+1,k) = u0(p+1,k) - du;
%     df = (f - f0)/du;
%     Jmv(:,j,p) = df;
% end
%}


% From Matlab's ineq function
%{
for i = 1:p-1
    for j = 1:nmv
        k = imv(j);
        du = dv*ua(k);
        u0(i,k) = u0(i,k) + du;
        f = P06_IneqConFcn_HW(X, u0, e, data, parameters{:});
        u0(i,k) = u0(i,k) - du;
        df = (f - f0)/du;
%         for ii = 1:nf
%             Jmv(ii,j,i) = df(ii);
%         end
        Jmv(:,j,i) = df;
    end
end
% special handling of p to account for mv(p+1,:) = mv(p,:)
for j = 1:nmv
    k = imv(j);
    du = dv*ua(k);
    u0(p,k) = u0(p,k) + du;
    u0(p+1,k) = u0(p+1,k) + du;
    f = P06_IneqConFcn_HW(X, u0, e, data, parameters{:});
    u0(p,k) = u0(p,k) - du;
    u0(p+1,k) = u0(p+1,k) - du;
    df = (f - f0)/du;
%     for ii = 1:nf
%         Jmv(ii,j,p) = df(ii);
%     end
    Jmv(:,j,p) = df;
end
%}

%% Outputs
Geq = permute(Jx, [3,2,1]);
Gmv = permute(Jmv, [3,2,1]);
Ge = Je(:);

end

