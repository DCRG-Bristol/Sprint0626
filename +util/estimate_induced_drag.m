function res = get_induced_drag(model,resFile,Mach,Alt,Tags,alpha_i_ext)
arguments
    model
    resFile;
    Mach
    Alt
    Tags
    alpha_i_ext=@(x)zeros(size(x));
end
    [rho,a,T,P,~,~,~] = dcrg.aero.atmos(Alt./cast.SI.ft);
    V = a*Mach;
    q = 0.5*rho*V^2;

    [ys,Cps,~,Fs,~,area] = util.get_lift_dist(model,resFile,Tags);

    b = ys(end)-ys(1);
    thetas = acos(2*ys/b);
    ns = (1:15)';
    gamma = Fs./(rho*V);
    [~,a,~] = util.Fseries(thetas,gamma./(2*b*V),ns(end),false,'s');

    y = linspace(ys(1),ys(end),1001);
    theta = acos(2*y/b);
    
    alpha_i = zeros(size(theta));
    gamma_i = zeros(size(theta));

    for i = 1:length(alpha_i)
        if sin(theta(i)) == 0
            alpha_i(i) = 0;
            gamma_i(i) = 0;
        else
            alpha_i(i) = sum(ns.*a.*sin(ns.*theta(i))./sin(theta(i)));
            gamma_i(i) = 2*b*V*sum(a.*sin(ns.*theta(i)));
        end
    end
    res = struct();
    res.alpha_is = alpha_i + alpha_i_ext(y);
    res.D_is = rho*V*alpha_i.*gamma_i;
    res.Ls = rho*V*gamma_i;
    res.Cps = interp1(ys,Cps,y);
    res.ys = y;
    res.L =  trapz(y,res.Ls);
    res.Di = trapz(y,res.D_is);
    res.CL = res.L/(q*area);
    res.CDi = res.Di/(q*area);
    res.q = q;
    res.area = area;
end