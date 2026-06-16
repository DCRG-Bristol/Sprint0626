function [CDw] = Shevell(obj, Mach, CL)
    % Constants
    kappa = obj.Taw.Mstar;         % Aerofoil technology factor
    toc = obj.CDw_t2c;
    SweepAngle = obj.SweepAngle * pi / 180;

    % Drag divergence Mach number
    Mdd = (kappa - toc / cos(SweepAngle) - CL / (10 * cos(SweepAngle)^2)) / cos(SweepAngle);

    % Shevell parameters (based on A320)
    aconst = 0.000885;
    bconst = 3.734;

    % Critical Mach number
    denom = 0.002 / (aconst * cos(SweepAngle)^3);
    Mcrit = (bconst * Mdd) / (atan(denom) + bconst);

    % Normalised drag function and derivative
    fCDw = @(MoMcrit) cos(SweepAngle)^3 * aconst * tan(bconst * MoMcrit - bconst);
    dfCDw = @(MoMcrit) cos(SweepAngle)^3 * aconst * bconst * sec(bconst * MoMcrit - bconst).^2;

    % Transition point setup
    near1 = 0.98;
    MoMcritT = near1 * (1 + pi / (2 * bconst));   % Normalised Mach/Mcrit
    MachT = MoMcritT * Mcrit;                     % Actual Mach at spline start

    % Compute CDw
    if Mach / Mcrit < 1
        CDw = 0.0;

    elseif Mach < MachT
        CDw = fCDw(Mach / Mcrit);

    else
        % Transition point and max point
        p1 = [MachT, fCDw(MoMcritT)];
        p2 = [1, obj.CDw_max];

        dp1 = dfCDw(MoMcritT) / Mcrit;
        dp2 = 0.1;
        CDw = hSpline(p1, p2, dp1, dp2, Mach);
    end

    CDw = max(0, CDw);
end

function y = hSpline(p1, p2, m1, m2, x)
    % Cubic Hermite spline between two 2D points
    x1 = p1(1); y1 = p1(2);
    x2 = p2(1); y2 = p2(2);
    dx = x2 - x1;
    t = (x - x1) / dx;

    % Hermite basis functions
    h00 = 2 * t^3 - 3 * t^2 + 1;
    h10 = t^3 - 2 * t^2 + t;
    h01 = -2 * t^3 + 3 * t^2;
    h11 = t^3 - t^2;

    y = h00 * y1 + h10 * dx * m1 + h01 * y2 + h11 * dx * m2;
end
