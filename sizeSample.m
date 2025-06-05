function output = sizeSample(input,saveMat,printoutput)

fuel_price = 0.64995; % USD/kg
oil_price = 30.0; % USD/kg
range_mission = 3000./(cast.SI.Nmile); % range of mission [km]
N_pax = 140; % Number of passengers
N_eng = 2; % Number of engines

% This function does the sizing for one sample of input parameters
load('example_data/A220_simple.mat')
ADP.AR = input(1);
ADP.HingeEta = input(2);
ADP.FlareAngle = input(3);
ADP.ADR.M_c = input(4);
ADP.SweepAngle = input(5);
%% ============================ Re-run Sizing =============================
% conduct sizing
ads.util.printing.title('Example Surrogates','Length',60,'Symbol','$')
SubHarmonic = [0.8,3000./cast.SI.Nmile];
sizeOpts = util.SizingOpts(IncludeGusts=false,...
    IncludeTurb=false,BinFolder='bin_size',SubHarmonic=SubHarmonic);
[ADP,res_mtom,Lds,time,isError,Cases] = ADP.Aircraft_Sizing(sizeOpts,"SizeMethod","SAH");
% get data during cruise
fh.printing.title('Get Cruise Loads','Length',60)
[~,Lds_c]=ADP.StructuralSizing(...
    LoadCaseFactory.GetCases(ADP,sizeOpts,"Cruise"),sizeOpts);
Lds = Lds | Lds_c;
%save data
res = util.ADP2SizeMeta(ADP,'GFWT','Mano',1.5,Lds,time,isError,Cases);

[doc,M_f,trip_fuel,t_bl,block_fuel] = ADP.MJperPAX(range_mission,0.8);

t_bl = t_bl/3600;
%% ============================ Operating Cost Calculation ================
% fuel and oil costs
% C_fuel and C_oil [USD per seat per km]
C_fuel = block_fuel * fuel_price / range_mission / N_pax;

% speed of sound at cruise level [m/s]
[rho,a,~,P] = ads.util.atmos(34e3./cast.SI.ft);
% true air speed at cruise level [m/s]
TAS = a * ADP.ADR.M_c;

% mission time in hours
% t_bl = range_mission * 1000 / (TAS * 3600);
C_oil = 0.7 * N_eng * t_bl * oil_price / range_mission / N_pax;

% flight crew costs

% salary per year
salary_Captain = 277000;
salary_FirstOfficer = 188000;
salary_CabinCrew = 43160;

salary_crew = 1.0 * salary_Captain ...
    + 1.0 * salary_FirstOfficer ...
    + 3.0 * salary_CabinCrew;

% Velocity in [km/hour]

V_bl = range_mission / t_bl;
C_crew = ((1+0.26)*salary_crew/1000. + 9)/(N_pax * V_bl);

% insurance & maintenance cost
% USD 1500 per flight hour
C_other = 1500*t_bl/3600. / (N_pax * range_mission);

% Total operating cost (per pax per km)
C_ops = C_fuel + C_oil + C_crew + C_other;


if ~isfolder('example_data')
    mkdir('example_data');
end
if saveMat
    save(['example_data/A220_simple_rerun_' num2str(i) '.mat'],'ADP','Lds');
end

if printoutput
    %% ======================== Get Mission Fuel Burn =========================
    
    fh.printing.title('','Length',60,'Symbol','=')
    fh.printing.title(sprintf('Trip Fuel: %.3f t',Fuel_trip./1e3),'Length',60,'Symbol','=')
    fh.printing.title(sprintf('Block Fuel: %.3f t',block_fuel./1e3),'Length',60,'Symbol','=')
    fh.printing.title(sprintf('MTOM: %.2f t',ADP.MTOM),'Length',60,'Symbol','=')

    %% ======================== Get Operating Cost  ===========================
    fh.printing.title('','Length',60,'Symbol','=')
    fh.printing.title(sprintf('Operating Cost: %d USD per seat per km',C_ops),'Length',60,'Symbol','=')
    
end
output = [block_fuel,C_ops,ADP.Span*ADP.HingeEta,ADP.Span];
end