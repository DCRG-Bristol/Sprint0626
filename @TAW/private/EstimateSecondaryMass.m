function [M_secondary] = EstimateSecondaryMass(ADP,wing,p_slat,S_flap,S_ail,FowlerSlots,refMass,refSpan,Misc)
arguments
    ADP
    wing
    p_slat
    S_flap
    S_ail
    FowlerSlots double {mustBeInRange(FowlerSlots,1,2)} = 1;
    refMass = ADP.MTOM;
    refSpan = sum(arrayfun(@(x)x.GetBeamLength,ADP.MainWingRHS))
    Misc = 0.1;
end
%ESTIMATESECONDARYMASS Summary of this function goes here
%   Detailed explanation goes here

% get Wing structural length

sigma_ref = 56;
S_ref = 10;

S = wing.PlanformArea;

% dive dyanamic pressure
[rho,a] = dcrg.aero.atmos(ADP.ADR.Alt_cruise);
M_d = ADP.ADR.M_c+0.05;
q_d = 0.5*rho*(a*M_d)^2;

% fixed LE Structure
sigma_fle = 3.15*(q_d/30e3)^0.25*(refMass*refSpan/5e7)^0.145;  % eq.11.63 Torenbeek
sigma_fle = sigma_fle*(1*(1-p_slat) + 1.3*(p_slat));
M_fle = 0.15*S*sigma_fle/9.81;

%LE HLD
S_slat = 0.15*S*p_slat;
sigma_slat = 4.83*sigma_ref*(S_slat/S_ref)^0.183; % eq.11.64 Torenbeek % assuming slat area same as storage area and ta 
M_slat =  S_slat*sigma_slat/9.81;

% fixed TE Structure
p_flap = S_flap/(0.35*S);
if p_flap>1
    % dcrg.printing.title([sprintf('WARNING - Flap Percentage %.0f',p_flap*100),'%%'],'Length',60);
end

sigma_fte = 2.6*sigma_ref*(refMass*refSpan/5e7)^0.0544;
sigma_sup = dcrg.tern(FowlerSlots == 1,40,100);
sigma_fte = p_flap*(sigma_fte+sigma_sup) + max((1-p_flap),0)*sigma_fte; % eq.11.65 Torenbeek
M_fte = (1-0.65)*S*sigma_fte/9.81;

% TE flap
if S_flap>0
    k_sup = 1.6; % assumes fowler flaps
    k_slot = dcrg.tern(FowlerSlots == 1,1,1.5);
    sigma_flap = 1.7*k_sup*k_slot*sigma_ref*(1+(refMass/1e6)^0.35);
    M_flap = S_flap*sigma_flap/9.81; % eq 11.66 Torenbeek
else
    M_flap = 0;
end

% aileron 
if S_ail >0
    sigma_ail = 3*sigma_ref*1.3*(S_ail/S_ref)^0.044;
    M_ail = S_ail*sigma_ail/9.81;
else
    M_ail = 0;
end

M_secondary = M_fle + M_slat + M_fte + M_flap + M_ail;

% Misc Weight = 
M_secondary = M_secondary*(1+Misc);
end

