function [testData, metadata, testSettings] = chargeToFull(chargeCurr, varargin)
%chargeToFull Charges to full using CC-CV based on the charge current specified

[testData, metadata, testSettings] = chargeToSOC(1, chargeCurr, varargin);
end