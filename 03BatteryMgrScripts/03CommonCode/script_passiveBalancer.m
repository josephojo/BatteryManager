% If battery pack has a series connectoin, check if
% balancing is needed
if strcmpi(cellConfig, "series") || strcmpi(cellConfig, "SerPar")
    % Use passive balancers if the volt deviation range is
    % greater than an allowable limit, and the max voltage
    % of a cell is greater and less than limits
    if (abs( max(testData.cellVolt(end, :)) - min(testData.cellVolt(end, :))) > testSettings.allowable_VoltDev)...
            && round(max(testData.cellVolt(end, :)), 2) >= testSettings.initialBalVolt ...
            && round(max(testData.cellVolt(end, :)), 2) < highVoltLimit-0.02
        
        cellVoltDiff = testData.cellVolt(end, :) - testSettings.initialBalVolt;
        for board_num = 0:bal.numBoards-1
            
            if length(cellVoltDiff) <= DC2100A.MAX_CELLS % If there aren't up to 12 cells
                bal_actions = double(cellVoltDiff > 0);
            elseif board_num == bal.numBoards-1 % If you're checking out cells on the last board
                startCellInd = board_num*DC2100A.MAX_CELLS+1;
                bal_actions = double(cellVoltDiff(startCellInd : end) > 0);
            else
                startCellInd = board_num*DC2100A.MAX_CELLS+1;
                rng = startCellInd : startCellInd + DC2100A.MAX_CELLS;
                bal_actions = double(cellVoltDiff(rng) > 0);
            end
            
            % Send passive balance commands to the balancing (bal) board
            bal.Passive_Balance_Write(board_num, bal_actions);
        end
    else
        % Stop passive balance commands to the balancing (bal) board
        bal.Passive_Balance_Stop();
    end
    
end