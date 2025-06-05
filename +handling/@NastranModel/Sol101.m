function binFolder = Sol101(obj,opts,solOpts)
arguments
    obj
    opts.NumAttempts = 1
    opts.Silent = true;
    opts.TruelySilent = false;
    solOpts.g = 9.81;
    solOpts.GravVector = [0 0 1]';

end
%% get info for flight condtion
% update FE Model
b = obj.Taw.Span;
AR = obj.Taw.AR;
obj.fe.AeroSettings = ads.fe.AeroSettings(b./AR,1,b,b.^2./AR,...
    "ACSID",obj.fe.CoordSys(end),"Velocity",1);
IDs = obj.fe.UpdateIDs();
%make solver object
idx_CoM = find([obj.fe.Constraints.Tag] == "CoM",1);
sol = ads.nast.Sol101();
sol.isFree = true;
sol.CoM = obj.fe.Constraints(idx_CoM);
sol.DoFs = [];
sol.g = solOpts.g;
sol.Grav_Vector = solOpts.GravVector;
sol.LoadFactor = 1;
sol.UpdateID(IDs);

%% run Nastran
binFolder = sol.run(obj.fe,Silent=opts.Silent,NumAttempts=opts.NumAttempts,...
    BinFolder=obj.BinFolder,TruelySilent=opts.TruelySilent);
end

