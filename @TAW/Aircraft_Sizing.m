function [ADP,res_mtom,Lds,time_size,isError,Cases] = Aircraft_Sizing(ADP,SizingOpts,opts)
arguments
    ADP
    SizingOpts util.SizingOpts = util.SizingOpts();
    opts.TargetDeltaMass = 20;
    opts.SizeMethod string {mustBeMember(opts.SizeMethod,["Baseline","SAH"])} = "Baseline";
    opts.MaxSteps = 15;
end
tic;
res_mtom = struct();
r_harm = ADP.ADR.Range;
% try
    % tune harmonic
    for i = 1:opts.MaxSteps   
        ads.Log.info(sprintf('iter %.0f: MTOM %.0f kg',i,ADP.MTOM),"high");
        %% tune harmonic
        ADP.size_harmonic(SizingOpts);
        %% run sizing
        mtom = ADP.MTOM;
        if ADP.Size_wing
            Cases = LoadCaseFactory.GetCases(ADP,SizingOpts,opts.SizeMethod);
            [~,Lds,~]=ADP.StructuralSizing(Cases,SizingOpts);
        else
            Lds = cast.size.Loads.empty;
            Cases = cast.LoadCase.empty;
        end

        ADP.ApplyWingParams();
        % update masses
        ADP.WingEta = ADP.Baff.Wing(1).Eta;
        ADP.OEM = ADP.Baff.GetOEM();
        ADP.MTOM = ADP.OEM + ADP.ADR.Payload + ADP.MTOM * ADP.Mf_Fuel;

        %% tune for subharmonic point
        if ~isnan(SizingOpts.SubHarmonic(1))
            ads.Log.debug(sprintf('Subharmonic Loop'));
            % need to adjust Extra Fuel to hit secondary point of payload
            % range diagram
            res_extra = [];
            ADP.size_harmonic(SizingOpts);
            for ii = 1:opts.MaxSteps             
                [r,p] = ADP.PR_diagram();
                r = r./cast.SI.Nmile;
                idx = ads.util.tern(p(2) == p(3),3,2);
                r_cur = interp1(p(idx:end)/p(1),r(idx:end),SizingOpts.SubHarmonic(1));
                delta = SizingOpts.SubHarmonic(2) - r_cur;
                res_extra = cast.util.opt.dynBoundary(res_extra,ADP.ExtraFuel,delta,"UpdateBoundary",false);
                if ADP.ExtraFuel == 0 && r_cur>SizingOpts.SubHarmonic(2)
                    break
                end
                if abs(delta)<(1/cast.SI.km)
                    break
                end
                ADP.ExtraFuel = max(0,cast.util.opt.gd(res_extra,ADP.Mf_Fuel*ADP.MTOM/r(2)*delta,1e3));
                ADP.size_harmonic(SizingOpts);
            end
            ads.Log.debug(sprintf('Subharmonic Loop Completed on iter %.0f: Extra Fuel %.2f Tn',ii,ADP.ExtraFuel/1e3));
        end
        %% update estimates
        [r,p] = ADP.PR_diagram();
        delta = ADP.MTOM - mtom;
        res_mtom = cast.util.opt.dynBoundary(res_mtom,mtom,delta,UpdateBoundary=false);
        % if abs(delta)>10e3
        %     ADP.MTOM = mtom + sign(delta)*5e3;
        % end
        %% set next MTOM
        if abs(delta)<opts.TargetDeltaMass && abs(r(2)-r_harm)<10
            isError = false;
            break
        elseif i>2 && abs(delta)<opts.TargetDeltaMass && res_mtom(end-1).Y<opts.TargetDeltaMass
            isError = false;
            break
        elseif i == opts.MaxSteps
            if opts.MaxSteps>1
                error('CAST:SizingError','Aircraft sizing loop did not Converge.')
            else
                isError = false;
            end
        elseif abs(delta)>=0.618*min(abs([res_mtom.Delta])) || i>6
            tmp = cast.util.opt.gd(res_mtom,delta,max_step(i));
            ADP.MTOM = 0.618*(ADP.MTOM-tmp) + tmp;
        else
            ADP.MTOM = cast.util.opt.gd(res_mtom,delta,max_step(i));
        end
        r_harm = r(2);        
        time_size = toc;
    end
    % check loads the correct size, if not re-run
    NLds = arrayfun(@(x)size(x.Mx,2),Lds);
    NWB = [ADP.WingBoxParams.NumEl];
    if any(NLds~=NWB)
        if ADP.Size_wing
            Cases = LoadCaseFactory.GetCases(ADP,SizingOpts,opts.SizeMethod);
            [~,Lds,~]=ADP.StructuralSizing(Cases,SizingOpts);
        else
            Lds = cast.size.Loads.empty;
            Cases = cast.LoadCase.empty;
        end
    end
end

function val = max_step(i)
if i == 1
    val = 10e3;
elseif i<3
    val = 5e3;
elseif i<4
    val = 3e3;
elseif i<6
    val = 1e3;
elseif i<8
    val = 0.5e3;
else
    val = 0.25e3;
end
end
