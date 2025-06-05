function [masses, eta, massId, isInnerWing] = flutterMassInterpolation(obj)
    
%required hyper parameters....
AR_req = obj.AR;
HingeEta_req = obj.HingeEta;
FlareAngle_req = obj.FlareAngle;
M_c_req = obj.ADR.M_c;
sweep_req = obj.SweepAngle;

%saved data......
Dat = open('flutterMasses.mat');
data = Dat.data;
masses_data = data.masses;

%take these out and pass as they are.....
massId = data.massId;
eta = data.eta;
isInnerWing = data.isInnerWing;

%% INTERPOLATION 

%the below are data for interpolation....
HP_data = data.HPs; %values 
HP_id = data.HP_id; %this should clarify what's in HP_data

%for now pass some zero masses... 
masses = zeros(length(eta),1);

%we only use the following (active) HPs for interpolation:
active_HP = [1, 2, 5]; %i.e., AR_req, HingeEta_req, sweep_req
% inactive_HP = [3, 4]; %i.e., FlareAngle_req, M_c_req
candidate_HP = [AR_req, HingeEta_req, FlareAngle_req, M_c_req, sweep_req];

if any(isnan(candidate_HP(active_HP)))
    masses = zeros(length(eta),1);
elseif sweep_req >= 20
    masses = zeros(length(eta),1);
else    
    sweep_req = 0;
    for ii = 1:length(eta)
        mass_interp = scatteredInterpolant(HP_data(:, active_HP), reshape(masses_data(ii, :), [], 1));
        masses(ii) = mass_interp(AR_req, HingeEta_req, sweep_req);
        if masses(ii) <= 0
           masses(ii) = 0;
        end
    end
end 

%NOTE: ONLY MASSES ARE TO BE INTERPOLATED!!!!!

end