function [soc, ahUsed, ahRemain] = newSOCAfterProfile(prevSOC,currProfile)
%NEWSOCAFTERPROFILE Calculates the new SOC after a certain timeseries profile

currProfile.Time = currProfile.Time + currProfile.Time(2);
profileLen = length(currProfile.Time);
counter = 1;
tic; % Start Timer
prevT = toc;
coulombCount = 7668; % (2.13/2.5) * 9000
while counter <= profileLen
    if (toc - currProfile.Time(counter)) >= (currProfile.Time(2)-currProfile.Time(1))
        deltaT = toc - prevT;
        soc = estimateSOC(currProfile.Data(counter), deltaT, prevSOC, 'Q', coulombCount); % Leave right after battCurr update since it is used in SOC estimation
        prevT = toc; % Update Current time to previous
        prevSOC = soc; % Update the current SOC as prev
        counter = counter + 1; 
    end
end %End of While Loop

ahRemain = (soc/1) * 2.13;
ahUsed = 2.13 - ahRemain;
end % End of Function

