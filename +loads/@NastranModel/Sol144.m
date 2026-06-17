function binFolder = Sol144(obj,Mach,alt,LoadFactor,opts,solOpts)
arguments
    obj
    Mach double % Mach Number
    alt double  % Altitude in ft
    LoadFactor double % Load Factor
    opts.NumAttempts = 3
    opts.Silent = true;
    opts.TruelySilent = false;
    solOpts.g = obj.g;
    solOpts.GravVector = obj.GravVector;

end
%% get info for flight condtion
[TAS,~,rho,~,~] = dcrg.aero.get_flight_condition(Mach,"alt",alt);
% update FE Model
b = obj.Taw.Span;
AR = obj.Taw.AR;
obj.fe.AeroSettings = ads.fe.AeroSettings(b./AR,1,b,b.^2./AR,...
    "ACSID",obj.fe.CoordSys(end),"Velocity",TAS);

% for i = 1:length(obj.fe.ControlSurfaces)
%     if obj.fe.ControlSurfaces(i).LinkedSurface == ""
%         obj.fe.ControlSurfaces(i).Deflection = deg2rad(4.55);
%     end
% end
IDs = obj.fe.UpdateIDs();

%make solver object
idx_CoM = find([obj.fe.Constraints.Tag] == "CoM",1);
sol = ads.nast.Sol144();
sol.OutputAeroMatrices = true;
sol.set_trim_steadyLevel(TAS,rho,Mach,obj.fe.Constraints(idx_CoM))
sol.g = solOpts.g;
sol.Grav_Vector = solOpts.GravVector;
sol.LoadFactor = LoadFactor;
sol.UpdateID(IDs);

%% run Nastran
binFolder = sol.run(obj.fe,Silent=opts.Silent,NumAttempts=opts.NumAttempts,...
    BinFolder=obj.BinFolder,TruelySilent=opts.TruelySilent);
end

