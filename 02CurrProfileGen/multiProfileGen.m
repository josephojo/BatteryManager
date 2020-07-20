function multiProfileGen(max_cRate, cellIDs, saveLocation, cellConfig, batteryParam)
% clearvars;
% clc;
% close all;

currentPath = pwd;
% Gets the full path for the current file
currScriptPath = mfilename('fullpath');
% Seperates the path directory and the filename
[scriptPath, ~, ~] = fileparts(currScriptPath);
% goes to path
cd(scriptPath)

filePath = "01DrivingCycles\";
cd(filePath);

filelist = dir('*.mat');

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
% maxCurr = MaxCurr; %15A is equivalent to 6C

interv = 0.05;

if strcmpi(cellConfig, 'parallel')
    maxCurr = sum(batteryParam.ratedCapacity(cellIDs) * max_cRate);
else
    maxCurr = batteryParam.ratedCapacity(cellIDs) * max_cRate; % batteryParam.maxCurr(cellIDs);
end

%% For loop to convert speed current or each driving cycle in "filelist"
for i=1:length(filelist)
    strname=filelist(i,1).name;
    load(strname);

    cyc_mph(:,2)=mph2mps*cyc_mph(:,2);  

    data = cyc_mph;
    data(:,1) = 1:1:length(cyc_mph(:,1));

    data_intp_t = 1:interv:max(data(:,1));
    
    % Interpolate velocity data vs time
    method = 'spline';
    data_intp_y_vel = interp1(data(:,1),data(:,2),data_intp_t,method); %Interpolate Velocity
    
    % Differentiate velocity to find acceleration
    data_intp_y_accel = diff([data_intp_y_vel(1),  data_intp_y_vel])./diff([data_intp_t(1) , data_intp_t]);
    data_intp_y_accel(1)=data_intp_y_accel(2);
    
    fd = (0.5*airDensity*frontalArea*aerodyCoeff).*(data_intp_y_vel.^2); % Aerodynamic drag force;
    fi = vehicleMass.*data_intp_y_accel;
    
    % Convert to power profile using formula (P = (fr+fg+fd+fi)* v)
    data_intp_y_power = (fr+fg+fd+fi).*data_intp_y_vel; %  W
    data_intp_y_power = -data_intp_y_power; % Flip all the values for current drive cyc so that a positive power becomes charging and a negative power becomes discharging
    
    
    maxPwr = max(data_intp_y_power);
    minPwr = min(data_intp_y_power);
    divisor = max(abs(minPwr), abs(maxPwr)); % Finds max value in the current cycle. 
    %   This value will be used to normalize the power values. It also adds
    %   the maximum power values to a list.
    
    scaledPWRProfile = data_intp_y_power / divisor; % Scaled the entries to within the maximum absolute value in the profile. Therefore below 1
    
    %%  Adds the filenames to a list
    cycleNames(i) = string(strname(3:end-4));
    
    currProfile = scaledPWRProfile * maxCurr; % Since scaledPowerProfile is 
        % within -1 and 1, maxCurr is multiplied to it to result in current within -maxCurr and maxCurr
    
    %% store each profile as a timeseries in an array "cycleProfile"
    cycleProfiles(i) = timeseries(round(transpose(currProfile),3), (data_intp_t-data_intp_t(1))); %"(data_intp_t-data_intp_t(1))" : Moves time to start from 0 Secs instead of one
end

%% add constant charging to the collection list, and also the constant C rate to the list
ccNames = {};
for ii=1:6
    ccNames{end+1}=[num2str(ii) 'C'];
    
    data_intp_t=0:interv:5000;
    
    currProfile=ones(length(data_intp_t),1)*ii*2.5;
    
    %% store each profile as a timeseries in an array "ccProfile"
    ccProfiles(ii)= timeseries(currProfile, data_intp_t);
    
end

%% Save to file
if length(cellIDs) > 1
    save(saveLocation + "002_" + num2str(length(cellIDs)) + upper(cellConfig(1)) + ...
            batteryParam.chemistry(cellIDs(1)) + "_" + max_cRate + "C_CurrProfiles.mat",'cycleNames','cycleProfiles', 'ccNames','ccProfiles');
else
    save(saveLocation + "002_" + cellIDs + "_" + max_cRate + "C_CurrProfiles.mat",'cycleNames','cycleProfiles', 'ccNames','ccProfiles');
end

cd(currentPath);

end
