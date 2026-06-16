
%% Size using Enforced Stuff
load('example_data\A220_simple.mat')
% ========================= Set Hyper-parameters =========================
ADP.AR = 15;
ADP.HingeEta = 0.7;
ADP.FlareAngle = 15;
ADP.ADR.M_c = 0.78;
ADP.SweepAngle = []; % if empty will link to mach number...
ADP.ConstraintAnalysis();
ADP.BuildBaff;
% ============================ Re-run Sizing =============================
% conduct sizing
ads.util.printing.title('Example Surrogates','Length',60,'Symbol','$')
SubHarmonic = [0.8,3000./cast.SI.Nmile];
sizeOpts = util.SizingOpts(IncludeGusts=false,...
    IncludeTurb=false,BinFolder='bin_size',SubHarmonic=SubHarmonic);
[ADP,res_mtom,Lds,time,isError,Cases] = ADP.Aircraft_Sizing(sizeOpts,"SizeMethod","SAH");


%% ========================= Run Nastran Proper ===========================

% build Nastran Object
ld = loads.NastranModel(ADP);
ld.BinFolder = 'bin_jig';
%build load cases
opts = util.SizingOpts(IncludeGusts=false,IncludeTurb=false,IncludeGround=false);
Cases = LoadCaseFactory.GetCases(ADP,opts,"SAH");
ld.GetLoads(Cases);