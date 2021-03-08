function [A, Bmv]  = P06_BattStateJac_HW(x, u, p1, p2, p3, p4)
%P06_BATTSTATEJAC_HW Calculates the State Jacobians for the P06 HCFC/Bal Algorithm
%   This function calculates the jacobians for the state function
%   that are used in the optimization of the health-conscious fast charging 
%   and active balancing algorithm (Project 06)


% Parameters (p#)
% dt          = p1;   % Algorithm sample time
% predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x) and OUTPUTS (y) presented as a struts

NUMCELLS = cellData.NUMCELLS;

xIND = indices.x;

nx = indices.nx; % Number of states
nmv = indices.nu; % Number of inputs. In this case, current for each cell + PSU current

parameters = {p1, p2, p3, p4};

x0 = x;
u0 = u;

f0 = P06_BattStateFcn_HW(x0, u0, parameters{:});

%% Get sizes
Jx = zeros(nx, nx);
Jmv = zeros(nx, nmv);
% Perturb each variable by a fraction (dv) of its current absolute value.
dv = 1e-6;

%% Get Jx - How do the states change when each state is changed?

xa = abs(x0);
xa(xa < 1) = 1;  % Prevents perturbation from approaching eps.

% SOC - How does changing the SOC change the states (SOC, V1, and V2. Tc or
% Ts don't change)


Jx(xIND.SOC, xIND.SOC) = eye(NUMCELLS); % Jacobian for the SOCs since they don't change when perturbed

%{
dx = dv*xa(xIND.SOC);
x0(xIND.SOC) = x0(xIND.SOC) + dx;  % Perturb all states
f = P06_BattStateFcn_HW(x0, u0, parameters{:});
x0(xIND.SOC) = x0(xIND.SOC) - dx;  % Undo pertubation
df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
Jx(xIND.SOC, xIND.SOC) = diag(df(xIND.SOC, 1));
% Jx(xIND.V1, xIND.SOC) = diag(df(xIND.V1, 1));
% Jx(xIND.V2, xIND.SOC) = diag(df(xIND.V2, 1));
% Jx(xIND.Tc, xIND.SOC) = diag(df(xIND.Tc, 1));
% Jx(xIND.Ts, xIND.SOC) = diag(df(xIND.Ts, 1));
%}


% RC Voltages - V1 and V2. 
%   (Because V1 and V2 don't change wrt each other,
%    their jacobians can be computed in one go.)

%{
dx = dv*xa([xIND.V1, xIND.V2]);
x0([xIND.V1, xIND.V2]) = x0([xIND.V1, xIND.V2]) + dx; % Perturb only V1 and V2
[v1, v2] = getRC_Volt(battMdl, dt, -abs(uc), x0(xIND.SOC)', x0_Tavg, x0(xIND.V1)', x0(xIND.V2)');
x0([xIND.V1, xIND.V2]) = x0([xIND.V1, xIND.V2]) - dx; % Undo pertubation

f = [v1(:); v2(:)];
df = (f - f0([xIND.V1, xIND.V2]))./dx;
Jx = replaceDiag(Jx, df, [xIND.V1, xIND.V2], 0);
%}

% V1
dx = dv*xa(xIND.V1);
x0(xIND.V1) = x0(xIND.V1) + dx;  % Perturb all states
f = P06_BattStateFcn_HW(x0, u0, parameters{:});
x0(xIND.V1) = x0(xIND.V1) - dx;  % Undo pertubation
df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
Jx(xIND.SOC, xIND.V1) = diag(df(xIND.SOC, 1));
Jx(xIND.V1, xIND.V1) = diag(df(xIND.V1, 1));
Jx(xIND.V2, xIND.V1) = diag(df(xIND.V2, 1));
Jx(xIND.Tc, xIND.V1) = diag(df(xIND.Tc, 1));
Jx(xIND.Ts, xIND.V1) = diag(df(xIND.Ts, 1));

% V2
dx = dv*xa(xIND.V2);
x0(xIND.V2) = x0(xIND.V2) + dx;  % Perturb all states
f = P06_BattStateFcn_HW(x0, u0, parameters{:});
x0(xIND.V2) = x0(xIND.V2) - dx;  % Undo pertubation
df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
Jx(xIND.SOC, xIND.V2) = diag(df(xIND.SOC, 1));
Jx(xIND.V1, xIND.V2) = diag(df(xIND.V1, 1));
Jx(xIND.V2, xIND.V2) = diag(df(xIND.V2, 1));
Jx(xIND.Tc, xIND.V2) = diag(df(xIND.Tc, 1));
Jx(xIND.Ts, xIND.V2) = diag(df(xIND.Ts, 1));


% Tc and Ts Temperatures.
% How does V1, V2, Tc and Ts change wrt Tc and Ts respectively? soc does
% not change wrt Tc or Ts (at least not in this algorithm)

%{
dx_tc = dv*xa(xIND.Tc);
x0(xIND.Tc) = x0(xIND.Tc) + dx_tc; % Perturb only V1 and V2
f_tc = calcTemp (uc, [x0(xIND.Tc)'; x0(xIND.Ts)'], dt, Tf);
x0_Tavg = mean([x0(xIND.Tc), x0(xIND.Ts)], 2)';
[v1, v2] = getRC_Volt(battMdl, dt, -abs(uc), x0(xIND.SOC)', x0_Tavg, x0(xIND.V1)', x0(xIND.V2)');
f_tc = [v1(:); v2(:); f_tc(1, :)'; f_tc(2, :)'];
x0(xIND.Tc) = x0(xIND.Tc) - dx_tc; % Undo pertubation

dx_ts = dv*xa(xIND.Ts);
x0(xIND.Ts) = x0(xIND.Ts) + dx_ts; % Perturb only V1 and V2
f_ts = calcTemp (uc, [x0(xIND.Tc)'; x0(xIND.Ts)'], dt, Tf);
x0_Tavg = mean([x0(xIND.Tc), x0(xIND.Ts)], 2)';
[v1, v2] = getRC_Volt(battMdl, dt, -abs(uc), x0(xIND.SOC)', x0_Tavg, x0(xIND.V1)', x0(xIND.V2)');
f_ts = [v1(:); v2(:); f_ts(1, :)'; f_ts(2, :)'];
x0(xIND.Ts) = x0(xIND.Ts) - dx_ts; % Undo pertubation

ix = [xIND.V1, xIND.V2, xIND.Tc, xIND.Ts];

df_tc = (f_tc - f0(ix)) ./ repmat(dx_tc(:), (nx/NUMCELLS)-1, 1); % (f-f0)./dx
df_ts = (f_ts - f0(ix)) ./ repmat(dx_ts(:), (nx/NUMCELLS)-1, 1); % (f-f0)./dx

soc_change = zeros(size(xIND.SOC'));
df_tc = [soc_change; df_tc];
df_ts = [soc_change; df_ts];

df_tc = [diag(df_tc(xIND.SOC)); diag(df_tc(xIND.V1)); diag(df_tc(xIND.V2));...
            diag(df_tc(xIND.Tc)); diag(df_tc(xIND.Ts))];
df_ts = [diag(df_ts(xIND.SOC)); diag(df_ts(xIND.V1)); diag(df_ts(xIND.V2));...
            diag(df_ts(xIND.Tc)); diag(df_ts(xIND.Ts))];

Jx(: , xIND.Tc) = df_tc;
Jx(: , xIND.Ts) = df_ts;
%}
% % TC
% dx = dv*xa(xIND.Tc);
% x0(xIND.Tc) = x0(xIND.Tc) + dx;  % Perturb all states
% f = P06_BattStateFcn_HW(x0, u0, parameters{:});
% x0(xIND.Tc) = x0(xIND.Tc) - dx;  % Undo pertubation
% df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
% Jx(xIND.SOC, xIND.Tc) = diag(df(xIND.SOC, 1));
% Jx(xIND.V1, xIND.Tc) = diag(df(xIND.V1, 1));
% Jx(xIND.V2, xIND.Tc) = diag(df(xIND.V2, 1));
% Jx(xIND.Tc, xIND.Tc) = diag(df(xIND.Tc, 1));
% Jx(xIND.Ts, xIND.Tc) = diag(df(xIND.Ts, 1));

Jx(xIND.Tc, xIND.Tc) = 0.991240769925956 * eye(NUMCELLS);
Jx(xIND.Ts, xIND.Tc) = 0.966062163308749 * eye(NUMCELLS);

% % TS
% dx = dv*xa(xIND.Ts);
% x0(xIND.Ts) = x0(xIND.Ts) + dx;  % Perturb all states
% f = P06_BattStateFcn_HW(x0, u0, parameters{:});
% x0(xIND.Ts) = x0(xIND.Ts) - dx;  % Undo pertubation
% df = (f - f0)./ repmat(dx, (nx/NUMCELLS), 1);
% Jx(xIND.SOC, xIND.Ts) = diag(df(xIND.SOC, 1));
% Jx(xIND.V1, xIND.Ts) = diag(df(xIND.V1, 1));
% Jx(xIND.V2, xIND.Ts) = diag(df(xIND.V2, 1));
% Jx(xIND.Tc, xIND.Ts) = diag(df(xIND.Tc, 1));
% Jx(xIND.Ts, xIND.Ts) = diag(df(xIND.Ts, 1));

% Jx(xIND.Tc, xIND.Ts) = 0.967016120252270 * eye(NUMCELLS);
% Jx(xIND.Ts, xIND.Ts) = 0.003840263642064 * eye(NUMCELLS);

Jx(xIND.Tc, xIND.Ts) = 0.003936465759280 * eye(NUMCELLS);
Jx(xIND.Ts, xIND.Ts) = 0.003836475313207 * eye(NUMCELLS);


%% Get Jmv - How do the states change when each manipulated variable is changed?
%{
ua = abs(u0); % (1:NUMCELLS)
ua(ua < 1) = 1;
du = dv*ua(1:NUMCELLS);
u0(1:NUMCELLS) = u0(1:NUMCELLS) + du;
f = P06_BattStateFcn_HW(x0, u0, parameters{:});
u0(1:NUMCELLS) = u0(1:NUMCELLS) - du;
df = (f - f0) ./ repmat(du, (nx/NUMCELLS), 1);

du = dv*ua(end);
u0(end) = u0(end) + du;
f = P06_BattStateFcn_HW(x0, u0, parameters{:});
u0(end) = u0(end) - du;
df2 = (f - f0) ./ du;


Jmv(xIND.SOC, 1:NUMCELLS) = diag(df(xIND.SOC));
Jmv(xIND.V1, 1:NUMCELLS) = diag(df(xIND.V1));
Jmv(xIND.V2, 1:NUMCELLS) = diag(df(xIND.V2));
Jmv(xIND.Tc, 1:NUMCELLS) = diag(df(xIND.Tc));
Jmv(xIND.Ts, 1:NUMCELLS) = diag(df(xIND.Ts));

Jmv = [Jmv, df2];
%}

ua = abs(u0);
ua(ua < 1) = 1;
for j = 1:nmv
    k = j; % imv(j);
    du = dv*ua(k);
    u0(k) = u0(k) + du;
    f = P06_BattStateFcn_HW(x0, u0, parameters{:});
    u0(k) = u0(k) - du;
    df = (f - f0)/du;
    Jmv(:,j) = df;
end

A = Jx;
Bmv = Jmv;

end

