function Lds = GustLoads(obj,Case,idx)
arguments
    obj
    Case cast.LoadCase
    idx double
end
% Get 1G  (Static) loads
OneGCase = cast.LoadCase.Manoeuvre(Case.Mach,Case.Alt,1,config=Case.ConfigParams,...
        SafetyFactor=Case.SafetyFactor,Idx=Case.IdxOverride);
Lds_static = obj.StaticLoads(OneGCase,idx);

% Get max gust loads
Lds = cast.size.Loads.empty;
for i = 1:length(obj.Taw.Tags)
    w_idx = find(ismember([obj.Taw.Baff.Wing.Name],obj.Taw.Tags{i}(1)),1);
    wing = obj.Taw.Baff.Wing(w_idx);
    N = length(wing.Stations);
    Lds(i) = cast.size.Loads(N,Idx=idx) .* Case.SafetyFactor;
end
% add loads together


end