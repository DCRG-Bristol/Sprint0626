load('example_data\A220_simple.mat')

%% ========================= Set Hyper-parameters =========================
ADP.AR = 13.7475;%12;
ADP.HingeEta =0.6657; %.7;
ADP.FlareAngle = 5.00;%15;
ADP.ADR.M_c = 0.85;%0.78;
ADP.SweepAngle = 38.53;%[]; % if empty will link to mach number...


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
meta = ADP.ToMeta;
fh.printing.title('','Length',60,'Symbol','=')
fh.printing.title(sprintf('Trip Fuel: %.3f t',meta.Fuel_trip./1e3),'Length',60,'Symbol','=')
fh.printing.title(sprintf('MTOM: %.2f t',ADP.MTOM),'Length',60,'Symbol','=')