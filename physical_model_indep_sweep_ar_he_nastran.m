function Y = physical_model_indep_sweep_ar_he_nastran(X)
%% Title section - Block fuel (BF) and Direct operating cost (DOC) computations for the swept wing case
%{
--------------------------------------------------------
Comments:
* The model computes the block fuel, direct operating cost, ... as a function of design variables (i.e., Sweep angle, Mach no., AR, Hinge Eta, and Flare Angle)
* We use a UQLab style notation, i.e., X: vector of design variables; Y: vector of model outputs
* This model (and its surrogate approximation) will be used for design space exploration and global optimisation
--------------------------------------------------------
Input:
* X: design variables
    * X(1)      : Sweep angle
    * X(2)      : Mach number
    * X(3)      : aspect ratio (AR)
    * X(4)      : Hinge Eta
--------------------------------------------------------
Output:
* Y: vector of quantities of interest (QIs)
    * Y(1)      : block fuel (BF) 
    * Y(2)      : direct operating cost (DOC)
    * Y(3)      : Wingspan
    ...
    * Y(7)      : MTOM
--------------------------------------------------------
%}

%%
fuel_price = 0.64995; % USD/kg
oil_price = 30.0; % USD/kg
range_mission = 3000./(cast.SI.Nmile); % range of mission [km]
N_pax = 140; % Number of passengers
N_eng = 2; % Number of engines

% This function does the sizing for one sample of input parameters
load('example_data/UB321_simple_nastran_gusts.mat')
ADP.IsSweepDependent = false;
% ADP.LoadsSurrogateType = "Enforced";
ADP.LoadsSurrogateType = "Nastran";
ADP.WingIndependentVar = "AR";
ADP.isWingAreaFixed = false;

ADP.AR = X(3);
ADP.HingeEta = 1;
ADP.FlareAngle = 15;
ADP.ADR.M_c = X(2);
ADP.SweepAngle = X(1);

%% ============================ Re-run Sizing =============================
% conduct sizing
ads.util.printing.title('Example Surrogates','Length',60,'Symbol','$')

% SubHarmonic = [0.8,3000./cast.SI.Nmile];
% sizeOpts = util.SizingOpts(IncludeGusts=true,...
%     IncludeTurb=false,BinFolder='bin_size',SubHarmonic=SubHarmonic);

SubHarmonic = [16/19.28,6000./cast.SI.km];
sizeOpts = util.SizingOpts(IncludeGusts=true,...
    IncludeTurb=false,BinFolder='bin_size',SubHarmonic=SubHarmonic);

if ADP.HingeEta == 1
    [ADP,res_mtom,Lds,time,isError,Cases] = ADP.Aircraft_Sizing(sizeOpts,"SizeMethod","Baseline");
else 
    [ADP,res_mtom,Lds,time,isError,Cases] = ADP.Aircraft_Sizing(sizeOpts,"SizeMethod","SAH");
end
% get data during cruise
fh.printing.title('Get Cruise Loads','Length',60)
[~,Lds_c]=ADP.StructuralSizing(...
    LoadCaseFactory.GetCases(ADP,sizeOpts,"Cruise"),sizeOpts);
Lds = Lds | Lds_c;
%save data
res = util.ADP2SizeMeta(ADP,'GFWT','Mano',1.5,Lds,time,isError,Cases);

ADP.LogCl = true;
ADP.SetConfiguration(PayloadFraction=0.8);
[doc,M_f,trip_fuel,t_bl,block_fuel] = ADP.MJperPAX(range_mission,0.8);

t_bl = t_bl/3600;

%% ============================ Operating Cost Calculation ================
% fuel and oil costs
% C_fuel and C_oil [USD per seat per km]
C_fuel = block_fuel * fuel_price * 1000/ (range_mission * N_pax);

% speed of sound at cruise level [m/s]
[rho,a,~,P] = ads.util.atmos(34e3./cast.SI.ft);
% true air speed at cruise level [m/s]
TAS = a * ADP.ADR.M_c;

% mission time in hours
% t_bl = range_mission * 1000 / (TAS * 3600);
C_oil = 0.7 * N_eng * t_bl * oil_price * 1000/ range_mission / N_pax;

% flight crew costs

% salary per year
salary_Captain = 277000;
salary_FirstOfficer = 188000;
salary_CabinCrew = 43160;

salary_crew = 1.0 * salary_Captain ...
    + 1.0 * salary_FirstOfficer ...
    + 3.0 * salary_CabinCrew;

% Velocity in [km/hour]

V_bl = range_mission / (t_bl*1000);
C_crew = ((1+0.26)*salary_crew/1000. + 9)/(N_pax * V_bl);

% insurance & maintenance cost
% USD 1500 per flight hour
C_other = 1500*t_bl*1000. / (N_pax * range_mission);

% Total operating cost (per pax per km)
C_ops = C_fuel + C_oil + C_crew + C_other;

%% collate outputs
% cruise condition
M_c = X(2);
[rho,a] = ads.util.atmos(ADP.ADR.Alt_cruise);
Cl_cruise = ADP.MTOM*ADP.Mf_TOC*9.81/(0.5*rho*(M_c*a)^2*ADP.WingArea);
% estimate cd0 and cd_cruise
cd0 = ADP.AeroSurrogate.Get_Cd(0,X(2),FlightPhase.Cruise);
cd_cruise = ADP.AeroSurrogate.Get_Cd(Cl_cruise,X(2),FlightPhase.Cruise);
% collate data
Y = [block_fuel,C_ops,ADP.Span,ADP.Span*ADP.HingeEta,cd0,cd_cruise,ADP.MTOM];

end