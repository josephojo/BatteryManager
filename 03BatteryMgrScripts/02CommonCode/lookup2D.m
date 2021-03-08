function z = lookup2D(X, Y, Z, x, y)
%LOOKUP2D Searches for z in a precise 2D Lookup table given x and y.
% Usage:
%   z = lookup2D(X,Y,Z,x,y)     - X and Y should be "plaid" 
%                                   (e.g., generated with meshgrid).
%                               - X, Y and Z must be 2D matrices. 
%                               - x and y can be scalers or vectors.
% Usage restrictions
%   X(:,n) and Y(m,:) must be monotonically and evenly increasing
%   e.g.,  [X,Y] = meshgrid(-5:5, 0:0.025:1);
%
% Example:
%   To create a 2D lookup table use the meshgrid function.
%   e.g
%       xVec = 0:0.1:2.3*6;
%       yVec = linspace(0, 1, length(xVec));
%       [X,Y] = meshgrid(xVec, yVec); % Create mesh grid of xVec and yVec
%       Z = (300/13.8*X .* Y.^2);

% check to see if X, Y and Z are the same size
if size(X, 1) ~= size(Z, 1) || size(Y, 2) ~= size(Z, 2)
    error("The dimensional size of X or Y do not match that of size of Z." ...
        + newline + "Size X = " +  num2str(size(X)) + "Size Y = " + num2str(size(Y)));
end

xVec = X(1, :); % unique(X, 'Rows');
yVec = Y(:, 1); % unique(Y', 'Rows')';

% % Find location of x
% locX = xVec >= x & xVec <= x;
% numVals = length(locX(locX == 1));
% 
% if numVals == 0
%     % Fill z with NaNs
%     z = NaN*ones(size(x));
%     warning("x does not exist in lookup table");
%     return;
% end
% 
% % Find location of y
% locY = yVec >= y & yVec <= y;
% numVals = length(locY(locY == 1));
% 
% if numVals == 0
%     % Fill z with NaNs
%     z = NaN*ones(size(x));
%     warning("y does not exist in lookup table");
%     return;
% end

[~, ind_x] = min( abs( x(:)' - xVec(:) ) ); % (locX) ) );
[~, ind_y] = min( abs( y(:)' - yVec(:) ) ); % (locY) ) );


z = diag(Z(ind_x, ind_y));


end

