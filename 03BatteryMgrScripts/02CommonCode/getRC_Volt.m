function [Vrc1, Vrc2] =  getRC_Volt(mdl, dt, curr, SOC, prevTemp, prevV1, prevV2)
%getRC_Volt Calculates the next state of the RC voltages

NUMCELLS = length(curr);

RC = lookupRCs(mdl.lookupTbl, SOC, prevTemp, curr(:)');

% Creates a row of repeating A Matrices
A11 = -1./(RC.R1 .* RC.C1);
A12 = zeros(1, length(A11));
A1 = [A11; A12];
A1 = A1(:)';

A21 = -1./(RC.R2 .* RC.C2);
A22 = zeros(1, length(A21));
A2 = [A22; A21];
A2 = A2(:)';

A_cont = [A1; A2];

% Creates a row of repeating vectors cols i.e[x1, x2, ...; y1, y2;...]
B_cont = [1./RC.C1 ; 1./RC.C2];

A_tempo = repmat(A_cont, NUMCELLS, 1) .* eye(NUMCELLS * 2);

% t = tic;
% B_tempo = B_cont(:); % repmat(B_cont, NUMCELLS, 1);
% sys_SS = ss( A_tempo, B_tempo, zeros(size(A_tempo)), zeros(size(B_tempo)) );
% sds_SS = c2d(sys_SS, dt);
% 
% mdl_A = sds_SS.A;
% mdl_B = sds_SS.B;
% toc(t)

% t = tic;
A = expm(A_tempo * dt);

B = A_tempo\(A - eye(size(A))) * B_cont(:);

% toc(t)

x = [prevV1(:)'; prevV2(:)'];
x = x(:);

u = repmat(curr(:)', 2, 1);
u = u(:); % Force vector to column

Vrc = A*x + B.*u;
Vrc = reshape(Vrc, 2, NUMCELLS);

Vrc1 = Vrc(1, :); % Voltage drop across in RC pair 1
Vrc2 = Vrc(2, :); % Voltage drop across in RC pair 2

end