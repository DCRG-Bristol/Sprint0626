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
gprMdl = obj.gprMdl_locked;
if ~isLocked
    gprMdl = obj.gprMdl_unlocked;
end

% --- Predict WRBM (50 points)
Y_pred = zeros(1, 50);
for j = 1:50
    Y_pred(j) = predict(gprMdl{j}, X); 
end

% Get max gust loads
Lds = cast.size.Loads.empty;
for i = 1:length(obj.Taw.Tags)
    w_idx = find(ismember([obj.Taw.Baff.Wing.Name],obj.Taw.Tags{i}(1)),1);
    wing = obj.Taw.Baff.Wing(w_idx);
    N = length(wing.Stations);
    
    % Interpolate WRBM to match number of stations
    WRBM_interp = interp1(linspace(0, 1, 50), Y_pred, linspace(0, 1, N), 'pchip');
    
    % Add to static loads
    Lds(i) = Lds_static(i);  % Start with static loads
    Lds(i).My = Lds(i).My + WRBM_interp .* Case.SafetyFactor;
end

end