function [CLs,BinFolder] = StabilityMargin(obj,Case,opts)
arguments
    obj
    Case cast.LoadCase
    opts.IsLocked = true;
    opts.aoa = 0;
end

obj.SetConfiguration(FuelMass=obj.Taw.MTOM*obj.Taw.Mf_Fuel*obj.Taw.Mf_TOC,IsLocked=opts.IsLocked)
[BinFolder,sol] = obj.Sol144(Case.Mach,Case.Alt,Case.LoadFactor,TruelySilent=false,aoa=opts.aoa);
% [BinFolder,sol] = obj.Sol144(Case.Mach,Case.Alt,Case.LoadFactor,TruelySilent=~obj.Verbose,aoa=opts.aoa);
filename = fullfile(BinFolder,'bin','sol144.h5');

res_rhs = util.get_meta_aero(obj,filename,["Wing_RHS","Connector_RHS"]);
rest_rhs = util.get_meta_aero(obj,filename,["HTP_RHS"]);
res_lhs = util.get_meta_aero(obj,filename,["Wing_LHS","Connector_LHS"]);
rest_lhs = util.get_meta_aero(obj,filename,["HTP_LHS"]);

L = abs(sum(res_rhs.Fz))+abs(sum((res_lhs.Fz)));
A = sum([res_rhs.A;res_lhs.A]);
Lt = abs(sum(rest_rhs.Fz))+abs(sum((rest_lhs.Fz)));
At = sum([rest_rhs.A;rest_lhs.A]);

CLs(1)=L/(0.5*sol.rho*sol.V^2*A);
CLs(2)=Lt/(0.5*sol.rho*sol.V^2*A);

end