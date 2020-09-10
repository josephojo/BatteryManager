function cellCurr = combineCurrents(psuCurr, balCurr, predMdl)
%combineCurrents Combines Power Supply and Balancer Currents to cell Currents
    % Compute Actual Current Through cells
    logicalInd = balCurr(:) >= 0; % Indices where balancer currents are discharging
    balActual_dchrg = predMdl.Curr.T_dchrg * (balCurr(:) .* (logicalInd));
    balActual_chrg = predMdl.Curr.T_chrg * (balCurr(:) .* (~logicalInd));
    balActual = balActual_chrg + balActual_dchrg;
    cellCurr = psuCurr + (predMdl.Curr.balWeight * balActual(:)); % Actual Current in each cell
end
