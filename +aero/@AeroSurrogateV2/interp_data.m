function [CD] = interp_data(obj, Mach_in, Cl, Phase)
arguments
    obj
    Mach_in
    Cl
    Phase FlightPhase = FlightPhase.Cruise;
end


Mach = clip(Mach_in, 0.3, 0.85);
Mach_data = [obj.data_meta.Mach];
[~, idx] = min(abs(Mach_data - Mach));
% Step 2: Determine neighbouring indices
n = numel(Mach_data);
if idx == 1
    idx_range = 1:3;  % First 3 values
elseif idx == n
    idx_range = n-2:n;  % Last 3 values
else
    idx_range = idx-1:idx+1;  % Central 3 values
end

CLint = [0.2 0.3 0.4 0.5 0.6]'; NCLone = ones(length(CLint),1);

for i=1:length(idx_range)
    idata = load(obj.data_meta(idx_range(i)).File);

    iAR = obj.AR .*NCLone;
    iSwp = obj.SweepAngle .*NCLone;
    iCL = CLint;

    mrCDi(i,:) = interpn(idata.AR,idata.Swp,idata.CL,idata.Cdi,iAR,iSwp,iCL,'makima');
    mrCD0(i,:) = interpn(idata.AR,idata.Swp,idata.CL,idata.Cds,iAR,iSwp,iCL,'makima');

end

for i=1:length(CLint)
    wCD0_data(i) = interp1(Mach_data(idx_range),mrCD0(:,i),Mach,"makima");
    wCDi_data(i) = interp1(Mach_data(idx_range),mrCDi(:,i),Mach,"makima");
end

% Interp Data for specific Cl
SF = 1.2;
wCD0 = SF.*interp1(CLint,wCD0_data,Cl,"makima");
wCDi = SF.*interp1(CLint,wCDi_data,Cl,"makima");

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
