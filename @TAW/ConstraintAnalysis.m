function [obj] = ConstraintAnalysis(obj)
arguments
    obj
end
if obj.Size_Eng
    obj.Thrust = obj.ThrustToWeightRatio*obj.MTOM*9.81;
end
if ~obj.isWingAreaFixed && obj.Size_wing
    obj.WingArea = 1/obj.TargetWingLoading*(obj.MTOM*obj.Mf_Ldg);  
end

if obj.IsSweepDependent
    obj.SweepAngle = real(acosd(0.75.*obj.Mstar./obj.ADR.M_c));
    if obj.IsForwardSwept
        obj.SweepAngle = -obj.SweepAngle;
    end
else
    if isnan(obj.SweepAngle)
        error('Must have real value for wing sweep if set as independent')
    end
end

switch obj.WingIndependentVar
    case 'Span'
        obj.AR = obj.Span^2/obj.WingArea;
    case 'AR'
        obj.Span = sqrt(obj.AR*obj.WingArea);
end
end
