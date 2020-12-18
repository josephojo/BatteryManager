function [newStruct, mergeSuccess] = appendTestDataStruts(OldStruct, Struct2Merge)
%appendBattTS2TS Appends a timeseries to an older and lengthier timeseries data.
%   This function continues the timestamps based on the ending of the old
%   timeseries and adds the rest of the data, granted the number of columns
%   on the timeseries to be merged match that on the oldTS

newStruct = OldStruct;

if isequal(fieldnames(OldStruct), fieldnames(Struct2Merge)) ...
        %         && length(oldstruct.cellVolt(1, :)) == length(Struct2merge.cellVolt(1, :))
    Struct2Merge.time = Struct2Merge.time + OldStruct.time(end);
    fieldNames = fieldnames(OldStruct);
    for i = 1:length(fieldNames)
        newStruct.(fieldNames{i}) = [OldStruct.(fieldNames{i}); Struct2Merge.(fieldNames{i})];
    end
    
    mergeSuccess = true;
else
    warning("The fieldnames in the Old and New Test Data are different." +...
        newline + "Returning the old timeseries instead.");
    mergeSuccess = false;
end

end

