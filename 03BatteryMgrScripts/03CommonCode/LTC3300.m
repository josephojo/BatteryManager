classdef LTC3300 < handle
    %LTC3300 Specific Routines and details related to the LTC3300 cell
    %balancers
    %   The LTC3300 Class contains the methods and supplementary bits
    %   associated with translating the balance actions of 6 cell balancers 
    %   into balance commands for the LTC3300 Battery Balancer IC.
    %   
    %   There is NO NEED to define an object for this class file yourself. 
    %   It is used in DC2100A.m
    %   
    % ####################       Change Log       #########################
    %----------------------------------------------------------------------
    % REVISION	DATE-YYMMDD  |  CHANGE                                      
    %----------------------------------------------------------------------
    % 00        200501          Initial Release
    %
    
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % CONSTANTS
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    properties (Constant)
        NUM_CELLS = 6;
        CRC_SIZE = 4
        BALANCE_COMMAND_SIZE = 16;
        STATUS_UNUSED_SIZE = 3;
        
        % Struct containing the Main IC commands. These instruct the IC of
        % what is needed to be done. They are different from the balance
        % commands
        Command = struct ...
            (...	
                'Write_Balance' , 0xA9, ...
                'Read_Balance' 	, 0xAA, ...
                'Read_Status' 	, 0xAC, ...
                'Execute' 		, 0xAF, ...
                'Suspend' 		, 0xAE  ...
            );
        
        % A struct containing the actual Balancer commands the LTC3300 ICs 
        % can understand. Non_Sync discharge is not used. See LTC3300 
        % manual for functionality.
         Balance_Command = struct ...
            (...	
                'None'              , uint32(0x00), ... % Balancing Action: None
                'Discharge_Nonsync' , uint32(0x01), ... % Balancing Action: Discharge Cell n (Nonsynchronous)
                'Discharge_Sync'    , uint32(0x02), ... % Balancing Action: Discharge Cell n (Synchronous)
                'Charge'            , uint32(0x03)  ... % Balancing Action: Charge Cell n
            );
            
        % Balancer constants for sending and receiving data from the
        % DC2100A Board
        Cell_Balancer = struct ...
            (...	
                'BALANCE_TIME_RESOLUTION'   , (125/1000), ... %  s per bit
                'BALANCE_TIME_MAX'          , (bitshift(1, 15) - 1) * (1/1000), ... % 15 bit time
                'BALANCE_TIME_FORMAT'       , "0.00", ...
                'BALANCE_COMMAND_SIZE'      , 2,  ... 
                'BALANCE_ACTION'            , struct... % Human understandable balance actions
                                                (...
                                                    'None', 0, ...
                                                    'Discharge', 1, ...
                                                    'Charge', 2, ...
                                                    'IC_Error', 3 ...
                                                )...
            );
        
        
    end
    
    
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % PUBLIC PROPERTIES
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    properties
        ic_num
        status_valid = false;
        Enabled = true;
        eventLog
        
        % Variable to receive the current balance commands/actions of the
        % balancers on the LTC3300 IC
        RD_Cmd = struct...
            (...
            'bal_cmd', zeros(1, LTC3300.NUM_CELLS),  ...
            'bal_action', zeros(1, LTC3300.NUM_CELLS), ...
            'crc', 0 ...
            );
        
        % Variable to receive the current status of the IC and the 
        % balancers on the LTC3300 IC
        RD_Stat = struct...
            (...
            'unused', zeros(1, 3), ...
            'temp_ok', false, ...
            'stack_not_ov', false, ...
            'cells_not_ov', false, ...
            'gate_ok', zeros(1, LTC3300.NUM_CELLS), ...
            'crc', 0 ...
            );
        
    end
    
    
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % PRIVATE METHODS
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    methods (Static) % Access = private)
        
        function balance_action = Convert_Balance_Command_To_Balance_Action(balance_command)
            %Convert_Balance_Command_To_Balance_Action Converts Hardware
            %recognizable command to human recognizable actions.
            %   Hardware "Balance Commands" include :
            %       - LTC3300.Balance_Command.None                      = 0
            %       - LTC3300.Balance_Command.Discharge_NoSync(Not Used)= 1
            %       - LTC3300.Balance_Command.Discharge_Sync            = 2
            %       - LTC3300.Balance_Command.Charge                    = 3
            %   Human "Balance Actions" include : 
            %       - LTC3300.Cell_Balancer.BALANCE_ACTION.None         = 0
            %       - LTC3300.Cell_Balancer.BALANCE_ACTION.Discharge    = 1
            %       - LTC3300.Cell_Balancer.BALANCE_ACTION.Charge       = 2

            
            if balance_command == LTC3300.Balance_Command.None
                balance_action = LTC3300.Cell_Balancer.BALANCE_ACTION.None;
                
            elseif balance_command == LTC3300.Balance_Command.Discharge_Sync
                balance_action = LTC3300.Cell_Balancer.BALANCE_ACTION.Discharge;
                
            elseif balance_command == LTC3300.Balance_Command.Charge
                balance_action = LTC3300.Cell_Balancer.BALANCE_ACTION.Charge;
            end
            
        end
        
        
        function balance_command = Convert_Balance_Action_To_Balance_Command(balance_action)
            %Convert_Balance_Action_To_Balance_Command Converts Human 
            %recognizable actions to Hardware recognizable command.
            %   Hardware "Balance Commands" include :
            %       - LTC3300.Balance_Command.None                      = 0
            %       - LTC3300.Balance_Command.Discharge_NoSync(Not Used)= 1
            %       - LTC3300.Balance_Command.Discharge_Sync            = 2
            %       - LTC3300.Balance_Command.Charge                    = 3
            %   Human "Balance Actions" include : 
            %       - LTC3300.Cell_Balancer.BALANCE_ACTION.None         = 0
            %       - LTC3300.Cell_Balancer.BALANCE_ACTION.Discharge    = 1
            %       - LTC3300.Cell_Balancer.BALANCE_ACTION.Charge       = 2
            
            if balance_action == LTC3300.Cell_Balancer.BALANCE_ACTION.None
                balance_command = LTC3300.Balance_Command.None;
                
            elseif balance_action == LTC3300.Cell_Balancer.BALANCE_ACTION.Discharge
                balance_command = LTC3300.Balance_Command.Discharge_Sync;
                
            elseif balance_action == LTC3300.Cell_Balancer.BALANCE_ACTION.Charge
                balance_command = LTC3300.Balance_Command.Charge;
            end
            
        end
        
        
        function crcVal = calculateCRC(balance_command) %obj, 
            %calculateCRC Calculates CRC for data send to the LTC3300 IC
            dividend = int32(balance_command);
            divisor = int32(0x980); % intialize divisor As int32

            crcVal = bitand(dividend, int32(0xF80));
%             disp("Before For Loop: " + num2str(crcVal));
            for i = 1 : LTC3300.Cell_Balancer.BALANCE_COMMAND_SIZE * LTC3300.NUM_CELLS
                if crcVal >= 0x800
                    crcVal = bitxor(crcVal, divisor);
%                     disp("In For IF " + i +": " + num2str(crcVal));
                end
                crcVal = bitshift(crcVal, 1);
%                 disp("Loop After IF " + i +": " + num2str(crcVal));
                crcVal = bitor(crcVal, bitand(bitshift(dividend, i), int32(0x80)));
            end

            crcVal = bitshift(crcVal, -8);            
            crcVal = bitand((int32(0xF) - crcVal), int32(0xF), 'int32');            
        end
        
    end
    
    
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    % PUBLIC METHODS
    % =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    methods
        function obj = LTC3300(ic_ID, eventLog)
            %LTC3300 Construct an instance of this class
            %  
            
            obj.ic_num = ic_ID;
            obj.eventLog = eventLog;
        end

        
        function balance_command = Get_Write_Command(obj, balance_action)
            %Get_Write_Command Creates appropriate hex value string to be used in Write command
            %   
            %   Inputs:
            %       obj             : LTC3300 object. Can otherwise add it behind
            %                           function i.e. obj.Get_Write_Command(balance_action)
            %
            %       balance_action  : LTC3300.Cell_Balancer actions that balancer should take for each cell connected to the balancer.
            %                           Actions for each cell include:
            %                            - LTC3300.Cell_Balancer.BALANCE_ACTION.None
            %                            - LTC3300.Cell_Balancer.BALANCE_ACTION.Discharge
            %                            - LTC3300.Cell_Balancer.BALANCE_ACTION.Charge
            %                            
            
            balance_command = 0;

            for cell_num = 0 : LTC3300.NUM_CELLS - 1
                balance_command = bitshift(balance_command, LTC3300.Cell_Balancer.BALANCE_COMMAND_SIZE);
                balance_command = balance_command + LTC3300.Convert_Balance_Action_To_Balance_Command(balance_action(cell_num +1));
            end
            
            % Calculate the LTC3300 CRC
            crcVal = zeros(1, LTC3300.CRC_SIZE);
            command_crc = LTC3300.calculateCRC(balance_command);
            for crc_bit = 0 : LTC3300.CRC_SIZE - 1
                crcVal(crc_bit +1) = bitand(bitshift(command_crc, -crc_bit), 1);
            end
            
            for crc_bit = LTC3300.CRC_SIZE - 1 : -1 : 0
                balance_command = bitshift(balance_command, 1);
                balance_command = balance_command + crcVal(crc_bit +1);
            end

            balance_command = dec2hex(balance_command, 4);
        end
        
        
        function Set_Read_Register(obj, command, register)
            %Set_Read_Register Sets the received value of the Read command and verifies the CRC
            %
            %   Inputs:
            %       obj             : LTC3300 object. Can otherwise add it behind
            %                           function i.e. obj.Set_Read_Register(command, register)
            %
            %       command         : LTC3300.Command - Either Read_Balance or Read_Status
            %       register        : Data from current LTC3300 IC
            %       
            
            crc_read = bitand(register, (bitshift(1, LTC3300.CRC_SIZE) - 1));
            crc_check = LTC3300.calculateCRC(bitshift(register, -LTC3300.CRC_SIZE));
            
            % If CRC does not check, flag an error
            if crc_read ~= crc_check
                obj.eventLog.Add(ErrorCode.LTC3300_CRC, ...
                    "CRC Mismatch While Reading from Board. Read: " + string(dec2hex(register, 4)) + " : calculated CRC ="...
                    + string(dec2hex(crc_check, 2)));
            else
                % If CRC does check, save the value for this balancer
                
                if command == LTC3300.Command.Read_Balance
                    % Save the CRC
                    obj.RD_Cmd.crc = crc_read;
                    register = bitshift(register, -LTC3300.CRC_SIZE); % Bit shift Right
                    
                    % Save the balance command
                    for cell_num = LTC3300.NUM_CELLS -1 : -1 : 0
                        obj.RD_Cmd.bal_cmd(cell_num +1) ...
                            = bitand(register,(bitshift(1, LTC3300.Cell_Balancer.BALANCE_COMMAND_SIZE) - 1));
                        
                        obj.RD_Cmd.bal_action(cell_num +1) ...
                            = LTC3300.Convert_Balance_Command_To_Balance_Action(obj.RD_Cmd.bal_cmd(cell_num +1));
                        
                        register = bitshift(register, -LTC3300.Cell_Balancer.BALANCE_COMMAND_SIZE);
                    end
                    
                elseif command == LTC3300.Command.Read_Status
                    % Save the CRC
                    obj.RD_Stat.crc = crc_read;
                    register = bitshift(register, -LTC3300.CRC_SIZE); % Bit shift Right
                    
                    % Comment from Mfg GUI Code
                    %todo - This is a hack to determine if any of the status bits should be trusted.
                    %       Basically, none of the status bits are valid unless a balance command
                    %       is being executed, and then the Gate OK bits aren't valid unless
                    %       that particular cell is balancing.  Mark V suggested that using
                    %       the presence of any bits being set in the status register could indicate
                    %       that a balance command is being executed, as opposed to keeping track of this in FW.
                    
                    if register == 0
                        obj.status_valid = false;
                    else
                        obj.status_valid = true;
                    end
                    
                    % Save the statusES
                    for bit_num = 0 : LTC3300.STATUS_UNUSED_SIZE - 1
                        if register && 1
                            obj.RD_Stat.unused(bit_num +1) = true;
                        else
                            obj.RD_Stat.unused(bit_num +1) = false;
                        end
                        register = bitshift(register, -1);
                    end
                    
                    if register && 1
                        obj.RD_Stat.temp_ok = true;
                    else
                        obj.RD_Stat.temp_ok = false;
                    end
                    register = bitshift(register, -1);
                    
                    if register && 1
                        obj.RD_Stat.stack_not_ov = true;
                    else
                        obj.RD_Stat.stack_not_ov = false;
                    end
                    register = bitshift(register, -1);
                    
                    if register && 1
                        obj.RD_Stat.cells_not_ov = true;
                    else
                        obj.RD_Stat.cells_not_ov = false;
                    end
                    register = bitshift(register, -1);
                    
                    for cell_num = LTC3300.NUM_CELLS - 1 : -1 : 0
                        if register && 1
                            obj.RD_Stat.gate_ok(cell_num +1) = true;
                        else
                            obj.RD_Stat.gate_ok(cell_num +1) = false;
                        end
                        register = bitshift(register, -1);
                    end
                else
                    obj.eventLog.Add(ErrorCode.LTC3300_CRC, ...
                        "Unknown command = "...
                        + string(dec2hex(command, 2)));
                end
            end
        end
        
        
        function err = Get_Error(obj)
            %Get_Error Returns True if any errors are indicated by the status register
            if obj.status_valid == false
                err = false;
            else
                err = ~(obj.RD_Stat.cells_not_ov && obj.RD_Stat.stack_not_ov && obj.RD_Stat.temp_ok);
            end
        end
   
    end

end
