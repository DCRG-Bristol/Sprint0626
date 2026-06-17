function [binFolder,res] = ISO145(obj,Mach,opts,solOpts)
arguments
    obj
    Mach double % Mach Number
    opts.NumAttempts = 1

    solOpts.Alts = 60e3:-1e3:0;
    solOpts.DispIDs = [];
    solOpts.ForceIDs = [];
    solOpts.ModalDamping = 0.0;
    solOpts.GetEigenVectors = false;
end
%% get info for flight condtion
[TAS,CAS,rho,~,~] = ads.util.get_flight_condition(Mach,"alt",solOpts.Alts);
% update FE Model
b = obj.Taw.Span;
AR = obj.Taw.AR;
obj.fe.AeroSettings = ads.fe.AeroSettings(b./AR,1,b,b.^2./AR,...
    "ACSID",obj.fe.CoordSys(end),"Velocity",TAS(1));
IDs = obj.fe.UpdateIDs();
%make solver object
idx_CoM = find([obj.fe.Constraints.Tag] == "CoM",1);
sol = ads.nast.Sol145();
sol.CoM = obj.fe.Constraints(idx_CoM);

if solOpts.GetEigenVectors
    TAS = -TAS;
end
% sol.set_trim_steadyLevel(TAS,rho,ones(size(TAS))*Mach);
sol.set_trim_locked(TAS,rho,ones(size(TAS))*Mach)

% Flutter setup
sol.DispIDs = solOpts.DispIDs;
sol.ForceIDs = solOpts.ForceIDs;
sol.FreqRange = [0 50];
sol.FlutterMethod = 'PKNL';
sol.ModalDampingPercentage = solOpts.ModalDamping;
sol.UpdateID(IDs);

%% run Nastran
binFolder = sol.build(obj.fe,obj.BinFolder);
sol.run(binFolder,NumAttempts=opts.NumAttempts,...
    StopOnFatal=false,cmdLineArgs=cmdLineArgs);
res = sol.ExtractResults(binFolder,IncludeEigenVec=solOpts.GetEigenVectors);

%populate res with other data
for i = 1:length(res)
    [err,idx] = min(abs(res(i).RHO_RATIO-rho));
    if err<1e-4
        res(i).TAS = TAS(idx);
        res(i).CAS = CAS(idx);
    end
end
end

