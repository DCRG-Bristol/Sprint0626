clear all
fclose all;
close all;
cruise_alt = 34e3./cast.SI.ft;
alternate_dist = 325e3;

bin_folder = 'bin_a220_ja1';
%% load A321
% set parameters
% ADP.WingBoxParams = cast.size.WingBoxSizing.empty;

%misson settings
ADP = TAW();
ADP.ADR = cast.ADR.A320(140,2500,16e3);
ADP.ADR.M_c = 0.8;
ADP.ADR.Alt_cruise = cruise_alt;
ADP.ADR.Range_alternate = alternate_dist;
ADP.N_seatsPerRow = 5;

ADP.Engine = cast.config.Engine.CFM_LEAP_1A(1,cruise_alt,ADP.ADR.M_c);

%wing settings
ADP.RibPitch = 0.8;
ADP.WingBeamElements = 60;
ADP.WingletHeight = 0;
ADP.WingIndependentVar = "AR";
ADP.AR = 11;
ADP.IsSweepDependent = true;

%hinge setting
ADP.HingeEta = 1;
ADP.IsLightHinge = false;

%Empenage Settings
ADP.V_HT = 1.4626;
ADP.V_VT = 0.0847;
ADP.HTP_TCR_root = 0.15;
ADP.SizeEmpenage = true;

ADP.WingArea = 112.3;
ADP.isWingAreaFixed = false;
ADP.TargetWingLoading = 500;

ADP.ThrustToWeightRatio = 0.33;
ADP.ProturbanceDrag = 0.019;
ADP.FowlerSlots = 1;
ADP.SecondaryMethod = "Planform";

% fuel settings
ADP.ExtraFuel = 0;

%% inital mass estimate
%initial mission analysis to estimate MTOM
mission = cast.Mission.StandardWithAlternate(ADP.ADR);
[EWF,fs] = cast.weight.MissionFraction(mission.Segments,ADP);
val = @(x) 1.1166 - 0.0516*log(x)+(ADP.ADR.Payload+ADP.ADR.CrewMass)/x-EWF; % from database
ADP.MTOM = fminsearch(@(x)val(x)^2,0);
ADP = ADP.MissionAnalysis(OverideLD=false);

fprintf('\n\n%.0f kg\n',ADP.MTOM);
fprintf('Block Fuel: %.1f Tn\n',(1-prod(fs))*93.5);
fprintf('Trip Fuel: %.1f Tn\n',(1-prod(fs([1:5,10,11])))*93.5);

%% sizing Mano
res = [];
% now size with DLM for manouevres only
ads.util.printing.title('Example Surrogates','Length',60,'Symbol','$')
SubHarmonic = [0.8,3000./cast.SI.Nmile];
sizeOpts = util.SizingOpts(IncludeGusts=false,IncludeTurb=false,BinFolder=bin_folder,SubHarmonic=SubHarmonic);
[ADP,res_mtom,Lds,time,isError,Cases] = ADP.Aircraft_Sizing(sizeOpts);
% get data during cruise
fh.printing.title('Get Cruise Loads','Length',60)
[~,Lds_c]=ADP.StructuralSizing(LoadCaseFactory.GetCases(ADP,sizeOpts,"Cruise"),sizeOpts);
Lds = Lds | Lds_c;
%save data
tmp_stats = util.ADP2SizeMeta(ADP,'GFWT','Mano',1.5,Lds,time,isError,Cases);
res = dcrg.struct.concat(res,tmp_stats);

if ~isfolder('example_data')
    mkdir('example_data');
end
save('example_data/A220_simple.mat','ADP','Lds');



%% res
meta = ADP.ToMeta;
fh.printing.title('','Length',60,'Symbol','=')
fh.printing.title(sprintf('Trip Fuel: %.3f t',meta.Fuel_trip./1e3),'Length',60,'Symbol','=')
fh.printing.title(sprintf('MTOM: %.2f t',ADP.MTOM),'Length',60,'Symbol','=')

f = fh.pubFig("Size",[14,14]);clf;
ADP.BuildBaff(Retracted=false);
ADP.Baff.draw(f,"Type","mesh");
axis equal