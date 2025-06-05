function Meta = ExtractMeta(obj,filename)

resFile = mni.result.hdf5(filename);
Meta.ResultsFile = filename;
%% trim data
try
    trimData = resFile.read_trim;
    Meta.TrimAoA = rad2deg(trimData.ANGLEA);
catch
    Meta.TrimAoA = nan;
end
%% save Jig Twist
Meta.JigEta = obj.Taw.InterpEtas;
Meta.JigTwist = obj.Taw.InterpTwists;

%% induced drag Data
try
    res_w = util.get_induced_drag(obj,resFile,0.8,36e3,[[obj.Taw.MainWingRHS.Name],[obj.Taw.MainWingLHS.Name]]);
    res_h = util.get_induced_drag(obj,resFile,0.8,36e3,"HTP_",@(x)interp1(res_w.ys,res_w.alpha_is,x));
    Meta.InducedDragWing = res_w.Di;
    Meta.InducedDragHTP = res_h.Di;
    Meta.InducedDrag = res_w.Di + res_h.Di;
    Meta.LiftWing = res_w.L;
    Meta.LiftHTP = res_h.L;
    Meta.CL = (res_w.L + res_h.L)./(res_w.q*(res_w.area+res_h.area));
    Meta.CDi = (res_w.Di + res_h.Di)./(res_w.q*(res_w.area+res_h.area));
    Meta.CL_wing = res_w.CL;
    Meta.CDi_wing = res_w.CDi;
    Meta.LiftDist = res_w.Ls;
    Meta.CpDist = res_w.Cps;
    Meta.LiftDistYs = res_w.ys;
catch
    Meta.InducedDragWing = nan;
    Meta.InducedDragHTP = nan;
    Meta.InducedDrag = nan;
    Meta.LiftWing = nan;
    Meta.LiftHTP = nan;
    Meta.CL = nan;
    Meta.CDi = nan;
    Meta.LiftDist = nan;
    Meta.CpDist = nan;
    Meta.LiftDistYs = nan;
end
end

