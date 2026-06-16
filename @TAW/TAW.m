classdef TAW < cast.ADP & cast.size.BaffSizing
    %TAW Summary of this class goes here
    %   Detailed explanation goes here

    properties %SJ added: switch to control flutter masses...
        inclFlutterMass = true;
    end

    properties
        Masses = struct();
        Dihedral = 5;
        Engine = cast.config.Engine.CFM_LEAP_1A;
        TrappedFuel = 0;

        FuelCapacity = nan;

        CD0_meta = cast.drag.DragMeta.empty();


        WingboxEtas = [0.15,0.65];
        HingeEta = 1;
        FlareAngle = 10;
        WingMass = 0;
        IsLightHinge = false;
        IsTAH = false;
        FuelEta = 0;
        IsDry = false;
        ExtraFuel = 0;
        AftEta = 0.5;
        k_hinge = 1;

        WingBeamElements = 25;

        
        MainWingRHS;
        MainWingLHS;

        ThrustToWeightRatio = 0.31;
        TargetWingLoading = 650;
        isWingAreaFixed = false;

        WingIndependentVar string {ismember(WingIndependentVar,{'AR','Span'})} = "Span";

        BallastMass = 0;

        ProturbanceDrag = 0.02;


        WingBallast = 0;
        WingBallastEta = 1;

        SecondaryMethod string {mustBeMember(SecondaryMethod,{'Prop','Planform'})} = "Prop";
        
        FowlerSlots = 1;
        RefMass = nan;

        AeroSurrogate api.AbstractPolar = aero.NullPolar();
    end

    properties % wing sweep control
        Mstar = 0.935;  % to calc wing sweep angle realtive to Cruise Mach Number
        SweepAngle = nan; % if not nan overrides MStar calc
        ForwardSwept = false; %if SweepAngle=nan then this defines if a forward or backward swept wing is generated
        NoKink = false;
    end

    properties
        N_seatsPerRow = 5;
        StaticMargin = 0.35;
        CLs = [];
        LogCl = false;
    end


    %jig twist
    properties
        UpdateJigTwist logical = false;
        RefEta = 0.3;
        UpdateRoot = true;
        InterpEtas double = [0 0.3 1];
        InterpTwists double = [0 0 0];
    end
    properties
        GravVector = [0;0;-1];
        g = 9.81;
    end
    %empenage
    properties
        HTPArea = 31.5
        VTPArea = 22.17
        HTP_TCR_root = 0.15;
        SizeEmpenage = true;
        EnableFairingStiffness = true;
    end
    %landing gear
    properties
        L_ldg = 4;
        Eta_ldg = 0.2;
        m_main_ldg = 1e3;
        m_nose_ldg = 1e3;
        Size_ldg = true;
        Size_Eng = true;
    end
    %wing/winglet
    properties
        M_winglet = 200;    % winglet mass
        TCR_root = 0.15;    % thickness to chord ratio
        Size_wing = true;
        WingDensityFactor = 1;
        ldg_scale_factor = 1;
    end
    %fuel properties
    properties
        EnforcedConnectorFuelMass = nan;
        EnforcedWingFuelMass = nan;
        WingFuelScaling = 0.94;
        ConnectorFuelScaling = 1;
    end


    properties
        Tags
    end
    methods
        function val = get.Tags(obj)
            val = obj.getTag();
        end
    end
    methods (Access=protected)
        function val = getTag(obj)
            if ~isnan(obj.HingeEta) && obj.HingeEta<1
                val = {["Wing_Connector_RHS","Wing_Connector_LHS"],["Wing_RHS","Wing_LHS"],["FFWT_RHS","FFWT_LHS"]};
            else
                val = {["Wing_Connector_RHS","Wing_Connector_LHS"],["Wing_RHS","Wing_LHS"]};
            end
        end
    end
    
    methods
        function m = PrintMass(obj)
            m = [];
            m(1) = obj.MTOM;
            m(2) = obj.Masses.PrimaryWingMass+obj.Masses.SecondaryWingMass+obj.Masses.WingletMass+obj.Masses.HingeMass;
            m(3) = obj.Masses.Fuselage + obj.Masses.ConnectorMass;
            m(4) = obj.Masses.HTP;
            m(5) = obj.Masses.VTP;
            m(6) = obj.Masses.LandingGear;
            m(7) = obj.Masses.EnginePylon;
            m(8) = obj.Masses.Engine;
            m(9) = obj.Masses.FuelSys;
            m(10) = obj.Masses.FuelTanks;
            if isfield(obj.Masses,'TrappedFuel');m(11)=obj.Masses.TrappedFuel;else;m(11)=0;end
            m(12) = 0;
            m(13) = 0;
            m(14) = 0;
            m(15) = 0;
            m(16) = obj.Masses.Systems;
            m(17) = obj.Masses.Furniture;
            m(18) = 0;
            m(19) = 0;
            m(20) = obj.Masses.OperatorItems;
            num2clip(m');
        end
        function PrintMassNames(obj)
%             m = [];
            m(1) = "MTOM [tn]";
            m(2) = "Wing Mass [tn]";
            m(3) = "Fuselage Mass [tn]";
            m(4) = "HTP [tn]";
            m(5) = "VTP [tn]";
            m(6) = "Landing Gear [tn]";
            m(7) = "Engine Pylon [tn]";
            m(8) = "Engine [tn]";
            m(9) = "Fuel System [tn]";
            m(10) = "Fuel Tanks [tn]";
            m(11) = "Trapped Fuel [tn]";
            m(12) = "N/A [tn]";
            m(13) = "Hydaulics [tn]";
            m(14) = "Electrical [tn]";
            m(15) = "Avionics [tn]";
            m(16) = "Control Systems [tn]";
            m(17) = "Furniture [tn]";
            m(18) = "N/A [tn]";
            m(19) = "N/A [tn]";
            m(20) = "Operator Items [tn]";
            clipboard('copy',strjoin(m,'\n'));
        end
        function meta = ToMeta(obj)
            [r,p] = obj.PR_diagram();
            %estimate design fuel
            mission = cast.Mission.StandardWithAlternate(obj.ADR);
            M_to = 0;
            M_f = obj.MTOM-obj.ADR.Payload-obj.OEM;
            while abs(M_to-(obj.OEM+obj.ADR.Payload+M_f))>10
                M_to = obj.OEM+obj.ADR.Payload+M_f;
                [EWF,fs] = cast.weight.MissionFraction(mission.Segments,obj,M_TO=M_to,OverideLD=true);
                M_f =  (1-EWF)/(EWF)*(obj.OEM+obj.ADR.Payload);
            end
            M_trip = (1-prod(fs([1:6])))*M_to;
            M_block = (1-prod(fs))*M_to;
            %create meta
            meta = cast.Meta();
            meta.PAX = obj.ADR.PAX;
            meta.Crew = obj.ADR.Crew;
            meta.Payload = obj.ADR.Payload;
            meta.Payload_asym = p(3);
            meta.Range_Design = obj.ADR.Range;
            meta.Range_harm = r(2)./cast.SI.Nmile;
            meta.Range_asym = r(3)./cast.SI.Nmile;
            meta.Range_ferry = r(4)./cast.SI.Nmile;
            meta.MTOM = obj.MTOM;
            meta.MZFM = (obj.Baff.GetOEM + obj.ADR.Payload - obj.TrappedFuel);
            meta.MFRES = obj.Mf_res .* obj.MTOM;
            meta.MLND = obj.MTOM.*obj.Mf_Ldg;
            meta.OEM = (obj.Baff.GetOEM - obj.TrappedFuel);
            meta.Fuel_capacity = sum([obj.Baff.Fuel.Capacity]);
            meta.Fuel_block = M_block;
            meta.Fuel_trip = M_trip;
            meta.WingArea = obj.WingArea;
            meta.Span = obj.Span;
            meta.AspectRatio = obj.AR;
            meta.Length = obj.Baff.BluffBody(1).EtaLength;
            meta.FuselageRadius = max(arrayfun(@(x)x.Radius,[obj.Baff.BluffBody(1).Stations]));
            meta.Thrust = obj.Thrust;
            meta.SpecificEnergy = obj.FuelType.SpecificEnergy;
            meta.CostPerKilo = obj.FuelType.CostPerKilo;
            meta.M_c = obj.ADR.M_c;
            meta.Alt_max = obj.ADR.Alt_max;
            meta.Alt_cruise = obj.ADR.Alt_cruise;
            meta.LD_c = obj.LD_c;
            meta.CL_c = obj.CL_cruise;
            meta.CD0 = obj.CD0;
            meta.e = obj.e;
%             meta.HingeEta = obj.HingeEta;
%             meta.IsLightHinge = obj.IsLightHinge;
        end
        function obj = TAW_pbs()
        end
%         function val = ToStruct(obj)
%             warning('off','MATLAB:structOnObject')
%             val = struct(obj);
%             warning('on','MATLAB:structOnObject')
%         end

        function [X,X_w,X_h,mac] = GetNeutralPoint(obj)
            % wing properites
            [mac,X_w] = obj.MainWingRHS.GetMGC(0.25);
            X_w(2) = 0;
            S_w = sum([tmp_wings.PlanformArea])*2;
            % htp properties
            htp_r = obj.Baff.Wing([obj.Baff.Wing.Name]=="HTP_RHS");
            [~,X_h] = htp_r.GetMGC(0.25);
            X_h(2) = 0;
            S_h = htp_r.PlanformArea()*2;
            X = (X_w.*S_w + X_h.*S_h)./(S_w+S_h);
        end

        function [x,m,vals] = GetCoMRange(obj,model)
            arguments
                obj
                model = obj.Baff;
            end
            % AdjustCoM adjust wing pos to get CoM at OEM at p % of MAC
            model = obj.Baff;
            
            [model.Payload.FillingLevel] = deal(0);
            [model.Fuel.FillingLevel] = deal(0);
            % get overall CoM (OEM)
            [COM,oem] = model.GetCoM;
            p_max = sum([model.Payload.Capacity]);
            f_max = sum([model.Fuel.Capacity]);
            mtom = obj.MTOM;
            % get fractions at differnt stages of flight
            if oem>mtom
                %oem too large so return
                m = oem;
                x = COM(1);
                vals = [0;0];
                return
            end
            p_asym = max(0,(mtom-oem-f_max));
            f_asym = max(0,(mtom-oem-p_max));
            vals = [  0 1 1 p_asym/p_max 0;...   % OEM, max payload zero fuel, max payload MTOM. max fuel MTOM. max fuel
                        0 0 f_asym/f_max 1 1]; 
            [x,m] = deal(zeros(1,size(vals,2)));
            for i = 1:size(vals,2)
                [model.Payload.FillingLevel] = deal(vals(1,i));
                [model.Fuel.FillingLevel] = deal(vals(2,i));
                % get overall CoM (OEM)
                [CoM,m(i)] = model.GetCoM;
                x(i) = CoM(1);
            end
        end

        function AdjustCoM(obj,p)
            % AdjustCoM adjust wing pos to get CoM at OEM at p % of MAC
            model = obj.Baff;
            % get CoM range
            [xs,ms,vals] = GetCoMRange(obj);
            [~,idx] = max(xs);
            % set model to aft most COM
            [model.Payload.FillingLevel] = deal(vals(1,idx));
            [model.Fuel.FillingLevel] = deal(vals(2,idx));
            [CoM,m] = model.GetCoM;
            x_a = CoM(1);
            % get wing com
            wing_r = obj.MainWingRHS(1);
            [CoM_rhs,m_rhs] = wing_r.GetGlobalCoM;
%             CoM_rhs =  wing_r.Parent.GetPos(wing_r.Eta) + wing_r.Offset + wing_r.A'*CoM_rhs;
            wing_l = obj.MainWingLHS(1);
            [CoM_lhs,m_lhs] = wing_l.GetGlobalCoM;
%             CoM_lhs = wing_l.Parent.GetPos(wing_l.Eta) + wing_l.Offset + wing_l.A'*CoM_lhs;
            m_w = m_rhs + m_lhs;
            x_w = (CoM_lhs(1).*m_lhs + CoM_rhs(1).*m_rhs)./m_w;
            %% get wing MAC
            % if has wingtip combine wings ...
            [mac,xr_mgc] = obj.MainWingRHS.GetMGC(p);
            delta_mac = xr_mgc(1) - x_w;

            % get fuselage CoM (OEM minus wings)
            m_f = m-m_w;
            x_f = (x_a*m - x_w*m_w)/m_f;

            % get reqeuire location for the CoM of the wing
            x_w_new = x_f - delta_mac*(1+m_w/m_f);

            % x_w_new is CoM now work out where the origin of the wing needs to be
            p_w = wing_r.Eta*wing_r.Parent.EtaLength;
            new_p_wing = p_w-x_w+(x_w_new);

            % adjust eta
            eta = new_p_wing/wing_r.Parent.EtaLength;
            if isnan(eta)
                error('Undefined Wing position calulated')
            end
            % update wings
            obj.MainWingRHS(1).Eta = eta;
            obj.MainWingLHS(1).Eta = eta;
            obj.Baff = model;
        end


        function AdjustCoM_NP(obj, p)
            % AdjustCoM_NP adjust wing pos to get CoM at OEM at p % in
            % front of NP
            % THIS HAS A BUG - it assumes tail is as effective and wing...
            % get overall CoM (OEM)
            [obj.Baff.Payload.FillingLevel] = deal(0);
            [obj.Baff.Fuel.FillingLevel] = deal(0);
            [CoM,m] = obj.Baff.GetCoM;
            x_a = CoM(1);
            % get wing com
            wing_r = obj.MainWingRHS(1);
            [CoM_rhs,m_rhs] = wing_r.GetCoM;
            CoM_rhs = wing_r.Parent.GetPos(wing_r.Eta) + wing_r.Offset + wing_r.A'*CoM_rhs;
            wing_l = obj.MainWingLHS(1);
            [CoM_lhs,m_lhs] = wing_l.GetCoM;
            CoM_lhs = wing_l.Parent.GetPos(wing_l.Eta) + wing_l.Offset + wing_l.A'*CoM_lhs;
            m_w = m_rhs + m_lhs;
            x_w = (CoM_lhs(1).*m_lhs + CoM_rhs(1).*m_rhs)./m_w;
            % get wing MAC
            [mac,xr_mgc] = obj.MainWingRHS.GetMGC(0.25);
            x_mac_w = xr_mgc(1);
            S_w = sum([tmp_wings.PlanformArea])*2;
            delta_mac = x_mac_w - x_w;

            % get HTP MAC
            htp_r = obj.Baff.Wing([obj.Baff.Wing.Name]=="HTP_RHS");
            [~,xr_mgc] = htp_r.GetMGC(0.25);
            x_mac_h = xr_mgc(1);
            S_h = htp_r.PlanformArea()*2;


            % get fuselage CoM (OEM minus wings)
            m_f = m-m_w;
            x_f = (x_a*m - x_w*m_w)/m_f;
            S = S_h+S_w;
%             x_w_new = (x_mac_h*S_h*m + mac*m*S*factor - x_f*m_f*S - delta_mac*m_w*S)/(m_w*S-m*S_w);
            x_w_new = (x_mac_h*S_h*m + mac*m*S*p - x_f*m_f*S + delta_mac*m*S_w)/(m_w*S-m*S_w);

            % adjust eta
            delta_wing = x_w_new - x_w;
            delta_eta = delta_wing./wing_r.Parent.EtaLength;
            eta = wing_r.Eta - delta_eta;
            % update wings
            obj.MainWingRHS(1).Eta = eta;
            obj.MainWingLHS(1).Eta = eta;
            obj.WingEta = eta;
        end
    end
end
