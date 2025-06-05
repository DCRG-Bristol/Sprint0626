function [res,binFolder] = Sol103(obj,opts)
arguments
    obj
    opts.NumAttempts = 1
    opts.Silent = true;
    opts.TruelySilent = false;
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
[res,binFolder] = sol.run(obj.fe,Silent=opts.Silent,NumAttempts=opts.NumAttempts,...
    BinFolder=obj.BinFolder);
end