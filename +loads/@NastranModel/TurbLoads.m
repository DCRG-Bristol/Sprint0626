function [Lds,BinFolder] = TurbLoads(obj,Case,idx)
arguments
    obj
    Case cast.LoadCase
    idx double
end
%get 1g cruise loads
BinFolder = obj.Sol144(Case.Mach,Case.Alt,1,TruelySilent=~obj.Verbose);

filename = fullfile(BinFolder,'bin','sol144.h5');
Loads_1g = obj.ExtractStaticLoads(filename,obj.Tags).SetIdx(idx);

try
   system(sprintf('del "\\\\.\\%s\\%s\\Source\\nul"', pwd, 'Bin_test'));
catch
end

%get incremental gust loads
obj.Sol146(Case.Mach,Case.Alt, DispIDs=nan, TruelySilent=~obj.Verbose,Type='Turb');
filename = fullfile(BinFolder,'bin','sol146.h5');
Loads_turb = obj.ExtractTurbLoads(filename,obj.Tags);

Lds_min = (Loads_1g - Loads_turb);
Lds_max = (Loads_1g + Loads_turb);
Lds = Lds_min.abs() | Lds_max.abs();
Lds = Lds.max() .* Case.SafetyFactor;
end