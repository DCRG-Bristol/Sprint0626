function e = EstimateOswald(obj,Mach,Method)
arguments
    obj
    Mach
    Method string {mustBeMember(Method,["Obert","Schaufele","NitaCompressible","Nita","NitaNastran"])}
end
KeM = 1;
switch Method
    case "Obert"
        Q = 1.05;
        P = 0.007;
    case "Schaufele"
        Q = 1.03;
        P = 0.38*obj.CD0;
    case "NitaCompressible"
        [~,Q,P,KeM] = obj.NitaOswald(Mach);
    case "Nita"
        [~,Q,P,~] = obj.NitaOswald(Mach);
    case "NitaNastran"
        [~,Q,P,~] = obj.NitaNastranOswald(Mach);
end
e = KeM/(Q+P*pi*obj.AR);
% geometric considerations
KeGamma = (1/cosd(obj.Taw.Dihedral))^2; % (Eq. 49) from Nita
%winbglet consideration
KeWinglet = (1+2/3.29*obj.Taw.WingletHeight/obj.Taw.Span)^2;

e = e * KeGamma * KeWinglet;
% e = e * 1.1; % factor to get it to match A320
end

