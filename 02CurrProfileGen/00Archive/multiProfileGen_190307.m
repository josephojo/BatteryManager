
clearvars;
clc;
close all;
currentPath = pwd;
cd('02CurrProfileGen\01DrivingCycles');

plotGraphs = false; %Should Graphs be plotted?

filelist = dir('CYC_*.mat');
mph2mps=0.44704;
vehicleMass=2241;% Based on the mass of a 2018 Tesla Model S P100D
maxCurr = 15; %15A is equivalent to 6C
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
    
    % Convert to power profile using formula (P = ma * v)
    data_intp_y_power = vehicleMass.*data_intp_y_accel.*data_intp_y_vel; %  W
    data_intp_y_power = -data_intp_y_power; % Flip all the values for current drive cyc so that a positive power becomes charging and a negative power becomes discharging
    
    
    maxPwr = max(data_intp_y_power);
    minPwr = min(data_intp_y_power);
    divisors(i) = max(abs(minPwr), abs(maxPwr)); % Finds max value in the current cycle. 
    %   This value will be used to normalize the power values. It also adds
    %   the maximum power values to a list.
    
    %% Plot Graphs
    if(plotGraphs == true)
        figs(i) = figure(i);
        subplot(3,1,1);
        plot(data_intp_x,data_intp_y_vel, 'g');
        hold on;
        plot(data(:,1),data(:,2),'.r')
        xlabel('Time (s)');
        ylabel('Velocity (m/s)');
        legend('Interpolated Vel', 'Orginal Vel');
        hold off;

%         subplot(3,1,2);
%         plot(data_intp_x,data_intp_y_accel,'g');
%         xlabel('Time (s)');
%         ylabel('Acc (m/s^2)');
%         hold on;
%         plot(data(:,1),data(:,3),'.r')
%         legend('Interpolated Acc', 'Orginal Acc')
%         hold off;
% 
%         subplot(3,1,3);
%         plot(data_intp_x,data_intp_y_power,'b-');
%         xlabel('Time (s)');
%         ylabel('Power (W)');
    end
    
    %%  Adds the filenames to a list
    cycleNames{i} = strname(1:end-4);
    
    %% Adds power to a collection list
    collection{i} = transpose([data_intp_x; data_intp_y_power]);
end

% Finds the overall maximum power value to use as the normalizing diviso
divisor = max(divisors);r

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
cd(currentPath + "\01CommonDataForBattery");
save('001CurrProfileCollection.mat','cycleNames','cycleProfiles', 'ccNames','ccProfiles');
cd(currentPath);

