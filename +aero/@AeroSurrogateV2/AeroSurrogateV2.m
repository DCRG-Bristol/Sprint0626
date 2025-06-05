classdef AeroSurrogateV2 < api.AbstractPolar
    %POLAR_SURROGATE Summary of this class goes here
    %   Detailed explanation goes here

    properties
        % parent
        Taw TAW
        %cruise
        e_c
        CD0_c
        CD0_meta_c

        %take-off
        e_to
        CD0_to
        CD0_meta_to

        %approach
        e_a
        CD0_a
        CD0_meta_a

        %landing
        e_ld
        CD0_ld
        CD0_meta_ld

        %extra
        AR
        SweepAngle;
        HingeEta;
        FlareAngle;
        CDw_t2c = 0.14;
        CDw_max = 0.05;
        ProturbanceDrag;
        

        e_theo = 1; % oswald efficency of the main wing

        data_meta;
        data_all;

        use_original;
    end

    methods
        function obj = AeroSurrogateV2(Taw,opts)
            arguments
                Taw
                opts.ProturbanceDrag = 0.02;
                opts.useOriginal = false;
            end
            obj.Taw = Taw;
            obj.AR = obj.Taw.AR;
            obj.ProturbanceDrag = opts.ProturbanceDrag;
            obj.use_original = opts.useOriginal;

            if isempty(Taw.SweepAngle) || isnan(Taw.SweepAngle)
                obj.SweepAngle = real(acosd(0.75.*obj.Taw.Mstar./obj.Taw.ADR.M_c)); 
            else
                obj.SweepAngle = Taw.SweepAngle;
            end
            obj.HingeEta = obj.Taw.HingeEta;
            obj.FlareAngle = obj.Taw.FlareAngle;
            
            %% Grab aerospecific data
            idir = fullfile(fileparts(mfilename('fullpath')),'private');
            files = dir(fullfile(fileparts(mfilename('fullpath')),'private'));

            obj.data_meta = repmat(struct('Mach', [], 'File', ''), length(files)-2, 1);

            k = 1;
            for i=3:length(files)
                ifile = fullfile(idir,files(1).name,files(i).name);
                iname = files(i).name;
                match = regexp(iname, '(\d+)p(\d+)', 'tokens');
                whole = match{1}{1};
                decimal = match{1}{2};
                value = str2double([whole '.' decimal]);
                iMach = value;

                idata = struct; idata.Mach = iMach; idata.File = ifile;
                obj.data_meta(k) = idata;

                k = k + 1;
            end


            %% Original

            pLamFuselage = 0.3*34/obj.Taw.Baff.BluffBody(1).EtaLength; % length of laminar flow 30% of a319 and same length on other aircraft
            [CD0,meta] = cast.drag.baff2CD0(obj.Taw.Baff,obj.Taw.WingArea,obj.Taw.ADR.Alt_cruise,obj.Taw.ADR.M_c,"pLamFuselage",pLamFuselage,"pLamWing",0.25);
            obj.CD0_meta_c = [meta,cast.drag.DragMeta("Extra",CD0*opts.ProturbanceDrag)];
            obj.CD0_c = sum([obj.CD0_meta_c.CD0]);

            % cruise info
            K_e = 1.075;
            % K_e = 1;
            obj.e_c = obj.EstimateOswald(obj.Taw.ADR.M_c,"NitaNastran")*K_e;
            obj.CD0_c = CD0;

            
            %% Take off info
            M_app = obj.Taw.ADR.V_app/340;
            CD0_to = cast.drag.baff2CD0(obj.Taw.Baff,obj.Taw.WingArea,0,M_app,"pLamFuselage",pLamFuselage,"pLamWing",0.25);
            obj.CD0_meta_to = [meta,cast.drag.DragMeta("Extra",CD0_to*0.03 + 0.04)]; % 10.2514/1.C036529 (near Eq. 5) + 0.015 fudge factor
            obj.CD0_to = sum([obj.CD0_meta_to.CD0]);
            obj.e_to = obj.EstimateOswald(M_app,"NitaNastran")*K_e-0.05;

            % obj.CL_TOmax = 0.9*(obj.Taw.Cl_max+obj.Taw.Delta_Cl_to)*cosd(sweep); % Raymer 12.15
            %% landing
            CD0_ld = cast.drag.baff2CD0(obj.Taw.Baff,obj.Taw.WingArea,0,obj.Taw.ADR.V_app/340,"pLamFuselage",pLamFuselage,"pLamWing",0.25);
            obj.CD0_ld = CD0_ld + CD0_ld * 0.03 + 0.085; % 10.2514/1.C036529 (near Eq. 5) + 0.015 fudge factor
            obj.e_ld = obj.EstimateOswald(M_app,"NitaNastran")*K_e-0.1;

            % obj.CL_max = 0.9*(obj.Cl_max+obj.Delta_Cl_ld)*cosd(sweep); % Raymer 12.15
        end

        function [CD0,meta]  = Get_Wing_Cd0(obj)
            if obj.use_original
                CD0 = obj.CD0_c + obj.Shevell(obj.Taw.ADR.M_c, obj.Taw.CL_cruise);
                meta = obj.CD0_meta_c;
            else
                [CD0,meta] = obj.interp_data_CD0(M,CL);
            end
        end

        function CD = Get_Cd(obj,Cl,M,Phase)
            arguments
                obj
                Cl
                M
                Phase FlightPhase = FlightPhase.Cruise;
            end
            if obj.Taw.LogCl
                obj.Taw.CLs(end+1) = Cl;
            end


            
            if obj.use_original
                switch Phase
                    case FlightPhase.Cruise
                        CD = obj.CD0_c + Cl^2/(pi*obj.AR*obj.e_c) + obj.Shevell(M,Cl);
                    case FlightPhase.Landing
                        CD = obj.CD0_ld + Cl^2/(pi*obj.AR*obj.e_ld);
                    case FlightPhase.Approach
                        CD = obj.CD0_ld + Cl^2/(pi*obj.AR*obj.e_ld);
                    case FlightPhase.Takeoff
                        CD = obj.CD0_to + Cl^2/(pi*obj.AR*obj.e_to);
                end
            else
                switch Phase
                    case FlightPhase.Cruise
                        CD = obj.interp_data(M,Cl,Phase);
                    case FlightPhase.Landing
                        CD = obj.interp_data(M,Cl,Phase);
                    case FlightPhase.Approach
                        CD = obj.interp_data(M,Cl,Phase);
                    case FlightPhase.Takeoff
                        CD = obj.interp_data(M,Cl,Phase);
                end
            end
            
        end
    end
end

