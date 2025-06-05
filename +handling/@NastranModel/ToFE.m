function ToFE(obj,opts)
arguments
    obj
    opts.NChord = 5;
    opts.AR_panel = 1.5;
    opts.GenAero = true;
end
model = obj.Taw.Baff;
if isempty(model)
    error('Model has not been created')
end
% add CoM to model
X_offset = model.GetCoM;
X_offset(2:3) = 0; % Suport must lie on centreline
com = baff.Constraint("Name","CoM");
com.Offset = X_offset;
model.BluffBody(1).Offset = -com.Offset;
com.add(model.BluffBody(1));
model.Orphans = com;
model = model.Rebuild();

%create fe Model
baffOpts = ads.baff.BaffOpts();
baffOpts.SplitBeamsAtChildren = false;
baffOpts.GenerateAeroPanels = opts.GenAero;
baffOpts.ChildAttachmentMethod = ads.baff.ChildAttachmentMethod.ClosestinX;
feModel = ads.baff.baff2fe(model,baffOpts);

% sort panel densities + create AeroCoordSys
feModel.CoordSys(end+1) = ads.fe.CoordSys("A",ads.util.roty(0),"Origin",[5 0 0]');
for i = 1:length(feModel.AeroSurfaces)
    feModel.AeroSurfaces(i).AeroCoordSys = feModel.CoordSys(end);
    feModel.AeroSurfaces(i).SetPanelNumbers(opts.NChord,opts.AR_panel,"Span");
end
% feModel.AeroSettings = ads.fe.AeroSettings(obj.Span./obj.AR,1,...
%     obj.Span,obj.Span.^2./obj.AR,"ACSID",feModel.CoordSys(end-1),"Velocity",0,"RCSID",feModel.CoordSys(end));
b = obj.Taw.Span;
AR = obj.Taw.AR;
feModel.AeroSettings = ads.fe.AeroSettings(b./AR,1,b,b.^2./AR,"ACSID",feModel.CoordSys(end),"Velocity",0);

% save obj
obj.fe = feModel.Flatten;
end

