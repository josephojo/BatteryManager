try
    %% Voltage Model 
    load(dataLocation + "008OCV_" + battID + ".mat", 'OCV', 'SOC'); 
    
    C1 = 47.827;
    C2 = 8.5956e+05;
    R1 = 0.0022329;
    R2 = 0.046958;
    Rs = 0.05867;
    
    C1 = C1 * ones(1, NUMCELLS);
    C2 = C2 * ones(1, NUMCELLS);
    R1 = R1 * ones(1, NUMCELLS);
    R2 = R2 * ones(1, NUMCELLS);
    Rs = Rs * ones(1, NUMCELLS);
    
    A11 = -1./(R1 .* C1);
    A12 = zeros(1, length(A11));
    A1 = [A11; A12];
    A1 = A1(:)';
    A22 = -1./(R2 .* C2);
    A21 = zeros(1, length(A22));
    A2 = [A21; A22];
    A2 = A2(:)';
    AV_cont = [A1; A2];
    BV_cont = [1./C1 ; 1./C2];
    
    A_tempo = repmat(AV_cont, NUMCELLS, 1) .* eye(NUMCELLS * 2);
    A = expm(A_tempo * sampleTime);
    B = A_tempo\(A - eye(size(A))) * BV_cont(:);
    
    voltMdl.A_cont = AV_cont;
    voltMdl.B_cont = BV_cont;
    voltMdl.A = A;
    voltMdl.B = B;
    voltMdl.R1 = R1;
    voltMdl.R2 = R2;
    voltMdl.C1 = C1;
    voltMdl.C2 = C2;
    voltMdl.Rs = Rs(:);

    resampleSOC = 0:0.0005:1;
    voltMdl.OCV = interp1(SOC, OCV, resampleSOC, 'pchip', 'extrap'); % OCV;
    voltMdl.SOC = resampleSOC; % SOC;
    
    
    %%  Temp Model 
    cc = 59.903 * ones(1, NUMCELLS);
    cs = 0.24409 * ones(1, NUMCELLS);
    rc = 0.42963 * ones(1, NUMCELLS);
    re = 0.098836 * ones(1, NUMCELLS);
    ru = 16.419 * ones(1, NUMCELLS);
    
    % A,B,C,D Matrices  ***
    % Multi SS model
    % Creates a row of repeating A Matrices
    A11 = -1./(rc.*cc); % Top left of 2x2 matrix
    A12 = 1./(rc.*cc);  % Top right of 2x2 matrix
    A21 = 1./(rc.*cs); % Bottom left of 2x2 matrix
    A22 = ((-1./cs).*((1./rc) + (1./ru))); % Bottom right of 2x2 matrix
    A1 = [A11; A12]; A1 = A1(:)';
    A2 = [A21; A22]; A2 = A2(:)';
    A_cont = repmat([A1; A2], NUMCELLS, 1);
    
    % Creates a row of repeating B Matrices
    B11 = (re)./cc; % Top left of 2x2 matrix
    B12 = zeros(1, NUMCELLS);  % Top right of 2x2 matrix
    B21 = zeros(1, NUMCELLS); % Bottom left of 2x2 matrix
    B22 = 1./(ru.*cs); % Bottom right of 2x2 matrix
    B1 = [B11; B12]; B1 = B1(:)';
    B2 = [B21; B22]; B2 = B2(:)';
    B_cont = repmat([B1; B2], NUMCELLS, 1);
    
    % Creates a row of repeating C Matrices
    C11 = zeros(1, NUMCELLS); % Top left of 2x2 matrix
    C12 = zeros(1, NUMCELLS);  % Top right of 2x2 matrix
    C21 = zeros(1, NUMCELLS); % Bottom left of 2x2 matrix
    C22 = ones(1, NUMCELLS); % Bottom right of 2x2 matrix
    C1 = [C11; C12]; C1 = C1(:)';
    C2 = [C21; C22]; C2 = C2(:)';
    C = repmat([C1; C2], NUMCELLS, 1);
    
    D = zeros(size(C));
    
    % Single SS model
    %{
    A_cont = [-1/(rc*cc), 1/(rc*cc) ; 1/(rc*cs), ((-1/cs)*((1/rc) + (1/ru)))];
    B_cont = [(re)/cc 0; 0, 1/(ru*cs)];
    C = [0 0; 0 1]; %eye(2);
    D = [0, 0;0, 0];
    %}
    
    % Filter out the unnecesary nondiag matrices
    filter = eye(size(A_cont));
    filter = replaceDiag(filter, ones(NUMCELLS, 1), 1:2:size(A_cont, 1)-1, -1); % replace bottom diag with 1's
    filter = replaceDiag(filter, ones(NUMCELLS, 1), 1:2:size(A_cont, 1)-1, 1); % replace top diag with 1's
    
    tempMdl = struct;
    tempMdl.A_cont = A_cont .* filter;
    tempMdl.B_cont = B_cont .* filter;
    tempMdl.C = C;
    tempMdl.D = D;
    
    sys_temp = ss(tempMdl.A_cont,tempMdl.B_cont,C,D);
    sds_temp = c2d(sys_temp,sampleTime);
    
    tempMdl.A = sds_temp.A;
    tempMdl.B = sds_temp.B;
    
    % Manual Discretization of SS model
    %{
    A_Dis = expm(tempMdl.A_cont * sampleTime);
    tempMdl.A = A_Dis;
    tempMdl.B = tempMdl.A\(A_Dis - eye(size(A_Dis,1))) * tempMdl.B_cont;
    %}
    
    
    %% SOC Model   
    A_soc = eye(NUMCELLS);
    B1 = -1 ./(CAP(:) * 3600);
    
    % Active Balancing Transformation Matrix
    Qx = diag(CAP(:) * 3600); % Maximum Capacities
    T = repmat(1/NUMCELLS, NUMCELLS) - eye(NUMCELLS); % Component for individual Active Balance Cell SOC [2]
    B2 = (Qx\T);
    
    socMdl.A = A_soc;
    socMdl.B1 = B1;
    socMdl.B2 = B2;
    
    %% Curr Model
    % Transformation matrix to emulate the actual current going through each
    % battery during balancing (charge and discharge). 
    T_chrg = eye(NUMCELLS) - (repmat(1/NUMCELLS, NUMCELLS) / chrgEff); % Current Transformation to convert primary cell currents to net cell currents to each cell during charging
    T_dchrg =  eye(NUMCELLS) - (repmat(1/NUMCELLS, NUMCELLS) * dischrgEff); % Current Transformation to convert primary cell currents to net cell currents to each cell during discharging
    currMdl.T_chrg = T_chrg;
    currMdl.T_dchrg = T_dchrg;
    currMdl.balWeight = 1; % Whether or not to use the balancing currents during optimization
    
    %% Anode Potential (indirectly Lithium Plating) Lookup table (From "01_INR18650F1L_AnodeMapData.mat")
    load(dataLocation + '01_INR18650F1L_AnodeMapData.mat'); % Lithium plating rate
    anPotMdl.Curr = cRate_mesh * RATED_CAP;
    anPotMdl.SOC = soc_mesh;
    anPotMdl.ANPOT = mesh_anodeGap;
    

catch ME
    script_handleException;
end
