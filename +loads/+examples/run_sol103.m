load('example_data\A220_simple.mat')

% rebuild baff
ADP.BuildBaff();

% set aircraft configuration
ld = loads.NastranModel(ADP);
ld.SetConfiguration(IsLocked=true);
[res,BinFolder] = ld.Sol103();

ads.nast.plot.sol103(char(BinFolder),1)

% % plot Bending Moment
% f = figure(1);
% clf;
% grid on
% Lds.plot("My",ADP.WingBoxParams);
% 
% % plot deflecton (you can pan the figure by clicking and dragging the mouse)
% ads.nast.plot.sol144(BinFolder);
% 
% 
% % plot lift dist
% 
% filename = fullfile(BinFolder,'bin','sol144.h5');
% %extract trimAoA
% resFile = mni.result.hdf5(filename);
% [ys,~,~,Fs,~,~,chords] = util.get_lift_dist(ld,resFile,[[ld.Taw.MainWingRHS.Name],[ld.Taw.MainWingLHS.Name]]);
% 
% f = figure(10);clf;
% plot(ys,Fs);









