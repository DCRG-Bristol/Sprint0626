function StaticStabilityCorrections(obj)
%STATICSTABILITYCORRECTIONS Summary of this function goes here
%   Detailed explanation goes here
ar = obj.AR;
he = obj.HingeEta;
fa = obj.FlareAngle;
Mc = obj.ADR.M_c;
sa = obj.SweepAngle;

SM_func = @(ar,he,fa,Mc,sa)0.35;

obj.StaticMargin = SM_func(ar,he,fa,Mc,sa);


obj.V_HT = 1.4626;
obj.V_VT = 0.0847;
end

