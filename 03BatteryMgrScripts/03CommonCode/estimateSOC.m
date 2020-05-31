function soc = estimateSOC(curr, delta_t, prevsoc, varargin)
%ESTIMATESOC Estimate the value of SOC based on coulomb counting
%   Based on the coulomb counting equation found in [Wen-Yeau Chang - "The
%   State of charge estimating methods for battery. A review."]
%   Soc(t) = SOC(t-1) + (I(t)/Qn)delta_t
%   
%   The function takes in 3 or more arguments: Current, time since last
%   current measurement, the previous SOC estimate (initial SOC for First
%   call, and optionally: the total charge [Q] of the battery in use.
    
    t1 = tic;
    if(nargin > 3)
        for i = 1:length(varargin)
            if varargin{i} == 'Q' || varargin{i} == 'q' || strcmp(varargin{i}, "total charge")
                Q = varargin{i+1:end};
                break;
            end
        end
    else
        Q = 9000; %Based on the maximum capacity of 2.5Ah ANR26650 used in exp
    end
    t2 = toc(t1);

    delta_t = delta_t + t2; % Here to make sure the timer is as correct as possible
    soc = prevsoc + (curr*delta_t)./Q;
end