function newDiagMat = replaceDiag(oldDiagMat, vector, indRangeV, offset)
%REPLACEDIAG Replaces the elements in the diag of a matrix
%
%oldDiagMat     The old square matrix to be modified
%vector         The vector with values to replace
%indRangeV      A vector containing the indices of the old matrix to
%               replace i.e. the idex of elements of the specific diagonal
%               to replace with new vector. E.g. 1:2 for both elements of
%               either the top/bottom offset diagonals of a 3x3 matrix.
%               Likewise, 2 if only the second element of the top/bottom
%               offset diagonal of the same 3x3 matrix is to be replaced.
%offset         The offset of the old square matrix to replace. A negative
%               value is below the main diagonal, while positive it above

if length(vector) ~= length(indRangeV)
    error("The index range vector must have the same length as the vector" + ...
        " to be inserted. The index range vector must contain the indices for each element of the vector");
end
vector = vector(:);

ind = ismember(1:length(diag(oldDiagMat, offset)), indRangeV);
ind = ind(:);

newDiag = double(ind); x = 1;
for i = indRangeV
    newDiag(i) = vector(x);
    x = x+1;
end

newDiagMat = (oldDiagMat .* ~diag(ind, offset)) + diag(newDiag, offset);

end