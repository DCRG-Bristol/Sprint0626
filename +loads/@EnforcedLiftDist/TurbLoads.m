function [Lds] = TurbLoads(obj,Case,idx)
arguments
    obj
    Case cast.LoadCase
    idx double
end
% zero loads
Lds = cast.size.Loads.empty;
for i = 1:length(obj.Taw.Tags)
    w_idx = find(ismember([obj.Taw.Baff.Wing.Name],obj.Taw.Tags{i}(1)),1);
    wing = obj.Taw.Baff.Wing(w_idx);
    Lds(i) = cast.size.Loads(wing.Stations.N,Idx=idx) .* Case.SafetyFactor;
end

end