ekf = extendedKalmanFilter(@P06_BattStateFcn_HW, @P06_OutputFcn_HW, xk);
%{
% Get observation noise covariance matrix
dt = readPeriod;
iters = 500;
plantObvs = cell(iters, 1);
u = [0 0 0 0 0]';  u_bal = u(1:NUMCELLS); u_psu = u(end);
t = tic;
for i=1:iters
    script_queryData;
    script_failSafes; %Run FailSafe Checks
    script_checkGUICmd; % Check to see if there are any commands from GUI
    % if limits are reached, break loop
    if errorCode == 1 || strcmpi(testStatus, "stop")
        script_idle;
    end
    
    y_Ts = thermoData(2:end);
    plantObvs{i} = [ testData.cellVolt(end, :) ;  y_Ts(:)' ];
    wait(0.25);
end
toc(t)

plantObvs_V_Ts = cell2mat(cellfun(@(X)[X(1, :), X(2, :)], plantObvs, 'UniformOutput', false));
obsvCov = cov(plantObvs_V_Ts - mean(plantObvs_V_Ts, 1));
zCov = diag(obsvCov);
%}

zCov = [4.24849699398227e-09;3.08216432866192e-09;4.52248496993420e-09;1.86977955912091e-09;...
    0.000118797595190384; 0.00142701402805615; 0; 0.00124933867735475; ...
    0.0001; 0.0001; 0.0001; 0.0001 ]; % 1e-10; 1e-10; 1e-10; 1e-10];
% zCov = repmat([0.08, 0.01], NUMCELLS, 1); % Measurement Noise covariance (assuming no cross correlation) % [0.02, 0.08, 0.01] 
ekf.MeasurementNoise = diag(zCov(:));
pCov = repmat([0.002, 0.005, 0.007, 0.05, 0.05, 0], NUMCELLS, 1);
ekf.ProcessNoise = diag(pCov(:));
% ekf.ProcessNoise = 0.07;