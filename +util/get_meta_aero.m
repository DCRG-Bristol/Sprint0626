function res = get_meta_aero(model,filename,Tags)
arguments
    model
    filename
    Tags = ["Wing_","Connector_"]
end

    FRes = util.get_aero_force(filename);
    idx = false(size(model.fe.AeroSurfaces))';
    for i = 1:length(Tags)
        idx = idx | contains([model.fe.AeroSurfaces.Tag],Tags(i));
    end
    Areas = [model.fe.AeroSurfaces(idx).Area];
    panels = [model.fe.AeroSurfaces(idx).get_panel_coords()];
    % get span of each panel
    Spans = zeros(size(Areas));
    for i = 1:size(panels,3)
        chord_1 = norm(panels(1,:,i)-panels(2,:,i));
        chord_2 = norm(panels(4,:,i)-panels(3,:,i));
        Spans(i) = Areas(i)/(0.5*(chord_1+chord_2));
    end
    Ns = [model.fe.AeroSurfaces.nPanels];
    Nend = cumsum(Ns);
    Nstart = [1,Nend(1:end-1)+1];
    Ns = [Nstart;Nend];
    Ns = Ns(:,idx);
    PanelIdx = [];
    for i = 1:size(Ns,2)
        PanelIdx = [PanelIdx,Ns(1,i):Ns(2,i)];
    end
    Xs = [model.fe.AeroSurfaces(idx).CentroidsGlobal];
    res.Xs = round(Xs,10); % dealing with rounding errors
    res.Fx = FRes.F(PanelIdx,1);
    res.Fy = FRes.F(PanelIdx,2);
    res.Fz = FRes.F(PanelIdx,3);
    res.A = Areas';
    res.S = Spans';

end

