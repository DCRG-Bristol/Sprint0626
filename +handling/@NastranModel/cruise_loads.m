function [obj,Lds] = cruise_loads(obj,opts)
arguments
    obj
    opts util.SizingOpts
end
% build geometry to estmate aero coeffs
obj.BuildBaff(Retracted=false);
% get cruise loads
config = struct();
config.FuelMass = obj.MTOM*obj.Mf_Fuel;
config.PayloadFraction = opts.PayloadFraction;
config.IsLocked = true;
if ~opts.useDLM
    config.ArtForceFactor = 1;
    Cases = cast.LoadCase.Ground(Config=config,Name='cruise_FF10',SafetyFactor=1,Idx=101);
else
    Cases = cast.LoadCase.empty;
    % add 2.5g manuoevre
    Cases(end+1) = cast.LoadCase.Manoeuvre(obj.ADR.M_c,obj.ADR.Alt_cruise.*cast.SI.ft,1,config=config,...
        SafetyFactor=1,Idx=101,Name='cruise_FF10');
end
[Lds,~] = obj.GetLoads(Cases,CleanUp=opts.CleanUp,BinFolder=opts.BinFolder,Verbose=opts.Verbose,Silent=opts.Silent);
end

