
clearvars;
clc;
close all;

currentPath = pwd;
filePath = "C:\Users\100520035\Google Drive\School Related\Masters\00-Grad_Research\Projects\01_NNForBattCoreTempEst\01CoreTempEst\03TrainingDataGeneration\02CurrProfileGen\01DrivingCycles\";
cd(filePath);

filelist = dir('CYC_*.mat');

vehicleMass=1254;% Based on the mass of a Toyota Prius (kg)
frictionCoeff = 0.015;
aerodyCoeff = 0.3;
airDensity = 1.2; %kg/m^3
frontalArea = 2.52; % m^2
g = 9.81; % m/s^2

fr = vehicleMass*g*frictionCoeff; %Rolling resistance
fg = 0; % Gradient Resistance ; ?? sin?(? = 0)
fd = 0; % Aerodynamic drag force; 
fi = 0; % Acceleration/deceleration

mph2mps=0.44704;
maxCurr = 15; %15A is equivalent to 6C
nominalVolt = 3.3; %3.3V

interv = 0.05;

% Variable Definition
cycleNames = cell(length(filelist), 1);
collection = cell(length(filelist), 1);
divisors = zeros(length(filelist), 1);
figs = zeros(length(filelist), 1);

%% For loop to convert speed current or each driving cycle in "filelist"
for i=1:length(filelist)
    strname=filelist(i,1).name;
    load(strname);

    cyc_mph(:,2)=mph2mps*cyc_mph(:,2);  

    data = cyc_mph;
    data(:,1) = 1:1:length(cyc_mph(:,1));

    data_intp_x = 1:interv:max(data(:,1));
    
    % Interpolate velocity data vs time
    method = 'spline';
    data_intp_y_vel = interp1(data(:,1),data(:,2),data_intp_x,method); %Interpolate Velocity
    
    % Differentiate velocity to find acceleration
    data_intp_y_accel = diff([data_intp_y_vel(1),  data_intp_y_vel])./diff([data_intp_x(1) , data_intp_x]);
    data_intp_y_accel(1)=data_intp_y_accel(2);
    
    fd = (0.5*airDensity*frontalArea*aerodyCoeff).*(data_intp_y_vel.^2); % Aerodynamic drag force;
    fi = vehicleMass.*data_intp_y_accel;
    
    % Convert to power profile using formula (P = (fr+fg+fd+fi)* v)
    data_intp_y_power = (fr+fg+fd+fi).*data_intp_y_vel; %  W
    data_intp_y_power = -data_intp_y_power; % Flip all the values for current drive cyc so that a positive power becomes charging and a negative power becomes discharging
    
    
    maxPwr = max(data_intp_y_power);
    minPwr = min(data_intp_y_power);
    divisors(i) = max(abs(minPwr), abs(maxPwr)); % Finds max value in the current cycle. 
    %   This value will be used to normalize the power values. It also adds
    %   the maximum power values to a list.
    
    %%  Adds the filenames to a list
    cycleNames{i} = strname(1:end-4);
    
    %% Adds power to a collection list
    collection{i} = transpose([data_intp_x; data_intp_y_power]);
end

% Finds the overall maximum power value to use as the normalizing diviso
divisor = max(divisors);

% Goes through power profile and divides by the maximum value, then scales
% that to within the maximum value of current being used
for i=1:length(filelist)
    
    scaledPwrProfile = collection{i,1}(:,2) / divisor; % Scaled the entries to within the maximum absolute value in the profile. Therefore below 1

    currProfile = scaledPwrProfile * maxCurr; % Since scaledPowerProfile is 
        % within -1 and 1, maxCurr is multiplied to it to result in current within -maxCurr and maxCurr
    
    %% store each profile as a timeseries in an array "cycleProfile"
    cycleProfiles(i) = timeseries(currProfile, collection{i,1}(:,1));
   
end

%% add constant charging to the collection list, and also the constant C rate to the list
ccNames = {};
for ii=1:6
    ccNames{end+1}=[num2str(ii) 'C'];
    
    data_intp_x=0:interv:5000;
    
    currProfile=ones(length(data_intp_x),1)*ii*2.5;
    
    %% store each profile as a timeseries in an array "ccProfile"
    ccProfiles(ii)= timeseries(currProfile, data_intp_x);
    
end

%% Save to file
saveLocation = "C:\Users\100520035\Google Drive\School Related\Masters\00-Grad_Research\Projects\01_NNForBattCoreTempEst\01CoreTempEst\03TrainingDataGeneration\01CommonDataForBattery\";
save(saveLocation + "002CurrProfileCollection_NEW.mat",'cycleNames','cycleProfiles', 'ccNames','ccProfiles');
cd(currentPath);

