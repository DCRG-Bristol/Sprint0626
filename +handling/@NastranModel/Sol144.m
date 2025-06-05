function [binFolder,sol] = Sol144(obj,Mach,alt,LoadFactor,opts,solOpts)
arguments
    obj
    Mach double % Mach Number
    alt double  % Altitude in ft
    LoadFactor double % Load Factor
    opts.NumAttempts = 1
    opts.Silent = true;
    opts.TruelySilent = false;
    solOpts.g = obj.g;
    solOpts.GravVector = obj.GravVector;
    solOpts.aoa = 0;

end
%% get info for flight condtion
[TAS,~,rho,~,~] = ads.util.get_flight_condition(Mach,"alt",alt);
% update FE Model
b = obj.Taw.Span;
AR = obj.Taw.AR;
obj.fe.AeroSettings = ads.fe.AeroSettings(b./AR,1,b,b.^2./AR,...
    "ACSID",obj.fe.CoordSys(end),"Velocity",TAS);

for i = 1:length(obj.fe.ControlSurfaces)
    if obj.fe.ControlSurfaces(i).LinkedSurface == ""
        obj.fe.ControlSurfaces(i).Deflection = deg2rad(0);
    end
end

% obj.fe.ControlSurfaces(find([obj.fe.ControlSurfaces.Name] == "ail_RHS",1)).Deflection = deg2rad(0);
% obj.fe.ControlSurfaces(find([obj.fe.ControlSurfaces.Name] == "ail_LHS",1)).Deflection = deg2rad(0);

IDs = obj.fe.UpdateIDs();

%make solver object
idx_CoM = find([obj.fe.Constraints.Tag] == "CoM",1);
sol = ads.nast.Sol144();
sol.OutputAeroMatrices = true;
sol.set_trim_locked(TAS,rho,Mach)
sol.g = solOpts.g;
sol.ANGLEA.Value = deg2rad(solOpts.aoa);
sol.Grav_Vector = solOpts.GravVector;
sol.LoadFactor = LoadFactor;
sol.UpdateID(IDs);

%% run Nastran
binFolder = sol.run(obj.fe,Silent=opts.Silent,NumAttempts=opts.NumAttempts,...
    BinFolder=obj.BinFolder,TruelySilent=opts.TruelySilent);
end

