% This script extracts OCV from both a charge and discharge voltage
% curve with respect to their SOCs. Data must have been collected in 25°C
% ambient temperature.
% 
% This script adopts the methods used in Dr. Gregory Plett's lectures 
% 2.6 & 2.7 (Repo: http://mocha-java.uccs.edu/ECE5710/index.html)


currFilePath = mfilename('fullpath');
[mainPath, filename, ~] = fileparts(currFilePath);
cd(mainPath)

%% 0) Some constants. Values here should be revised when needed
% Data file name
dataFile    = "008OCV_AB1_Rev1.mat";
dataLocation = "..\..\01CommonDataForBattery\";

saveResults = false; % Should mat file versions of the OCV and SOC be saved?

% Cell Data indices
volt_ind    = 1;
soc_ind     = 3;
ah_ind      = 4;

%% 1) Load the data
load(dataLocation+dataFile, 'battTS_dchrg', 'battTS_chrg')

%% 1.5) Plot OG OCV data
figure;
plot(battTS_chrg.time, flip(battTS_chrg.Data(:, volt_ind)), 'LineWidth', 4)
hold on;
plot(battTS_dchrg.time, battTS_dchrg.Data(:, volt_ind), 'LineWidth', 4)
legend("charged", "discharged")


%% 2) Calculate the Coulombic Efficiency

% Coulombic Efficiency calc at 25°C
ceff = max(battTS_dchrg.Data(:, ah_ind)) / max(battTS_chrg.Data(:, ah_ind))

%% 3) Compute SOC corresponding to each time
 
% Resample both timeseries to have equal sample time
timevec = 0.25:0.25:max(battTS_chrg.time); 
timevec = [min(battTS_chrg.time), timevec];
battTS_chrg2 = resample(battTS_chrg,timevec);
battTS_chrg2.time(1) = 0;

timevec = 0.25:0.25:max(battTS_dchrg.time);
timevec = [min(battTS_dchrg.time), timevec];
battTS_dchrg2 = resample(battTS_dchrg,timevec);
battTS_dchrg2.time(1) = 0;

dod = flip(battTS_dchrg2.Data(:, ah_ind));

SOC = 1 - (dod /  max(battTS_dchrg2.Data(:, ah_ind)));
%% 4) Extract OCV Relationship

% Find where the mid points for each Ah is. Midpoints correspond to 50%.
% 50% is chosen wrt the volt signal in both data trending in the same
% direction (charging direction)
[~, ind_chrg] = min( abs(ceff * max(battTS_chrg2.Data(:, ah_ind))/2 ...
                        - ceff * battTS_chrg2.Data(:, ah_ind)) );

[~, ind_dchrg] = min( abs( max(battTS_dchrg2.Data(:, ah_ind))/2 ...
                            - flip(battTS_dchrg2.data(:, ah_ind))));

% "Pad" the shorter vector 
offset = ind_dchrg-ind_chrg;
shorterRng = offset+1:offset+length(chrgVolt);
chrgVolt = battTS_chrg2.Data(:, volt_ind); 
dchrgVolt = flip(battTS_dchrg2.Data(:, volt_ind));

% Calculate OCV from average of charge and discharge volts that are
% available for both curves
avgVolt = mean([chrgVolt, dchrgVolt(shorterRng)], 2);

% Interpolate a line between the limits of avgVolt and their the very ends
% (0 and 1 SOC)
lowEnd_SOC = SOC(1:(shorterRng(1)-1));
highEnd_SOC = SOC(shorterRng(end)+1:end);

lowOCV = interp1(lowEnd_SOC([1, end]), [dchrgVolt(1), avgVolt(1)], lowEnd_SOC);
highOCV = interp1(highEnd_SOC([1, end]), [avgVolt(end), dchrgVolt(end)], highEnd_SOC);

OCV = [lowOCV; avgVolt; highOCV];

%% 5) Plot OCV relationships
figure;
plot(SOC(shorterRng), chrgVolt, 'LineWidth', 4)
hold on; grid on;
plot(SOC, dchrgVolt, 'LineWidth', 4)
hold on; 
plot(SOC(shorterRng), OCV, "k:", 'LineWidth', 4)
legend("charged", "discharged", "Approx. OCV")

%% 6) Save OCV Data to file
if saveResults == true
    save(dataLocation+dataFile, 'OCV', 'SOC', 'ceff', '-append')
end

%% Test Method 2

