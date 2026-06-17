load('C:\git\Sprint0626\example_data\UB321_simple.mat')

%% ========================= Set Hyper-parameters =========================
ADP.AR = 12;
ADP.HingeEta = 0.8;
ADP.FlareAngle = 15;
ADP.ADR.M_c = 0.8;
ADP.SweepAngle = 25;

%% ============================ Re-run Sizing =============================
% conduct sizing
dcrg.printing.title('Example Surrogates','Length',60,'Symbol','$')
sizeOpts = util.SizingOpts(IncludeGusts=false,...
    IncludeTurb=false,BinFolder='bin_size');
[ADP,res_mtom,Lds,time,isError,Cases] = ADP.Aircraft_Sizing(sizeOpts);
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

save('example_data/UB321_simple_rerun.mat','ADP','Lds');

%% ======================== Get Mission Fuel Burn =========================
meta = ADP.ToMeta;
fh.printing.title(sprintf('Trip Fuel: %.3f t',meta.Fuel_trip./1e3))