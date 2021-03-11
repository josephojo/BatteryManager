
% Fast Charging SOC Trajectory Planner
idealTimeLeft = abs(((TARGET_SOC - xk(xIND.SOC, 1)) .* CAP(:) * 3600)./ abs(MIN_CELL_CURR));
SOC_Traj = xk(xIND.SOC) + (sampleTime./(idealTimeLeft+sampleTime)).*(TARGET_SOC - xk(xIND.SOC, 1));

references = [SOC_Traj(:)', zeros(1, NUMCELLS), zeros(1, NUMCELLS)];

% Testing: Changing the u for power supply to the measured value
u(end) = testData.packCurr(end, 1);

% Combine the PSU and BalCurr based on the balancer transformation
% matrix
combCurr = combineCurrents(testData.packCurr(end, 1), optBalCurr, predMdl);
                
                
% Using the equivalent current from balance commands and psu.
% measured current here instead does not work while predicting
% model states (EKF).
ANPOTind = reshape(combCurr(:)', [], 1) < 0;
interpCurr = reshape(combCurr(:)', [], 1) .* (ANPOTind);
ANPOT = qinterp2(-predMdl.ANPOT.Curr, predMdl.ANPOT.SOC, predMdl.ANPOT.ANPOT,...
    interpCurr , reshape(testData.cellSOC(end, :), [], 1) );

% Update Observation (Volt, Ts)
y_Ts = thermoData(2:end);
% If at least 1 sample time worth of data has been recorded,
% start to average out the voltage measured during that period
% to emulate what a constant balancing current would have done
if length(testData.time) > round(sampleTime / readPeriod)
    y_Volt = mean(...
        testData.cellVolt(end-round(sampleTime/readPeriod):end, :)...
        , 1);
else % if one sample Time worth of data is not available, just use last recorded voltage
    y_Volt = testData.cellVolt(end, :);
end
y = [ y_Volt(:)',  y_Ts(:)', ANPOT(:)'];

% Kalman filter plant measurements to get the hidden model states
% Predict Step
[PredictedState,PredictedStateCovariance] = predict(ekf, u, options.Parameters{:});

% Correct Step
[CorrectedState,CorrectedStateCovariance] = correct(ekf, y(:), u, options.Parameters{:});

xk = CorrectedState';
xk = xk(:);
debugData.xk(end+1, :) = xk(:)';

if ONLY_CHRG_FLAG == false
    % Disable Balancing if SOC is past range
    % or if SOC deviation if less than threshold.
    % MPC won't optimize for Balance currents past this range
    socCheck = testData.cellSOC(end, :);
    if (max(socCheck > MAX_BAL_SOC) ...
            || min(socCheck < MIN_BAL_SOC)) ...
            || abs( max(socCheck) - min(socCheck) ) <= ALLOWABLE_SOCDEV
        
        BalanceCellsFlag = false;
        predMdl.Curr.balWeight = 0;
        p2 = predMdl;
        options.Parameters = {p1, p2, p3, p4};
        u = [zeros(NUMCELLS, 1); u(end)];
        mpcObj.MV(NUMCELLS + 1).Min = DfltMinPSUVal;
        
        % Allow Anode potential to reach zero since it is not
        % balancing (spiking)
        for i = 1:NUMCELLS
            mpcObj.OV(i + (yANPOT-1) * NUMCELLS).Min =  ANPOT_Target;
        end
        
        % ONLY Start up balncing again if within the allowed Balancing
        % range and if the deviation among cells is greater than
        % the allowable deviation at specific SOC levels
    elseif max(socCheck < MAX_BAL_SOC) ...
            && min(socCheck > MIN_BAL_SOC) ...
            && abs( max(socCheck) - min(socCheck)) >= ALLOWABLE_SOCDEV
        
        if max(max(round(socCheck, 2)) == BAL_SOC) % And if the cell with the highest SOC has reached a BAL_SOC
            % If any of the cells are close to max voltage,
            % manually reduce the PSU current limit.
            % This is really not ideal, the mpc should be able to
            % figure this out itself
            if max(testData.cellVolt(end, :) > 3.85) && max(socCheck > MAX_BAL_SOC)
                mpcObj.MV(NUMCELLS + 1).Min = MIN_PSUCURR_4_HIVOLTBAL; % + max(testData.cellSOC(end, :));
            else
                mpcObj.MV(NUMCELLS + 1).Min = DfltMinPSUVal;
            end
            BalanceCellsFlag = true;
            predMdl.Curr.balWeight = 1;
            p2 = predMdl;
            options.Parameters = {p1, p2, p3, p4};
            u = zeros(nu, 1); % Reset u as an input otherwise it doesn't solve
            % Allow Anode potential to reach zero since it is not
            % balancing (spiking)
            for i = 1:NUMCELLS
                mpcObj.OV(i + (yANPOT-1) * NUMCELLS).Min =  ANPOT_Target_BAL;
            end
        end
    end
end

debugData.u(end+1, :) = u(:)';
