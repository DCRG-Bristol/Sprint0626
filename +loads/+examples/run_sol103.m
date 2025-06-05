load('example_data\A220_simple.mat')

% rebuild baff
ADP.inclFlutterMass = false;
ADP.BuildBaff();

% set aircraft configuration
ld = loads.NastranModel(ADP);
ld.SetConfiguration(IsLocked=true);
[res,BinFolder] = ld.Sol103();


%%make model
[model,res_modeshape,res_freq]=ads.nast.plot.sol103(char(BinFolder),1);

% plot other modes
% get modal data
    % f06 = mni.result.f06(fullfile(BinFolder,'bin','sol103.f06'));
    % res_modeshape = f06.read_modeshapes;
    % res_freq = f06.read_modes;
    %% apply deformation result
    modeshape_num = 6;
    [~,i] = ismember(model.GRID.GID,res_modeshape.GID(modeshape_num,:));
    model.GRID.Deformation = [res_modeshape.T1(modeshape_num,i);...
        res_modeshape.T2(modeshape_num,i);res_modeshape.T3(modeshape_num,i)];
    res_freq(modeshape_num).cycles
    model.update()
    % if opts.Animate
    %     model.animate('Period',0.5,'Cycles',5,'Scale',0.2) 
    % end

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