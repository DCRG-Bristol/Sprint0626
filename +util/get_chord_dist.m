function [ys,span,area,chords] = get_chord_dist(model,Tags)
arguments
    model
    Tags = ["wing_","Connector_"]
end
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
    Xs = round(Xs,10); % dealing with rounding errors
    A = Areas';
    S = Spans';
    ys = [unique(Xs(2,:))];
    span = 0;
    area = 0;
    for i = 1:length(ys)
        tmp_id = Xs(2,:) == ys(i);
        span = span + mean(S(tmp_id));
        area = area + sum(A(tmp_id));
        chords(i) = sum(A(tmp_id))./mean(S(tmp_id));
    end
    delta = (model.Taw.Span - (ys(end)-ys(1)))/2;
    ys = [ys(1)-delta,ys,ys(end)+delta];
    chords = [chords(1),chords,chords(end)];
end