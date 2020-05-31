classdef BK_PSU
    %BK_PSU class handles control and data recording primarily for the BK
    %Precision 1688B power supply (PSU). Other BK PSUs might also be
    %compatible, you would need to confirm this yourself.
    %   This class uses the serial (USB) protocol to send commands and
    %   receive data from the PSU. For successful communication, the device
    %   needs to send "ok" for the command to execute. All of this is
    %   handled by this program.
    %
    %Change Log
    %   CHANGE                                      REVISION	DATE-YYMMDD
    %   Initial Revision                            00          181124
    %   Replaced global variable 's' with           01          181201
    %       class property SerialObj
    %   Removed automatic serial port open and      02          190107
    %       close with functions. User will be
    %       required to close ports manually
    
    properties (SetAccess = private)
        SerialObj % Returns the serial object used by the device  
        COMPort
        COMBaudRate
        COMDataBits
        COMParity
        COMStopBits
        COMTerminator
    end
    
    properties 
        Connected % Property for verifying whether or not the machine is connected
    end

    methods (Access = private)

        function reply = send(obj, comnd, value) 
            %send Makes most write commands to the PSU
            %   Writes the command - comnd{<value>}[CR] - to the serial
            %   port. Where "value" is a 1 decimal place value. Gets a
            %   reply "OK" from device indicating success.

            if isa(value, 'double')
                 value = value * 10;
                 value = num2str(value);

                 if numel(value) == 3
                     command = strcat(comnd, value);
                 elseif numel(value) == 2
                     command = strcat(comnd,'0',value);
                 elseif numel(value) == 1
                     command = strcat(comnd,'00', value);
                 end
                 
                fprintf(obj.SerialObj, command);
                reply = fgetl(obj.SerialObj);
             else
                error('Value must be a double with 1 decimal place')
            end
        end

        function [data, reply] = receive(obj, comnd)
            %receive Makes most read commands from the PSU
            %   Writes the command - comnd[CR] - and receives the reponse 
            %   from the serialport including the reply 'OK'.

            fprintf(obj.SerialObj, comnd);
            dataStr = fgetl(obj.SerialObj);
            reply = fgetl(obj.SerialObj);
            
            if numel(dataStr) == 3
                val_1 = str2double(dataStr); val_1 = val_1/10;
                data = val_1;
            % If the data received from the stream is of 6 characters 
            % (e.g 034142), this block breaks them into 2 double values
            % (3.4 and 14.2)
            elseif numel(dataStr) == 6
                val_1 = str2double(dataStr(1:3)); val_1 = val_1/10;
                val_2 = str2double(dataStr(4:6)); val_2 = val_2/10;
                data = [val_1, val_2];
            % If the data received from the stream is of 9 characters 
            % (e.g '030201450'), this block breaks them into 3 double values
            % (3.02, 1.45 and 0)
            elseif numel(dataStr)== 9 
                val_1 = str2double(dataStr(1:4)); val_1 = val_1/100;
                val_2 = str2double(dataStr(5:8)); val_2 = val_2/100;
                val_3 = str2double(dataStr(9));
                data = [val_1, val_2, val_3];
            end
        end %End of receive
        
    end %End of METHODS (Private)
    
    methods
        function obj = BK_PSU(port)
            %BK_PSU Initiates an instance of BK_PSU that takes the COM as
            %an argument.
            %   This Constructor creates a generic serial object with
            %   Baudrate = 9600, DataBits = 8, Parity = 'none', 
            %   StopBits = 1, and Terminator = 'CR'. These settings are
            %   default for the BK Precision 1688B PSU.
            %   port = 'COM#' (String)
                        
            obj.COMPort = port;
            s = serial(port); %Creates a serial port object
            obj.SerialObj = s;
            obj.COMBaudRate = 9600; s.BaudRate = obj.COMBaudRate;
            obj.COMDataBits = 8; s.DataBits = obj.COMDataBits;
            obj.COMParity = 'none'; s.Parity = obj.COMParity;
            obj.COMStopBits = 1; s.StopBits = obj.COMStopBits;
            obj.COMTerminator = 'CR'; s.Terminator = obj.COMTerminator;
            % Open Port
            if obj.SerialObj.Status == "closed"
                fopen(obj.SerialObj);
            end
            obj.Disconnect();
        end
        
        function reply = SetVolt(obj,volt)
            %SetVolt Sets the voltage level 
            %   Writes the command - VOLT{<voltage>}[CR] - to the serial
            %   port. Where "volt" is a 1 decimal place value from 0 - 18V
            %   e.g 5.5
            
             if (nargin > 0 && volt <= 18.0)
                 reply = send(obj,'VOLT',volt);                             
             else
                 error('Value can not be greater than 18.0V')
             end
        end
        
        function reply = SetCurr(obj,curr)
            %SetVolt Sets the Current level 
            %   Writes the command - VOLT{<voltage>}[CR] - to the serial
            %   port. Where "volt" is a 1 decimal place value from 0 - 18V
            %   e.g 5.5
            
             if (nargin > 0 && curr <= 20.0)
                 reply = send(obj,'CURR',curr);   
             else
                 error('Value can not be greater than 20.0A')
             end
        end
        
        function reply = SetPresets(obj, presets)
            %SetPresets Sets 3 sets of voltage and current values 
            %to be stored for quick recollection from the PSU storage.
            %   This function is not yet impelemented!
            
        end
        
        function [data, reply] = GetVoltCurrS(obj)
            %GetVoltCurrS Gets the voltage and current setting values from
            %the power supply.
            %   Writes the command - GETS[CR] - to the serial port and
            %   receives the data and the reply "OK"
            %   
            %   [data, reply] -> data is a vector of Voltage and Current.
            %   Reply returns the success of the operation "OK"
            
                       
            [result, reply] = receive(obj, 'GETS');
            
            data = result;
        end % End of GetVoltCurrS
        
        function [data, mode, reply] = GetVoltCurrD(obj)
            %GetVoltCurrD Gets the display voltage and current values from
            %the power supply (The actual values).
            %   Writes the command - GETD[CR] - to the serial port and
            %   receives the data and the reply "OK"
            %   
            %   [data, mode, reply] -> data is a vector of Voltage and
            %   Current, while mode is the PSU mode (CC or CV)
            %   Reply returns the success of the operation "OK"
            
            [result, reply] = receive(obj, 'GETD');
            
            data(1) = result(1);
            data(2) = result(2);
            
            if result(3) == 1.0
                mode = 'CC';
            elseif result(3) == 0.0
                mode = 'CV';
            end
        end % End of GetVoltCurrD
        
        function reply = GetPresets(obj)
            %GetPresets Gets 3 sets of voltage and current values 
            %from the PSU storage.
            %   This function is not yet impelemented!
            
        end%End of GetPresets
        
        function reply = SetVoltCurr4rmPreset(obj, presets)
            %SetVoltCurr4rmPreset Sets voltage and current values 
            %stored in the PSU presets storage to the PSU.
            %   This function is not yet impelemented!
            
        end%End of SetVoltCurr4rmPreset
        
        function reply = Connect(obj)
            %Connect Turn on the output. Connects PSU to the circuit.
            %   Writes - SOUT1 - to the PSU.
            
            fprintf(obj.SerialObj, 'SOUT0');
            reply = fgetl(obj.SerialObj);
            
            obj.Connected = true;
        end%End of ConnectPSU
        
        function reply = Disconnect(obj)
            %Disconnect Turn off the output. Disconnects PSU from the circuit.
            %   Writes - SOUT0 - to the PSU.
            
            fprintf(obj.SerialObj, 'SOUT1');
            reply = fgetl(obj.SerialObj);
            
            obj.Connected = false;
        end %End of DisconnectPSU
        
        function reply = SetOVP(obj,ovp)
            %SetOVP Sets the upper voltage limit of power supply 
            %Over-voltage Protection
            %   Writes the command - SOVP{<voltage>}[CR] - to the serial
            %   port. Where "ovp" is a 1 decimal place value from 0 - 18V
            %   e.g 15.0
 
             if (nargin > 0)
                 reply = send(obj,'SOVP',ovp);   
             end
         end %End of SetOVP
         
        function reply = SetOCP(obj,ocp)
            %SetOCP Sets the upper current limit of power supply. 
            %Over-current Protection
            %   Writes the command - SOCP{<Current>}[CR] - to the serial
            %   port. Where "ocp" is a 1 decimal place value from 0 - 20A
            %   e.g 15.0
            
             if (nargin > 0)
                 reply = send(obj,'SOCP',ocp);   
             end     
         end %End of SetOCP
         
        function [data, reply] = GetOVP(obj)
            %GetOVP Gets the Over-voltage protection (OVP) value from
            %the power supply.
            %   Writes the command - GOVP[CR] - to the serial port and
            %   receives the data and the reply "OK"
            %   
            %   [data, reply] -> data is the Over-Voltage Protection value.
            %   Reply returns the success of the operation "OK"
            
            [result, reply] = receive(obj, 'GOVP');
            
            data = result;
        end % End of GetOVP
        
        function [data, reply] = GetOCP(obj)
            %GetOCP Gets the Over-current protection (OCP) value from
            %the power supply.
            %   Writes the command - GOCP[CR] - to the serial port and
            %   receives the data and the reply "OK"
            %   
            %   [data, reply] -> data is the Over-Current Protection value.
            %   Reply returns the success of the operation "OK"
            
             [result, reply] = receive(obj, 'GOCP');
            
            data = result;
            
        end % End of GetOCP
        
        function [data, reply] = GetVoltCurrMax(obj)
            %GetVoltCurrMax Gets the Maximum Voltage and Current values 
            %the PSU can output.
            %   Writes the command - GMAX[CR] - to the serial port and
            %   receives the data and the reply "OK"
            %   
            %   [data, reply] -> data is the max Voltage and Current of 
            %   the PSU. Reply returns the success of the operation "OK"
            
            
            [result, reply] = receive(obj, 'GMAX');
            
            data = result;
        end % End of GetVoltCurrM
        
        
    end %End of METHODS (Public)
end

