function y = lookup1D(X, Y, x)
%LOOKUP1D Searches for y in a precise 1D Lookup table given x.
% Usage:
%   z = lookup2D(X,Y,x)         - X and Y MUST be 1D vectors
%                               - x can be a scaler or a vector.
% Usage restrictions
%   X and Y must be monotonically and evenly increasing
%

% check to see if X, Y and Z are the same size
if size(X, 1) ~= size(Y, 1)
    error("The dimensional size of X do not match that of size of Y.")
end

xVec = X; 

[~, ind_x] = min( abs( x(:)' - xVec(:) ) ); 

y = Y(ind_x);


end

