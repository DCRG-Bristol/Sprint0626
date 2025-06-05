function [Lds,BinFolder] = StaticLoads(obj,Case,idx)
arguments
    obj
    Case cast.LoadCase
    idx double
end
BinFolder = obj.Sol144(Case.Mach,Case.Alt,Case.LoadFactor, TruelySilent=~obj.Verbose);
filename = fullfile(BinFolder,'bin','sol144.h5');
Lds = obj.ExtractStaticLoads(filename,obj.Tags).abs() .* Case.SafetyFactor;
Lds = Lds.SetIdx(idx);
end

