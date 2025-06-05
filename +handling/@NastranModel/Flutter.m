function [flut_res,BinFolder] = Flutter(obj,Mach,opts)
arguments
    obj handling.NastranModel
    Mach
    opts.Verbose = true;
    opts.IsLocked = true;
    opts.EV = false;
    opts.Alts = 60e3:-1e3:0;
    opts.ReleaseDoFs = [];
end
% obj.SetConfiguration(FuelMass=obj.Taw.MTOM*obj.Taw.Mf_Fuel*obj.Taw.Mf_TOC,IsLocked=opts.IsLocked)
% [BinFolder,flut_res] = obj.ISO145(Mach,BinFolder=obj.BinFolder,TruelySilent=~opts.Verbose,GetEigenVectors=opts.EV,Alts=opts.Alts);

obj.SetConfiguration(FuelMass=obj.Taw.MTOM*obj.Taw.Mf_Fuel*obj.Taw.Mf_TOC,IsLocked=opts.IsLocked)
[BinFolder,flut_res] = obj.ISO145(Mach,TruelySilent=~opts.Verbose,GetEigenVectors=opts.EV,Alts=opts.Alts,ReleaseDoFs=opts.ReleaseDoFs);
end