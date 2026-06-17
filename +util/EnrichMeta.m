function res = EnrichMeta(res)
for i = 1:length(res)
    if isprop(res(i).ADP,"PoddedFraction")
        res(i).WFF = res(i).ADP.PoddedFraction;
    else
        res(i).WFF = 0;
    end
    res(i).Span = round(res(i).Span,10);
    if isprop(res(i).ADP,"pTank_Eta")
        res(i).TankEta = res(i).ADP.pTank_Eta;
    else
        res(i).TankEta = nan;
    end
    res(i).MJperPAX = res(i).SpecificEnergy*res(i).Fuel_trip/(res(i).Range_harm*cast.SI.km)/res(i).PAX*1e3;
    res(i).WingMass = res(i).ADP.Masses.PrimaryWingMass + res(i).ADP.Masses.SecondaryWingMass + res(i).ADP.Masses.HingeMass;
    res(i).CD_c = res(i).CL_c/res(i).LD_c;
    [rho,a] = dcrg.aero.atmos(res(i).ADP.ADR.Alt_cruise);
    res(i).Drag = 0.5*rho*(res(i).ADP.ADR.M_c*a)^2*res(i).ADP.WingArea*res(i).CD_c;
    res(i).Drag0 = 0.5*rho*(res(i).ADP.ADR.M_c*a)^2*res(i).ADP.WingArea*res(i).CD0;
    res(i).Dragi = res(i).Drag - res(i).Drag0;
    res(i).FuelMass = res(i).Fuel_trip + res(i).ADP.Masses.FuelTanks + res(i).ADP.Masses.FuelSys;
    res(i).SF = res(i).NominalSafetyFactor;
    res(i).Flare = res(i).ADP.FlareAngle;
    if isprop(res(i).ADP,"FlareAngle")
        res(i).Flare = res(i).ADP.FlareAngle;
    else
        res(i).Flare = nan;
    end
    if isprop(res(i).ADP,"PodQ")
        res(i).PodQ = res(i).ADP.PodQ;
    else
        res(i).PodQ = nan;
    end
end
end

