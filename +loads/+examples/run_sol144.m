load('example_data\A220_simple.mat')

% rebuild baff
ADP.BuildBaff();

% set aircraft configuration
ld = loads.NastranModel(ADP);
ld.SetConfiguration();
ld.CleanUp = false;

% make a manouvre load case (see LoadCaseFactory)
M = 0.75;
Alt = 32000; %ft
Load_factor = 1; %G
LoadCase = cast.LoadCase.Manoeuvre(M,Alt,Load_factor,SafetyFactor=1);

% run analysis (assumes nastran 2023 or later)
[Lds,BinFolder] = ld.StaticLoads(LoadCase,1);

% plot Bending Moment
f = fh.pubFig(Num=1);clf;
clf;
grid on
Lds.plot("My",ADP.WingBoxParams);

% plot deflecton (you can pan the figure by clicking and dragging the mouse)
ads.nast.plot.sol144(BinFolder);


% plot lift dist

filename = fullfile(BinFolder,'bin','sol144.h5');
%extract trimAoA
resFile = mni.result.hdf5(filename);
[ys,~,~,Fs,~,~,chords] = util.get_lift_dist(ld,resFile,[[ld.Taw.MainWingRHS.Name],[ld.Taw.MainWingLHS.Name]]);

f = fh.pubFig(Num=10);clf;
plot(ys,Fs);









