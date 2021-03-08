function wait(targTime)
%wait Pauses the program from running
%   Uses the tic, toc matlab properties to halt the program for the
%   targTime in seconds (s)

if targTime > 10
    disp("Waiting for " + targTime + "s");
end

waitTimer = tic;

waitTicker = 0;

while (waitTicker < targTime)
    waitTicker = toc(waitTimer);
end


if targTime > 10
    disp("Done Waiting for " + targTime + "s");
end

end