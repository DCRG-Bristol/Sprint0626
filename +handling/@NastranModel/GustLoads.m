function [Lds,BinFolder] = GustLoads(obj,Case,idx)
arguments
    obj
    Case cast.LoadCase
    idx double
end
%get 1g cruise loads
if Case.Nonlinear
    BinFolder = obj.Sol144nonlin(Case.Mach,Case.Alt,1, BinFolder=obj.BinFolder, TruelySilent=~obj.Verbose);      
else
    BinFolder = obj.Sol144(Case.Mach,Case.Alt,1, BinFolder=obj.BinFolder, TruelySilent=~obj.Verbose);
end
filename = fullfile(BinFolder,'bin','sol144.h5');
Loads_1g = obj.ExtractStaticLoads(filename,obj.Tags).SetIdx(idx);

%get incremental gust loads
obj.Sol146(Case.Mach,Case.Alt,BinFolder=BinFolder, DispIDs=nan, TruelySilent=~obj.Verbose);
filename = fullfile(BinFolder,'bin','sol146.h5');

Loads_gust_max = obj.ExtractDynamicLoads(filename,obj.Tags,isMax=true).max();
Loads_gust_min = obj.ExtractDynamicLoads(filename,obj.Tags,isMax=false).min();
Lds_min = (Loads_1g + Loads_gust_min);
Lds_max = (Loads_1g + Loads_gust_max);
Lds = Lds_min.abs() | Lds_max.abs();
Lds = Lds.max() .* Case.SafetyFactor;
end