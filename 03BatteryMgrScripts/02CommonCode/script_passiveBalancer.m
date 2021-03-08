% If battery pack has a series connectoin, check if
% balancing is needed
if strcmpi(cellConfig, "series") || strcmpi(cellConfig, "SerPar")
    % Use passive balancers if the volt deviation range is
    % greater than an allowable limit, and the max voltage
    % of a cell is greater and less than limits
    if round(max(testData.cellVolt(end, :)), 2) >= testSettings.initialBalVolt ...
            && round(max(testData.cellVolt(end, :)), 2) < (highVoltLimit/numCells_Ser)-0.02
        
        if (abs( max(testData.cellVolt(end, :)) - min(testData.cellVolt(end, :))) > testSettings.allowable_VoltDev)
            % Since we're trying to discharge all cells to the minimum cell
            % voltage so they can all be the same voltage. 
            % cellVoltDiff is determined based on the minCellVolt
            if  min(testData.cellVolt(end, :)) >= testSettings.initialBalVolt
                cellVoltDiff = testData.cellVolt(end, :) - min(testData.cellVolt(end, :));
            else 
                cellVoltDiff = testData.cellVolt(end, :) - testSettings.initialBalVolt;
            end
            
            for board_num = 0:bal.numBoards-1
                if length(cellVoltDiff) <= DC2100A.MAX_CELLS % If there aren't up to 12 cells
                    bal_actions = double(round(cellVoltDiff, 2) > 0.01);
                elseif board_num == bal.numBoards-1 % If you're checking out cells on the last board
                    startCellInd = board_num*DC2100A.MAX_CELLS+1;
                    bal_actions = double(round(cellVoltDiff(startCellInd : end), 2) > 0.01);
                else
                    startCellInd = board_num*DC2100A.MAX_CELLS+1;
                    rng = startCellInd : startCellInd + DC2100A.MAX_CELLS;
                    bal_actions = double(round(cellVoltDiff(rng), 2) > 0.01);
                end
                
                % Send passive balance commands to the balancing (bal) board
                bal.Passive_Balance_Write(board_num, bal_actions);
            end
        else
            % Stop passive balance commands to the balancing (bal) board
            bal.Passive_Balance_Stop();
        end
    end
    
end