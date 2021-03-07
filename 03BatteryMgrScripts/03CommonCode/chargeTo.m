function [testData, metadata, testSettings] = chargeTo(targSOC, chargeCurr, varargin)
%chargeTo Charges to the specified SOC based on the charge current
%specified
%%   This function runs chargeToSOC. It is left in here for backward
%   compatibility.

[testData, metadata, testSettings] = chargeToSOC(targSOC, chargeCurr, varargin);
end