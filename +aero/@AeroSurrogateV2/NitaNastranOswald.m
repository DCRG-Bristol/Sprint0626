function [e,Q,P,KeM] = NitaNastranOswald(obj,Mach)
%NITAOSWALD uses method from "Estimating the Oswald factor from Basic Aircraft Geometrical Paramters"
% to estimate oswald efficency factor of a Baff Aircraft
fus = obj.Taw.Baff.BluffBody(1);
%viscous corrections (Eq. 40 and Eq. 39b)
KeF = 1-2*(max([fus.Stations.Radius])*2/fus.EtaLength)^2; % fuselage factor (Eq. 40)
ae = -0.001521;
be = 10.82;
KeM = ads.util.tern(Mach<=0.3,1,ae*(Mach/0.3-1)^be+1); % Compressibility factor (Eq. 41)

Q = 1/(obj.e_theo*KeF);
P = 0.38*obj.CD0_c;
e = KeM/(Q+P*pi*obj.AR);

% geometric considerations
% KeGamma = (1/cosd(obj.Dihedral))^2; % (Eq. 49)
% e = e * KeGamma;
end

