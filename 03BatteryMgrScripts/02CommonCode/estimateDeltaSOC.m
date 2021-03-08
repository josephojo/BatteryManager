function Delta_SOC = estimateDeltaSOC(curr, delta_t, Q, cellConfig)
%ESTIMATEDELTASOC Estimate the change in SOC based on coulomb counting
%   Based on the coulomb counting equation found in [Wen-Yeau Chang - "The
%   State of charge estimating methods for battery. A review."]
%   Delta_SOC = (I(t)/Qn)delta_t
%
%   To get the SOC for the current timestep add the SOc of the PREVIOUS
%   timestep to the output of this function. i.e:
%    Soc(t) = SOC(t-1) + Delta_SOC;
%   
%   The function takes in 3 or more arguments: Current, time since last
%   current measurement, the previous SOC estimate (initial SOC for First
%   call, and optionally: the total charge [Q] of the battery in use.
    
    t1 = tic;
    
    if nargin < 5
       cellConfig = "single"; 
    end
    
    numCells = length(curr);
    if numCells > 1 && strcmpi(cellConfig, "series") % For Calculating SOC for a 
        Qx = diag(Q); % Maximum Capacities
        T = repmat(1/numCells, numCells) - eye(numCells); % Component for individual Active Balance Cell SOC [2]
        B2 = (Qx\T); 
        
        delta_t = delta_t + toc(t1); % Here to make sure the timer is as correct as possible
        Delta_SOC = (B2 * (curr(:) * delta_t));

    else
        delta_t = delta_t + toc(t1); % Here to make sure the timer is as correct as possible
        Delta_SOC = (curr*delta_t)./Q;
    end
    
    
end