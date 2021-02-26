function testData = dischargeToEmpty(dischargeCurr, varargin)
%dischargeToEmpty Discharges to empty based on the current provided.
%   This function runs dischargeToSOC. It is left in here for backward
%   compatibility.
%
testData = dischargeToSOC(0, dischargeCurr, varargin);

end