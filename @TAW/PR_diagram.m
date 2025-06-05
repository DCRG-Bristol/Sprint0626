function [r,p,M_to] = PR_diagram(obj)
% OEM = obj.Baff.GetOEM();
PayloadCapacity = sum([obj.Baff.Payload.Capacity]);
FuelCapacity = sum([obj.Baff.Fuel.Capacity]);
% get design fuel
%estimate design fuel
mission = cast.Mission.StandardWithAlternate(obj.ADR);
M_to = 0;
M_f = FuelCapacity;
while abs(M_to-(obj.OEM+obj.ADR.Payload+M_f))>10
    M_to = obj.OEM+obj.ADR.Payload+M_f;
    [EWF,fs] = cast.weight.MissionFraction(mission.Segments,obj,M_TO=M_to,OverideLD=true);
    M_f =  (1-EWF)/(EWF)*(obj.OEM+obj.ADR.Payload);
end
if M_f > FuelCapacity
    MTOM = obj.OEM+PayloadCapacity+FuelCapacity;
    if (fuelMass(0,obj,MTOM)-FuelCapacity)>0
        % Aircraft in unflyable as not enough fuel for reserve mission....
        r = [0,0,0,0];
        p = [1,1,1,0]*PayloadCapacity;
        return
    end
    A_r = fzero(@(x)fuelMass(x,obj,MTOM)-FuelCapacity,[0,obj.ADR.Range]);
else
    MTOM = obj.OEM+PayloadCapacity+M_f;
    A_r = obj.ADR.Range;
end
M_P_A = PayloadCapacity;
M_f_A = M_f;
% M_TO_A = MTOM;

% get point C (Max. fuel + payload upto MTOM)
M_TO_C = min(obj.OEM+FuelCapacity,MTOM);
M_f_C = M_TO_C-obj.OEM;
M_P_C = 0;
C_r = fzero(@(x)fuelMass(x,obj,M_TO_C)-M_f_C,[A_r,A_r*10]);

% get point B (Max. fuel + payload upto MTOM)
M_TO_B = MTOM;
if M_f_A>=(FuelCapacity-10) || MTOM-M_f_C-obj.OEM  == 0
    M_P_B = M_P_A;
    B_r = A_r;
else
    % M_f = M_f_C;
    M_P_B = MTOM-M_f_C-obj.OEM;
    B_r = fzero(@(x)fuelMass(x,obj,M_TO_B)-M_f_C,[A_r,C_r]);
end

% tidy up 
r = [0,A_r,B_r,C_r].*cast.SI.Nmile;
p = [PayloadCapacity,M_P_A,M_P_B,M_P_C];

end

function M_Fuel = fuelMass(range,obj,M_TO)
    ADR = obj.ADR;
    mission = cast.Mission.StandardWithAlternate(ADR,range);
    [EWF,fs] = cast.weight.MissionFraction(mission.Segments,obj,"M_TO",M_TO,"OverideLD",true);
    M_Fuel = (1-EWF)*M_TO;
end

