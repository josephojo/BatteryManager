
% Since resultCollection is currently a cell array of all the runs
% unwrap it into one array
resultCollection_Cell = resultCollection;
resultCollection_withAhCap = [];
for i = 1:length(resultCollection)
resultCollection_withAhCap = [resultCollection_withAhCap;resultCollection{1,i}];
end
resultCollection = resultCollection_withAhCap;

disp("Different smoothing values will be plotted in a moment." + newline...
    + newline + "Please select a smoothing Value (e.g.10) that works best for you.")
% pause(10);

lineWidth = 3;
figure(10);
plot(resultCollection(:,end-1), 'LineWidth', lineWidth);
hold on;
plot(movmean(resultCollection(:,end-1),10), 'LineWidth', lineWidth);
plot(movmean(resultCollection(:,end-1),50), 'LineWidth', lineWidth);
plot(movmean(resultCollection(:,end-1),70), 'LineWidth', lineWidth);
plot(movmean(resultCollection(:,end-1),100), 'LineWidth', lineWidth);
plot(movmean(resultCollection(:,end-1),200), 'LineWidth', lineWidth);
plot(movmean(resultCollection(:,end-1),400), 'LineWidth', lineWidth);
legend('raw','10', '50','70', '100', '200', '400')

correctVal = false;
while correctVal == false
    val = input(['\nPlease enter the smoothing value here.\n'...
        'Pressing enter automatically chooses 70 as the smoothing value: ']);
    correctVal = true;
    if isempty(val)
        val = 70;
    elseif ~strcmpi(class(val), 'double')
        correctVal = false;
    end
end
disp(newline + "You have entered: " + num2str(val));

%% Find where the temperature value starts i.e temp > 15ºC then smooths those columns
L = length(resultCollection(1, :));

for ind = L:-1:1
    if resultCollection(1,ind) < 15 && sum(resultCollection(1,ind)) ~= 0
        startCol = ind +1;
        break;
    end
end

for ind = startCol : L
    resultCollection(:,ind) = smooth(resultCollection(:,ind),val);
end

