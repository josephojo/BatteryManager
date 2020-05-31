%This script generates a current profile from a drive cycle

%% Single current profile based on one drive cycle
% clearvars;
% clc;

fileName = '03CYC_LA92'; %'CYC_UDDS'; %'CYC_HWFET'; %'CYC_US06'; %'CYC_EUDC';

filePath = "C:\Users\100520035\Google Drive\School Related\Masters\00-Grad_Research\Projects\01_NNForBattCoreTempEst\01CoreTempEst\03TrainingDataGeneration\02CurrProfileGen\01DrivingCycles\";

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
PWR = 200; % 200W as specified by the ANR26650 m1B datasheet

load(filePath + fileName); % Driving cycle variable name is "cyc_mph"

cyc_mph(:,2)=mph2mps*cyc_mph(:,2); %Convert the data from mph to mps

data = cyc_mph;
data(:,1) = 1:1:length(cyc_mph(:,1));

interv = 0.05;
data_intp_x = 0:interv:max(data(:,1));
method = 'spline';
data_intp_y_vel = interp1(data(:,1),data(:,2),data_intp_x,method); %Interpolate Velocity

data_intp_y_accel = diff([data_intp_y_vel(1),  data_intp_y_vel])./diff([data_intp_x(1) , data_intp_x]);
data_intp_y_accel(1) = data_intp_y_accel(2); %Since the first val of accel is NaN, replace it with the value in the second cell

fd = (0.5*airDensity*frontalArea*aerodyCoeff).*(data_intp_y_vel.^2); % Aerodynamic drag force;
fi = vehicleMass.*data_intp_y_accel;

% Convert to power profile using formula (P = (fr+fg+fd+fi)* v)
data_intp_y_power = (fr+fg+fd+fi).*data_intp_y_vel; %  W
data_intp_y_power = -data_intp_y_power; % Flip all the values for current drive cyc so that a positive power becomes charging and a negative power becomes discharging

maxPWR = max(data_intp_y_power);
minPWR = min(data_intp_y_power);
divisor = max(abs(minPWR), abs(maxPWR));

scaledPWRProfile = data_intp_y_power / divisor; % Scaled the entries to within the maximum absolute value in the profile. Therefore below 1

currProfile = timeseries(transpose(scaledPWRProfile * maxCurr), transpose(data_intp_x)); % Since scaledPWRProfile is 
    % within -1 and 1, maxCurr is multiplied to it to result in current within -maxCurr and maxCurr

saveLocation = "C:\Users\100520035\Google Drive\School Related\Masters\00-Grad_Research\Projects\01_NNForBattCoreTempEst\01CoreTempEst\03TrainingDataGeneration\01CommonDataForBattery\";

save(saveLocation + "003"+fileName(7:end) + "_CurrProfile.mat",'currProfile');
