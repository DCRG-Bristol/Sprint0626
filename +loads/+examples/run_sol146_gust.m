load('example_data/A220_simple_rerun.mat')
%% update Hyper Paramters
ADP.AR = 18.6;
ADP.HingeEta = 0.7;
ADP.FlareAngle = 15;
ADP.ADR.M_c = 0.78;
ADP.SweepAngle = 10;

%% build the baff
ADP.BuildBaff();

%% run gusts
ld = loads.NastranModel(ADP);
lc = cast.LoadCase.Gust(ADP.ADR.M_c,ADP.ADR.Alt_cruise.*cast.SI.ft);
ld.SetConfiguration(IsLocked=true);
ld.BinFolder = sprintf('Bin_test', i);
[Lds,BinFolder] = ld.GustLoads(lc,1);

try
   system(sprintf('del "\\\\.\\%s\\%s\\Source\\nul"', pwd, BinFolder));
catch
end

%% plot gust loads
% h5 = mni.result.hdf5(fullfile(BinFolder,'bin','sol146.h5'));
% get time series from gusts from wing root element
EIDs = [ld.fe.Beams([ld.fe.Beams.Tag] == ld.Tags{2}(1)).ID];
gusts_1 = ld.ExtractDynamicLoads(fullfile(BinFolder,'bin','sol146.h5'),ld.Tags(2));
gusts_2 = ld.ExtractDynamicLoads(fullfile(BinFolder, 'bin', 'sol146.h5'), ld.Tags(3));
vec_1 = max(abs(gusts_1(1).My), [], 1);  % Inner span bending moment
vec_2 = max(abs(gusts_2(1).My), [], 1);  % Outer span bending moment
% Get station locations and normalize to [0,1]
hh_1 = ADP.WingBoxParams(2).Span*ADP.WingBoxParams(2).Eta;
hh_2 = ADP.WingBoxParams(2).Span + ADP.WingBoxParams(3).Span*ADP.WingBoxParams(3).Eta;
vec_full = [vec_1, vec_2];
hh = [hh_1, hh_2];
spanNorm = hh./max(hh);

%% 6. PLOT RESULT ---------------------------------------------------------
figure; hold on; box on;
plot(spanNorm, vec_full, 'b-', 'LineWidth', 2);
xlabel('Normalized Spanwise Position');
ylabel('WRBM [Nm]');
title('Actual WRBM across Wing Span');








