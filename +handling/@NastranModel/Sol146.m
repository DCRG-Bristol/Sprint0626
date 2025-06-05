function binFolder = Sol146(obj,Mach,alt,opts,solOpts)
arguments
    obj
    Mach double % Mach Number
    alt double  % Altitude in ft

    opts.BinFolder = '';
    opts.NumAttempts = 3
    opts.Silent = true;
    opts.TruelySilent = false;

    solOpts.NGust = 12;
    solOpts.Type string {mustBeMember(solOpts.Type,{'1MC','Turb','Both'})} = '1MC';
    solOpts.DispIDs = [];       % IDs of grid points to output displacements, if blank will output all
    solOpts.ForceIDs = [];      % IDs of element IDs to output forcfes, if blank will output all
    solOpts.ModalDamping = 0.02;
    solOpts.g = 9.81;
    solOpts.GravVector = [0 0 1]';
    solOpts.FreqRange = [0 50];

end
%% get info for flight condtion
[TAS,~,rho,~,~] = ads.util.get_flight_condition(Mach,alt=alt);
% update FE Model
b = obj.Taw.Span;
AR = obj.Taw.AR;
obj.fe.AeroSettings = ads.fe.AeroSettings(b./AR,1,b,b.^2./AR,...
    "ACSID",obj.fe.CoordSys(end),"Velocity",TAS);

IDs = obj.fe.UpdateIDs();
%make solver object
idx_CoM = find([obj.fe.Constraints.Tag] == "CoM",1);
sol = ads.nast.Sol146(obj.fe.Constraints(idx_CoM));
sol.FreqRange = solOpts.FreqRange;
sol.set_trim_steadyLevel(TAS,rho,Mach,alt);

% gust setup
sol.GustDuration = 5;
sol.GustTstep = 0.01;
sol.NFreq = 600;
sol.DispIDs = solOpts.DispIDs;
sol.ForceIDs = solOpts.ForceIDs;
sol.ModalDampingPercentage = solOpts.ModalDamping;
idx = 1;
if solOpts.Type == "1MC" || solOpts.Type == "Both"
    Lengths = linspace(18,214,solOpts.NGust);
    for i = 1:length(Lengths)
        sol.Gusts(idx) = ads.nast.gust.OneMC(nan,Lengths(i),nan,'Length_atmos');
        sol.Gusts(idx).Tdelay = 1;
        idx = idx+1;
    end
elseif solOpts.Type == "Turb"
    sol.Gusts(idx) = ads.nast.gust.Turb(nan);
end
for i = 1:length(sol.Gusts)
    sol.Gusts(i).set_params(TAS,alt=alt);
end
sol.UpdateID(IDs);

%% run Nastran
binFolder = sol.run(obj.fe,Silent=opts.Silent,NumAttempts=opts.NumAttempts,...
    BinFolder=opts.BinFolder,TruelySilent=opts.TruelySilent);
end

