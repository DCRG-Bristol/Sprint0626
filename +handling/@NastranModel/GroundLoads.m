function [Lds,BinFolder] = GroundLoads(obj,Case,idx,opts)
arguments
    obj
    Case cast.LoadCase
    idx double
    opts.BinFolder string = "";
    opts.Verbose logical = true;
end
BinFolder = obj.Sol101(TruelySilent=~opts.Verbose,GravVector=obj.GravVector,g=obj.g);
filename = fullfile(BinFolder,'bin','sol101.h5');
Lds = obj.ExtractStaticLoads(filename,obj.Tags).abs() .* Case.SafetyFactor;
Lds = Lds.SetIdx(idx);
end