function [res,binFolder] = Sol103(obj,opts)
arguments
    obj
    opts.NumAttempts = 1
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


sol = ads.nast.Sol103();
sol.FreqRange = [0 100];
sol.g = 0;                  % disable gravity
sol.CoM = obj.fe.Constraints(idx_CoM);
sol.UpdateID(IDs);

%% run Nastran
binFolder = sol.build(obj.fe,obj.BinFolder);
sol.run(binFolder,NumAttempts=opts.NumAttempts,StopOnFatal=false);
res = sol.ExtractResults(binFolder);
end