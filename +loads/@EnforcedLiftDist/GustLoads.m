function Lds = GustLoads(obj,Case,idx)
arguments
    obj
    Case cast.LoadCase
    idx double
end
isLocked = Case.ConfigParams.IsLocked;

% Get 1G  (Static) loads
OneGCase = cast.LoadCase.Manoeuvre(Case.Mach,Case.Alt,1,config=Case.ConfigParams,...
        SafetyFactor=Case.SafetyFactor,Idx=Case.IdxOverride);
Lds_static = obj.StaticLoads(OneGCase,idx);

% --- Extract design parameters
ADP = obj.Taw;
X = [ADP.AR, ADP.HingeEta, ADP.FlareAngle, ADP.ADR.M_c, ADP.SweepAngle];

% --- Select surrogate model based on IsLocked
if isLocked
    gprMdl_gusts_My = obj.gprMdl_gusts_locked_My;
    gprMdl_gusts_Mx = obj.gprMdl_gusts_locked_Mx;
else
    gprMdl_gusts_My = obj.gprMdl_gusts_unlocked_My;
    gprMdl_gusts_Mx = obj.gprMdl_gusts_unlocked_Mx;
end

% --- Predict WRBM (50 points)
Y_pred_1 = zeros(1, 50);
Y_pred_2 = zeros(1, 50);
for j = 1:50
    Y_pred_1(j) = predict(gprMdl_gusts_My{j}, X); 
    Y_pred_2(j) = predict(gprMdl_gusts_Mx{j}, X); 
end

% Get max gust loads
Lds = cast.size.Loads.empty;
for i = 1:length(obj.Taw.Tags)
    w_idx = find(ismember([obj.Taw.Baff.Wing.Name],obj.Taw.Tags{i}(1)),1);
    wing = obj.Taw.Baff.Wing(w_idx);
    N = length(wing.Stations);
    
    % Interpolate WRBM to match number of stations
    My_interp = interp1(linspace(0, 1, 50), Y_pred_1, linspace(0, 1, N), 'pchip');
    Mx_interp = interp1(linspace(0, 1, 50), Y_pred_2, linspace(0, 1, N), 'pchip');
    
    % Add to static loads
    Lds(i) = Lds_static(i);  % Start with static loads
    Lds(i).My = Lds(i).My + My_interp .* Case.SafetyFactor;
    Lds(i).Mx = Lds(i).Mx + Mx_interp .* Case.SafetyFactor;
end

end