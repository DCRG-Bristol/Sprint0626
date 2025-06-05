load('example_data\A220_simple.mat')

%% ========================= Set Hyper-parameters =========================


ADP.AR = 18.6;
ADP.HingeEta = 0.7;
ADP.FlareAngle = 15;
ADP.ADR.M_c = 0.78;
ADP.SweepAngle = 10; % if empty will link to mach number...
ADP.ConstraintAnalysis();
ADP.BuildBaff;

f = figure(1);clf;ADP.Baff.draw(f);axis equal

%% ============================ Re-run Sizing =============================
% conduct sizing
ads.util.printing.title('Example Surrogates','Length',60,'Symbol','$')
SubHarmonic = [0.8,3000./cast.SI.Nmile];
sizeOpts = util.SizingOpts(IncludeGusts=true,...
    IncludeTurb=true,BinFolder='bin_size',SubHarmonic=SubHarmonic,Include1G=true);
[ADP,res_mtom,Lds,time,isError,Cases] = ADP.Aircraft_Sizing(sizeOpts,"SizeMethod","SAH");
% get data during cruise
fh.printing.title('Get Cruise Loads','Length',60)
[~,Lds_c]=ADP.StructuralSizing(...
    LoadCaseFactory.GetCases(ADP,sizeOpts,"Cruise"),sizeOpts);
Lds = Lds | Lds_c;
%save data
res = util.ADP2SizeMeta(ADP,'GFWT','Mano',1.5,Lds,time,isError,Cases);

if ~isfolder('example_data')
    mkdir('example_data');
end

save('example_data/A220_simple_rerun.mat','ADP','Lds');

%% ======================== Get Mission Fuel Burn =========================
ADP.LogCl = true;
ADP.SetConfiguration(PayloadFraction=0.8);
[~,~,trip_fuel,~] = ADP.MJperPAX(3000./cast.SI.Nmile,0.8);
fh.printing.title('','Length',60,'Symbol','=')
fh.printing.title(sprintf('Trip Fuel: %.3f t',trip_fuel./1e3),'Length',60,'Symbol','=')
fh.printing.title(sprintf('MTOM: %.2f t',ADP.MTOM),'Length',60,'Symbol','=')