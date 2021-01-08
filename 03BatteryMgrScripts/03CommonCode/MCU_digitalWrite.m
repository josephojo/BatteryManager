function [mcuObj,mcuHandle] = MCU_digitalWrite(mcuObj, mcuHandle, pins, states, invertedSig)
%MCU_DIGITALWRITE Writes a digital through an MCU to an aux device
%   Switches one or more digital pins on the MCU in question.
%   If the number of [states](true/false) equal that of the [pins] i.e if the user
%   wants each pin to have a different state, then the program can
%   implement it as long as each pin has a corresponding state.
%   [invertedSig] (true/false) invertes the state if the required.
%   Inversion means the signal reciepient requires 0 for ON and 1 for OFF.

% if invertedSig is not included in arguments
if nargin <= 4
    invertedSig = false(size(pins));
end

for i = 1:length(pins)
    if length(pins) == length(states)
        j = i;
    else
        j = 1;
    end
    
    if invertedSig(i) == false
        mcuObj.AddRequestS(mcuHandle,'LJ_ioPUT_DIGITAL_BIT', pins(i), double(states(j)), 0, 0);
    else
        mcuObj.AddRequestS(mcuHandle,'LJ_ioPUT_DIGITAL_BIT', pins(i), double(~states(j)), 0, 0);
    end
end

mcuObj.GoOne(mcuHandle);

end

