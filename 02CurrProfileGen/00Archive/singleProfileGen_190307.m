%This script generates a current profile from a drive cycle

%% Single current profile based on one drive cycle
clearvars;
clc;

fileName = 'CYC_EUDC';

currentPath = pwd;
cd('02CurrProfileGen\01DrivingCycles');

mph2mps=0.44704;
vehicleMass=2241;% Based on the mass of a 2018 Tesla Model S P100D
maxCurr = 15; %15A is equivalent to 6C

load(fileName); % Driving cycle variable name is "cyc_mph"

cyc_mph(:,2)=mph2mps*cyc_mph(:,2); %Convert the data from mph to mps

data = cyc_mph;
data(:,1) = 1:1:length(cyc_mph(:,1));

interv = 0.05;
data_intp_x = 0:interv:max(data(:,1));
method = 'spline';
data_intp_y_vel = interp1(data(:,1),data(:,2),data_intp_x,method); %Interpolate Velocity

data_intp_y_accel = diff([data_intp_y_vel(1),  data_intp_y_vel])./diff([data_intp_x(1) , data_intp_x]);
data_intp_y_accel(1) = data_intp_y_accel(2); %Since the first val of accel is NaN, replace it with the value in the second cell

data_intp_y_power = vehicleMass.*data_intp_y_accel.*data_intp_y_vel; %  W

data_intp_y_power = -data_intp_y_power; % Flip all the values so that a positive power becomes charging and a negative power becomes discharging

maxPwr = max(data_intp_y_power);
minPwr = min(data_intp_y_power);
divisor = max(abs(minPwr), abs(maxPwr));

scaledPwrProfile = data_intp_y_power / divisor; % Scaled the entries to within the maximum absolute value in the profile. Therefore below 1

currProfile = timeseries(transpose(scaledPwrProfile * maxCurr), transpose(data_intp_x)); % Since scaledPowerProfile is 
    % within -1 and 1, maxCurr is multiplied to it to result in current within -maxCurr and maxCurr

cd(currentPath + "\01CommonDataForBattery");


save("003"+fileName(5:end) + "_CurrProfile.mat",'currProfile');
cd(currentPath);
