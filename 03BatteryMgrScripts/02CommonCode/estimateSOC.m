function soc = estimateSOC(curr, delta_t, prevsoc, Q)
%ESTIMATESOC Estimate the value of SOC based on coulomb counting
%   Based on the coulomb counting equation found in [Wen-Yeau Chang - "The
%   State of charge estimating methods for battery. A review."]
%   Soc(t) = SOC(t-1) + (I(t)/Qn)delta_t
%   
%   The function takes in 3 or more arguments: Current, time since last
%   current measurement, the previous SOC estimate (initial SOC for First
%   call, and optionally: the total charge [Q] of the battery in use.
    
    t1 = tic;

    delta_t = delta_t + toc(t1); % Here to make sure the timer is as correct as possible
    soc = prevsoc + (curr*delta_t)./-Q; % negative here is to allow increase SOC when current is negative (charging)
end