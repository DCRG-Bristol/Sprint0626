load('example_data\A220_simple.mat')

% ========================= Set Hyper-parameters =========================
load("+globalOpt\Trainingset_500.mat")
idx = find(TrainingSet(:,end)==0)';
ads.util.printing.title(sprintf('%.0f Errors',length(idx)))
idx = idx(1);
% idx =2;
disp(TrainingSet(idx,:))

ADP.AR = TrainingSet(idx,1);
ADP.HingeEta = TrainingSet(idx,2);
ADP.FlareAngle = TrainingSet(idx,3);
ADP.ADR.M_c = TrainingSet(idx,4);
ADP.SweepAngle = TrainingSet(idx,5); % if empty will link to mach number...
ADP.ConstraintAnalysis();
ADP.BuildBaff("Retracted",false);

f = figure(1);clf;ADP.Baff.draw(f);axis equal

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

if ~isfolder('example_data')
    mkdir('example_data');
end

save('example_data/A220_simple_rerun.mat','ADP','Lds');

%% ======================== Get Mission Fuel Burn =========================
[~,~,trip_fuel,trip_time] = ADP.MJperPAX(3000./cast.SI.Nmile,1);
fh.printing.title('','Length',60,'Symbol','=')
fh.printing.title(sprintf('Trip Fuel: %.3f t',trip_fuel./1e3),'Length',60,'Symbol','=')
fh.printing.title(sprintf('Trip Time: %.0f t',trip_time),'Length',60,'Symbol','=')
fh.printing.title(sprintf('MTOM: %.2f t',ADP.MTOM),'Length',60,'Symbol','=')