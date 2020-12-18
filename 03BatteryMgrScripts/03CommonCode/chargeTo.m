function testData = chargeTo(targSOC, chargeCurr, varargin)
%chargeTo Charges to the specified SOC based on the charge current
%specified
%%   This function runs dischargeToSOC. It is left in here for backward
%   compatibility.

testData = chargeToSOC(targSOC, chargeCurr, varargin);
end