classdef ErrorLog
    %ErrorLog Logs and Reports Errors that have occured in the system
    %   Detailed explanation goes here
    
    properties
        Property1
    end
    
    methods (Static)
        function Add(code, error_string, varargin)
            %Add Adds errors to the Error Log Window (initially the matlab
            %command window
            %   Compiles Error Logs for debugging or notifications
            %   Inputs:
            %       code            : The Error code from the ErrorCode
            %                           Enumeration class
            %       error_string    : The string of error to add to the log
            %                           window
            %       varargin        : Optional. Should only contain extra
            %                           data that could possibly help with
            %                           debugging. Data from here is collected
            %                           into the debug_string variable
            
            
            if ErrLogPopup.Error_Log_Enable_CheckBox.Checked = true
                % Build the Error Log Entry
                textline = CStr(System.DateTime.Now) + ", "
                textline += [Enum].GetName(GetType(Error_Code), code)
                
                % Add the Error code data that is meaningful to customers
                if error_string <> ""
                    textline += ", "
                    switch code
                        case Error_Code.USB_Dropped
                            for character  = 0 To error_string.Length - 1
                                if (error_string(character) >= " ") && (error_string(character) <= "~")
                                    textline += error_string(character)
                                else
                                    number  = Microsoft.VisualBasic.AscW(error_string(character))
                                    textline += "0x" + number.ToString("X2")
                                end
                            end
                        otherwise
                            textline += error_string
                    end
                end
                
                % Add the Error code data that is only meaningful to Linear
                if ((D33001.DEBUG_ERRORS = true) Or D33001.Mfg_Enabled = true) &&Also debug_string <> ""
                    textline += ", "
                    switch code
                        case Error_Code.USB_Dropped
                            for character  = 0 To debug_string.Length - 1
                                if (debug_string(character) >= " ") && (debug_string(character) <= "~")
                                    textline += debug_string(character)
                                else
                                    number  = Microsoft.VisualBasic.AscW(debug_string(character))
                                    textline += "0x" + number.ToString("X2")
                                end
                            end
                        otherwise
                            textline += debug_string
                    end
                end
            end
            
        end
        
        methods
            function obj = untitled2(inputArg1,inputArg2)
                %UNTITLED2 Construct an instance of this class
                %   Detailed explanation goes here
                obj.Property1 = inputArg1 + inputArg2;
            end
            
            
        end
    end
    
