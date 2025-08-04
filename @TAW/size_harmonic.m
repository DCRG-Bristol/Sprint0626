function obj = size_harmonic(obj,opts)
arguments
    obj
    opts util.SizingOpts = util.SizingOpts;
end
res = struct();
warningFlag = false;
for i = 1:50
    old = obj.MTOM;
    obj.ConstraintAnalysis();
    obj.BuildBaff(Retracted=false);
    obj.UpdateAeroEstimates();
    obj.MissionAnalysis();
    obj.WingEta = obj.Baff.Wing(1).Eta;
    obj.OEM = obj.Baff.GetOEM();
    obj.MTOM = obj.OEM + obj.ADR.Payload + obj.MTOM * obj.Mf_Fuel;
    delta = obj.MTOM - old;
    res(i).X = old;
    res(i).Y = delta;

    if abs(delta)<1
        if opts.Verbose
            ads.util.printing.title(sprintf('Harmonic Loop completed on iter %.0f: MTOM %.0f kg',i,obj.MTOM),Length=60,Symbol=' ');
        end
        return
    elseif i>1 && abs(res(i).Y) > abs(res(i-1).Y)
        % not converging
        if warningFlag
            if opts.Verbose
                ads.util.printing.title(sprintf('No Harmonic Convergence Continuing Anyway: MTOM %.0f kg',i,obj.MTOM),Length=60,Symbol='E');
            end
            return
        else
            warningFlag = true;
        end
    elseif i>4 && abs(delta)<500 && abs(res(i-1).Y)<1e3
        % switch to gradient decent if getting close
        obj.MTOM = interp1([res(end-1:end).Y],[res(end-1:end).X],0,"linear","extrap");
    end  
end
if opts.Verbose
    ads.util.printing.title(sprintf('No Harmonic Convergence Continuing Anyway: MTOM %.0f kg',i,obj.MTOM),Length=60,Symbol='E');
end
error('No harmonic Convergence - continuing anyway')
end

