classdef SB < handle
    %UNTITLED3 Summary of this class goes here
    %   Detailed explanation goes here

    properties
        ADP_model
    end

    properties 
        Wing_area
        Tail_area
    end

    properties
        MAC_wing
        Mac_tail
    end

    properties
        MAC_wing_LEx
        MAC_tail_LEx
    end

    properties
        NP
    end

    properties
        nu = 0.25;
    end

    properties
        cg
    end

    properties
        Tail_Volum_Ratio
    end

    properties
        SM
        SM_target = 0.05;
    end

    methods
        function obj = SB()
            %UNTITLED3 Construct an instance of this class

        end

        function cg_val = get.cg(obj)
            % [cg_val,~,~]=obj.ADP_model.GetCoMRange();

            cg_val=obj.ADP_model.Baff.BluffBody(1).GetGlobalCoM;
        end

        function TVR = get.Tail_Volum_Ratio(obj)
            TVR = obj.ADP_model.V_HT;
        end

        function obj = Calc_MAC_wing(obj)

            Wings = obj.ADP_model.Baff.Wing;
            etas = 0:0.01:1;

            % connector
            connector = Wings(contains([Wings.Name], 'Wing_Connector_RHS'));

            Pos_connL = connector.GetGlobalWingPos(etas,0);
            Pos_connT = connector.GetGlobalWingPos(etas,1);
            chord_conn = Pos_connT(1,:) - Pos_connL(1,:);
            chord_connx = Pos_connL(1,:);
            chord_conny = Pos_connL(2,:);

            % wing
            wing = Wings(contains([Wings.Name], 'Wing_RHS'));

            Pos_wingL = wing.GetGlobalWingPos(etas,0);
            Pos_wingT = wing.GetGlobalWingPos(etas,1);
            chord_wing = Pos_wingT(1,:) - Pos_wingL(1,:);
            chord_wingx = Pos_wingL(1,:);
            chord_wingy = Pos_wingL(2,:);

            % FWT
            FWT = Wings(contains([Wings.Name], 'FFWT_RHS'));

            Pos_fwtL = FWT.GetGlobalWingPos(etas,0);
            Pos_fwtT = FWT.GetGlobalWingPos(etas,1);
            chord_fwt = Pos_fwtT(1,:) - Pos_fwtL(1,:);
            chord_fwtx = Pos_fwtL(1,:);
            chord_fwty = Pos_fwtL(2,:);

            chords_wing_all = abs([chord_conn(1:end-1), chord_wing(1:end-1), chord_fwt]);
            chords_wing_all_x = abs([chord_connx(1:end-1), chord_wingx(1:end-1), chord_fwtx]);
            chords_wing_all_y = abs([chord_conny(1:end-1), chord_wingy(1:end-1), chord_fwty]);

            chords_sq = chords_wing_all.^2;
            mac_wing = trapz(chords_wing_all_y,chords_sq)/trapz(chords_wing_all_y,chords_wing_all);

            mac_wingx = interp1(abs([chord_wing(1:end-1), chord_fwt]), abs([chord_wingx(1:end-1), chord_fwtx]), mac_wing);

            obj.MAC_wing = mac_wing;
            obj.MAC_wing_LEx = mac_wingx;

            obj.Wing_area = trapz(chords_wing_all_y,chords_wing_all)*2;

        end

        function obj = Calc_MAC_tail(obj)

            Wings = obj.ADP_model.Baff.Wing;
            etas = 0:001:1;

            Tail = Wings(contains([Wings.Name], 'HTP_RHS'));

            Pos_TailL = Tail.GetGlobalWingPos(etas,0);
            Pos_TailT = Tail.GetGlobalWingPos(etas,1);
            chord_Tail = Pos_TailT(1,:) - Pos_TailL(1,:);
            chord_Tailx = Pos_TailL(1,:);
            chord_Taily = Pos_TailL(2,:);

            chords_sq = chord_Tail.^2;
            mac_tail = trapz(chord_Taily,chords_sq)/trapz(chord_Taily,chord_Tail);

            mac_tailx = interp1(chord_Tail, chord_Tailx, mac_tail);

            obj.Mac_tail = mac_tail;
            obj.MAC_tail_LEx = mac_tailx;

            obj.Tail_area = trapz(chord_Taily,chord_Tail)*2;

        end

        function obj = Calc_NP(obj)

            ld = handling.NastranModel(obj.ADP_model);
            ld.SetConfiguration();
            ld.CleanUp = false;

            hn = get_StabilityMargin(ld);

            obj.NP = hn;

        end


        function obj = Run_sizing(obj)

            ads.util.printing.title('Example Surrogates','Length',60,'Symbol','$')
            SubHarmonic = [0.8,3000./cast.SI.Nmile];
            sizeOpts = util.SizingOpts(IncludeGusts=false,...
                IncludeTurb=false,BinFolder='bin_size',SubHarmonic=SubHarmonic);
            [obj.ADP_model,res_mtom,Lds,time,isError,Cases] = obj.ADP_model.Aircraft_Sizing(sizeOpts,"SizeMethod","SAH");
            % get data during cruise
            fh.printing.title('Get Cruise Loads','Length',60)
            [~,Lds_c]=obj.ADP_model.StructuralSizing(...
                LoadCaseFactory.GetCases(obj.ADP_model,sizeOpts,"Cruise"),sizeOpts);
            Lds = Lds | Lds_c;
            %save data
            res = util.ADP2SizeMeta(obj.ADP_model,'GFWT','Mano',1.5,Lds,time,isError,Cases);

            if ~isfolder('example_data')
                mkdir('example_data');
            end

        end

        function obj = Calc_SM(obj)

            % sizing 
            obj = Run_sizing(obj);

            Calc_MAC_wing(obj)
            Calc_MAC_tail(obj);
            Calc_NP(obj);

            h = (obj.cg(1) - obj.MAC_wing_LEx)/obj.MAC_wing;
            obj.SM = obj.NP - h;

        end

        function obj = findX(obj)

            if isempty(obj.SM)
                Calc_SM(obj)
            end

            dh0 = obj.SM - obj.SM_target;

            % previous x
            x0 = obj.ADP_model.StaticMargin;

            while abs(dh0) >= 0.01

                % correct new x
                if dh0 > 0 % too stable
                    x_new = x0 + dh0*0.35;
                else
                    x_new = x0 - abs(dh0)*0.35;
                end

                disp(['!!!!!!!!!!!!!!!!!!!!! x_new = ', num2str(x_new)])

                % Assign new x to ADP
                obj.ADP_model.StaticMargin = x_new;

                % Calculate SM again
                Calc_SM(obj);

                % % check
                % obj.ADP_model.Baff.draw;

                % Update dh
                dh0 = obj.SM - obj.SM_target;

                x0 = x_new;

                disp(['!!!!!!!!!!!!!!!!!!!!! Current dh = ', num2str(dh0)])

            end


        end




    end

end