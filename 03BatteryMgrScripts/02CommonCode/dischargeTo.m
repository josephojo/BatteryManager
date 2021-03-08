function [testData, metadata, testSettings] = dischargeTo(targSOC, dischargeCurr, varargin)
%dischargeTo Discharges to the specified SOC based on the current provided.
%   This function runs dischargeToSOC. It is left in here for backward
%   compatibility.
%
[testData, metadata, testSettings] = dischargeToSOC(targSOC, dischargeCurr, varargin);

end