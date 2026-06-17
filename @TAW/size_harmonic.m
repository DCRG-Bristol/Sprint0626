function obj = size_harmonic(obj,opts)
arguments
    obj
    opts util.SizingOpts = util.SizingOpts;
end
res = struct();
for i = 1:100
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
            dcrg.printing.title(sprintf('Harmonic Loop completed on iter %.0f: MTOM %.0f kg',i,obj.MTOM),Length=60,Symbol=' ');
        end
        return
    end
end
if opts.Verbose
    dcrg.printing.title(sprintf('No Harmonic Convergence Continuing Anyway: MTOM %.0f kg',i,obj.MTOM),Length=60,Symbol='E');
end
warning('No harmonic Convergence - continuing anyway')
end

