function [CD] = interp_data(obj, Mach_in, Cl, Phase)
arguments
    obj
    Mach_in
    Cl
    Phase FlightPhase = FlightPhase.Cruise;
end
% Mach check for data set
% Run interpolation ...
failed = false;

Mach = clip(Mach_in, 0.5, 0.85);
if Mach < 0.6
    CLint = [0.3 0.4 0.5 0.6 0.7 0.8]; NCLone = ones(length(CLint),1);
    % interp data for CD0 and CDi
    idat = obj.data_ascent;
    int_data = [[idat.AR]', [idat.SweepAngle]', [idat.Mach]', [idat.Cl]'];
    query_data = [obj.AR.*NCLone, obj.SweepAngle.*NCLone, Mach.*NCLone, CLint'];

    wCDi_data = griddatan(int_data,[idat.CD_induced]',query_data,"linear");
    wCD0_data = griddatan(int_data,[idat.CD_surface]',query_data,"linear");
    if sum(~isnan(wCDi_data)) <= 1
        % wCDi_data = griddatan(int_data,[idat.CD_induced]',query_data,"nearest"); % nothing wrong with c0 continuity
        % wCD0_data = griddatan(int_data,[idat.CD_surface]',query_data,"nearest");
        failed = true; 
    end
else
    CLint = [0.41 0.5 0.59]; NCLone = ones(length(CLint),1);
    % interp data for CD0 and CDi
    idat = obj.data_cruise;
    int_data = [[idat.AR]', [idat.SweepAngle]', [idat.Mach]', [idat.Cl]'];
    query_data = [obj.AR.*NCLone, obj.SweepAngle.*NCLone, Mach.*NCLone, CLint'];

    wCDi_data = griddatan(int_data,[idat.CD_induced]',query_data,"linear");
    wCD0_data = griddatan(int_data,[idat.CD_surface]',query_data,"linear");
    if sum(~isnan(wCDi_data)) <= 1
        % wCDi_data = griddatan(int_data,[idat.CD_induced]',query_data,"nearest"); % nothing wrong with c0 continuity
        % wCD0_data = griddatan(int_data,[idat.CD_surface]',query_data,"nearest");
        failed = true; 
    end
end

if failed % DON'T LOOK AT THIS FINTAN
    newADP = aero.NitaShevellPolar(obj.Taw);
    CD = newADP.Get_Cd(Cl,Mach_in,Phase);
    return
end

% Interp Data for specific Cl
igud = ~isnan(wCD0_data);
wCD0 = interp1(CLint(igud),wCD0_data(igud),Cl,"makima");
wCDi = interp1(CLint(igud),wCDi_data(igud),Cl,"makima");

w_eO = Cl^2 / (pi * obj.AR * wCDi);

meta = obj.CD0_meta_c;
CD0_sum = wCD0;
for i=1:length(meta)
    if contains(meta(i).Name,"fuselage")
        CD0_sum = CD0_sum + meta(i).CD0;
    elseif contains(meta(i).Name,"engine")
        CD0_sum = CD0_sum + meta(i).CD0;
    elseif contains(meta(i).Name,"HTP")
        CD0_sum = CD0_sum + meta(i).CD0;
    elseif contains(meta(i).Name,"VTP")
        CD0_sum = CD0_sum + meta(i).CD0;
    end
end

switch Phase
    case FlightPhase.Cruise
        CD0 = CD0_sum * (1 + obj.ProturbanceDrag);
        CD = CD0 + wCDi;
    case FlightPhase.Landing
        eO = w_eO-0.1;
        CD0 = CD0_sum + CD0_sum * 0.03 + 0.085;
        CD = CD0 + Cl^2/(pi*obj.AR*eO);
    case FlightPhase.Approach
        eO = w_eO - 0.075;
        CD0 = CD0_sum + CD0_sum*0.03 + 0.06;
        CD = CD0 + Cl^2/(pi*obj.AR*eO);
    case FlightPhase.Takeoff
        eO = w_eO-0.05;
        CD0 = CD0_sum + CD0_sum*0.03 + 0.04;
        CD = CD0 + Cl^2/(pi*obj.AR*eO);
end

end
