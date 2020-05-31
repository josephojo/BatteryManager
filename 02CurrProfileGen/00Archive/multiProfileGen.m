
clearvars;
clc;
close all;
currentPath = pwd;
cd('02CurrentProfileGen\01DrivingCycles');

plotGraphs = false; %Should Graphs be plotted?

%% find all CYC file
filelist = dir('CYC_*.mat');
mph2mps=0.44704;
vehicleMass=2241;% Based on the mass of a 2018 Tesla Model S P100D
maxCurr = 15; %15A is equivalent to 6C

NameList = {};
ProfileCollection = {};
divisors = zeros(length(filelist), 1);
data_intp_y_power = cell(length(filelist), 1);
vis = zeros(length(filelist), 1);

for i=1:length(filelist)
    strname=filelist(i,1).name;
    load(strname);

    cyc_mph(:,2)=mph2mps*cyc_mph(:,2);  

    data = cyc_mph;
    data(:,1) = 1:1:length(cyc_mph(:,1));

    interv = 0.05;
    data_intp_x = 0:interv:max(data(:,1));
    
    method = 'spline';
    data_intp_y_vel = interp1(data(:,1),data(:,2),data_intp_x,method); %Interpolate Velocity
    
    data_intp_y_accel = diff([data_intp_y_vel(1),  data_intp_y_vel])./diff([data_intp_x(1) , data_intp_x]);
    data_intp_y_accel(1)=data_intp_y_accel(2);

    data_intp_y_power{i}= vehicleMass.*data_intp_y_accel.*data_intp_y_vel; %  W
    data_intp_y_power{i} = -data_intp_y_power{i}; % Flip all the values for current drive cyc so that a positive power becomes charging and a negative power becomes discharging

    maxPwr = max(data_intp_y_power{i});
    minPwr = min(data_intp_y_power{i});
    divisors(i) = max(abs(minPwr), abs(maxPwr)); % Finds max value in the current cycle. 
    %   This value will be used to normalize the power values. It also adds
    %   the maximum power values to a list.
    
    %% Plot Graphs
    if(plotGraphs == true)
        vis(i) = figure(i);
        subplot(3,1,1);
        plot(data_intp_x,data_intp_y_vel, 'g');
        hold on;
        plot(data(:,1),data(:,2),'.r')
        xlabel('Time (s)');
        ylabel('Velocity (m/s)');
        legend('Interpolated Vel', 'Orginal Vel');
        hold off;

        subplot(3,1,2);
        plot(data_intp_x,data_intp_y_accel,'g');
        xlabel('Time (s)');
        ylabel('Acc (m/s^2)');
        hold on;
        plot(data(:,1),data(:,3),'.r')
        legend('Interpolated Acc', 'Orginal Acc')
        hold off;

        subplot(3,1,3);
        plot(data_intp_x,data_intp_y_power,'b-');
        xlabel('Time (s)');
        ylabel('Power (W)');
    end    
end
    
divisor = max(divisors); % Finds the overall maximum power value to use as the normalizing divisor

for i=1:length(filelist)
    
    scaledPwrProfile = data_intp_y_power{i} / divisor; % Scaled the entries to within the maximum absolute value in the profile. Therefore below 1

    currProfile = [data_intp_x; scaledPwrProfile * maxCurr]; % Since scaledPowerProfile is 
        % within -1 and 1, maxCurr is multiplied to it to result in current within -maxCurr and maxCurr
    
    
    %%  file name added to a list
    NameList{end+1}={strname};
    
    %% data added to a collection list
    ProfileCollection{end+1}={currProfile};
    
end


%% add constant charging to the collection list, and also the constant C rate to the list

% for ii=1:6
%     NameList{end+1}=[num2str(ii) 'C'];
%     
%     %     interv=0.02;
%     data_intp_x=0:interv:5000;
% 
%     data_intp_y_vel=ones(size(data_intp_x));
%     data_intp_y_accel=ones(size(data_intp_x));
%     data_intp_y_power=-ones(size(data_intp_x))*ii;
% 
%     ProfileCollection{end+1}={data_intp_x,data_intp_y_vel,data_intp_y_accel,data_intp_y_power};
%    
% end


cd(currentPath + "\01CommonDataForBattery");
save('001CurrProfileCollection.mat','NameList','ProfileCollection');
cd(currentPath);

