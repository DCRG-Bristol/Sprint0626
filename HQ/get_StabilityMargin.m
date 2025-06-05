function hn = get_StabilityMargin(obj,opts)
arguments
    obj
    opts.IsLocked = false;
end
%GET_STABILITYMARGIN Summary of this function goes here
%   Detailed explanation goes here

% make a manouvre load case (see LoadCaseFactory)
M = obj.Taw.ADR.M_c;
Alt = obj.Taw.ADR.Alt_cruise.*cast.SI.ft; %ft
Load_factor = 1; %G
LoadCase = cast.LoadCase.Manoeuvre(M,Alt,Load_factor,SafetyFactor=1);

[CLs0,~] = obj.StabilityMargin(LoadCase,IsLocked=opts.IsLocked,aoa=2);
[CLs1,~] = obj.StabilityMargin(LoadCase,IsLocked=opts.IsLocked,aoa=4);

a=(CLs1(1)-CLs0(1))/(deg2rad(2));
at=(CLs1(2)-CLs0(2))/(deg2rad(2));

hn=0.25+at/a*obj.Taw.V_HT;

end

