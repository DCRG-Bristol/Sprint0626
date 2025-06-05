function [obj,Lds] = cruise_loads_SAH(obj,opts)
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
    Cases = cast.LoadCase.Ground(Config=config,Name='cruise_FF10',SafetyFactor=1,Idx=99);
    config.IsLocked = false;
    Cases(end+1) = cast.LoadCase.Ground(Config=config,Name='crusie_free',SafetyFactor=1,idx=98);
else
    Cases = cast.LoadCase.Manoeuvre(obj.ADR.M_c,obj.ADR.Alt_cruise.*cast.SI.ft,1,config=config,...
        SafetyFactor=1,Idx=99);
    config.IsLocked = false;
    Cases(end+1) = cast.LoadCase.Manoeuvre(obj.ADR.M_c,obj.ADR.Alt_cruise.*cast.SI.ft,1,Config=config,Name='cruise_free',SafetyFactor=1,Idx=98);
end
[Lds,~] = obj.GetLoads(Cases);
end

