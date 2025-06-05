function [binFolder,h5_file] = Roll144(obj,Mach,opts,solOpts)
arguments
    obj
    Mach double % Mach Number
    opts.NumAttempts = 3
    opts.Silent = true;
    opts.TruelySilent = false;
    solOpts.g = obj.g;
    solOpts.Alts = 60e3:-1e3:0;
    solOpts.GravVector = obj.GravVector;
    solOpts.AilDeflection = 0;
    solOpts.Roll = 0;
    solOpts.aoa = 0;
end
%% get info for flight condtion
[TAS,CAS,rho,~,~] = ads.util.get_flight_condition(Mach,"alt",solOpts.Alts);
rho=rho(1);
TAS=TAS(1);
% update FE Model
b = obj.Taw.Span;
AR = obj.Taw.AR;
obj.fe.AeroSettings = ads.fe.AeroSettings(b./AR,1,b,b.^2./AR,...
    "ACSID",obj.fe.CoordSys(end));

IDs = obj.fe.UpdateIDs();

obj.fe.ControlSurfaces(find([obj.fe.ControlSurfaces.Name] == "ail_RHS",1)).Deflection = deg2rad(solOpts.AilDeflection);
obj.fe.ControlSurfaces(find([obj.fe.ControlSurfaces.Name] == "ail_LHS",1)).Deflection = deg2rad(-solOpts.AilDeflection);

%make solver object
idx_CoM = find([obj.fe.Constraints.Tag] == "CoM",1);
sol = ads.nast.Sol144();
sol.OutputAeroMatrices = true;
sol.set_trim_steadyLevel(TAS,rho,Mach,obj.fe.Constraints(idx_CoM))
sol.g = solOpts.g;
sol.Grav_Vector = solOpts.GravVector;
% sol.LoadFactor = LoadFactor;
sol.UpdateID(IDs);
sol.FreqRange = [0 300];

sol.LModes = 20;
sol.ANGLEA.Value = deg2rad(solOpts.aoa);
sol.DoFs = 4;

sol.ROLL.Value = deg2rad(solOpts.Roll);

%% run Nastran
binFolder = sol.run(obj.fe,Silent=opts.Silent,NumAttempts=opts.NumAttempts,...
    BinFolder=obj.BinFolder,TruelySilent=opts.TruelySilent);
h5_file = fullfile(binFolder,"bin","sol144.h5");
end