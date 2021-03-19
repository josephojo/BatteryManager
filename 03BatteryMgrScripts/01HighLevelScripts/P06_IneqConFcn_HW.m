function cineq = P06_IneqConFcn_HW(X, U, e, data, p1, p2, p3, p4)
%P06_INEQCONFUN_HW Calculates the inequality constraints for the P06 HCFC/Bal Algorithm
%   This function calculates the inequality constraints that are used in the
%   optimization of the health-conscious fast charging and active balancing
%   algorithm (Project 06)

% Parameters (p#)
% dt          = p1;   % Algorithm sample time
predMdl     = p2;   % Predictive Battery Model Structure
cellData    = p3;   % Constant Cell Data
indices     = p4;   % Indices for the STATES (x)and OUTPUTS (y) presented as a struts

% NUMCELLS = cellData.NUMCELLS;
xIND = indices.x;
yIND = indices.y;

p = data.PredictionHorizon;

if predMdl.Curr.balWeight == 1
%     if max(X(1, xIND.SOC)) < 0.4
%         MAX_CHRG_VOLT = cellData.MAX_CHRG_VOLT - 0.25;
%     else
%         MAX_CHRG_VOLT = cellData.MAX_CHRG_VOLT - 0.40;
%     end
    MAX_CHRG_VOLT = cellData.MAX_CHRG_VOLT - 0.20; % 0.35; % 
else
    MAX_CHRG_VOLT = cellData.MAX_CHRG_VOLT - 0.01;
end

horizonInd = 2:p+1;
Y = zeros(p, indices.ny);
for i = 1:p+1
    Y(i,:) = P06_OutputFcn_HW(X(i,:)',U(i,:)',p1, p2, p3, p4)';
end
cineq0 = (Y(horizonInd, yIND.Volt) - MAX_CHRG_VOLT')';
cineq = cineq0(:);

end

