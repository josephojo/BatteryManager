function newTS = appendBattTS2TS(oldTS, TS2merge)
%appendBattTS2TS Appends a timeseries to an older and lengthier timeseries data.
%   This function continues the timestamps based on the ending of the old
%   timeseries and adds the rest of the data, granted the number of columns
%   on the timeseries to be merged match that on the oldTS

if length(TS2merge.data(1, :)) == length(oldTS.data(1, :))
    TS2merge = delsample(TS2merge,'Index',1);
    TS2merge2 = timeseries(TS2merge.data, TS2merge.time+oldTS.time(end));
    newTS = append(oldTS, TS2merge2);
else
    warning("Column size for both TS do not match. Returning the old timeseries instead.");
    newTS = oldTS;
end

end

