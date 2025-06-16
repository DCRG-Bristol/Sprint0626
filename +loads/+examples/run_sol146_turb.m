load('example_data\A220_simple.mat')

%% update Hyper Paramters
ADP.AR = 12;
ADP.HingeEta = 0.8;
ADP.FlareAngle = 15;
ADP.ADR.M_c = 0.8;
ADP.SweepAngle = 25;

%% build the baff
ADP.BuildBaff();

%% run gusts
ld = loads.NastranModel(ADP);
lc = cast.LoadCase.Turbulence(ADP.ADR.M_c,ADP.ADR.Alt_cruise.*cast.SI.ft);
ld.SetConfiguration(IsLocked=true);
[Lds,BinFolder] = ld.TurbLoads(lc,1);

%% plot gust loads
% h5 = mni.result.hdf5(fullfile(BinFolder,'bin','sol146.h5'));
% get time series from gusts from wing root element
[Lds,f,S] = ld.ExtractTurbLoadsPSD(fullfile(BinFolder,'bin','sol146.h5'),ld.Tags(2),10);%change this number, was 1

figObj = fh.pubFig(Num=5,Size=[8,7],Layout=[1,1]);
plot(f,S)
ax = gca;
ax.YScale = "log";
ylabel('PSD?')
xlabel('Freq?')


