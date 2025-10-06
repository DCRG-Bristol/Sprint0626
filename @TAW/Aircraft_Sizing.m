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
    ADP.size_harmonic(SizingOpts);
    for i = 1:opts.MaxSteps    
        ads.Log.info(sprintf('iter %.0f: MTOM %.0f kg',i,ADP.MTOM),"#");
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
        %% tune harmonic
        ADP.size_harmonic(SizingOpts);
        %% tune for subharmonic point
        if ~isnan(SizingOpts.SubHarmonic(1))
            ads.Log.debug(sprintf('Subharmonic Loop'));
            % need to adjust Extra Fuel to hit secondary point of payload
            % range diagram
            res_extra = [];
            for ii = 1:opts.MaxSteps  
                ADP.size_harmonic(SizingOpts);
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
        % elseif abs(delta)>10e3
        %     ADP.MTOM = mtom + sign(delta)*5e3;
        % else
        %     ADP.MTOM = mtom + delta;
        % elseif i==12 || abs(delta)>abs(res_mtom(end).Bounds(1,2)-res_mtom(end).Bounds(1,1))
        %     %clean the slate
        %     save('log.mat','res_mtom')
        %     util.notify('Info',sprintf('Current Run is taking a long time...%.1f,%.1f',abs(delta),abs(r(2)-r_harm)));
        %     res_mtom = struct();
        %     res_mtom = cast.util.opt.dynBoundary(res_mtom,mtom,delta);
        %     ADP.MTOM = cast.util.opt.gd(res_mtom,1e3,10e3);
        else
            ADP.MTOM = cast.util.opt.gd(res_mtom,delta,max_step(i));
        end
        r_harm = r(2);        
        time_size = toc;
    end
% catch err
%     switch err.identifier
%         case {'CAST:SizingError','ADS:Nastran'}
%             % sizing loop failed return with error flag
%             % res_mtom = nan;
%             Lds = cast.size.Loads.empty;
%             Cases = cast.LoadCase.empty;
%             time_size = toc;
%             isError = true;
%             warning(err.message)
%         otherwise
%             rethrow(err)
%     end
% end

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
