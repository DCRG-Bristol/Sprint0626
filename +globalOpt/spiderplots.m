load("C:\git\Sprint0626\surrogate_results.mat");

f = figure(1);
clf;
f.Units = 'centimeters';
f.Position = [4,4,14,10];
sp = dcrg.plot.spider_plot(BF(1:end-1,[1,2,4,5,6]));
sp.AxesLabels = {"AR","Hinge Norm Pos.","Mach","Sweep [deg]","Block Fuel [tn]"};
sp.AxesLimits = [12, 0.5,0.5,0,12;22,0.9,0.85,45,13];
sp.LegendLabels = {'GP/GA','GP/PSO','GP/Grad','NN/GA','PCE/GA'};
sp.LegendHandle.Position = [0.7450    0.2100    0.18    0.28];
sp.AxesLabelsEdge = 'w';
sp.LineStyle{2} = '--';

exportgraphics(gcf,'BF.png','Resolution',300)

f = figure(2);
clf;
f.Units = 'centimeters';
f.Position = [4,16,14,10];
DOC(:,7) = DOC(:,7)*100;
sp = dcrg.plot.spider_plot(DOC(1:end-1,[1,2,4,5,7]));
sp.AxesLabels = {"AR","Hinge Norm Pos.","Mach","Sweep [deg]","DOC [¢/PAX/km]"};
sp.AxesLimits = [[12, 0.5,0.5,0;22,0.9,0.85,45],sp.AxesLimits(:,end)];
sp.LegendLabels = {'GP/GA','GP/PSO','GP/Grad','NN/GA','PCE/GA'};
sp.LegendHandle.Location = "southeastoutside";
sp.AxesDisplay
sp.AxesLabelsEdge = 'w';
sp.LegendHandle.Position = [0.7450    0.2100    0.18    0.28];
sp.LineStyle{2} = '--';

exportgraphics(gcf,'DOC.png','Resolution',300)

%% pareto front plot
load("C:\git\Sprint0626\+globalOpt\Trainingset_5000.mat")

f = fh.pubFig(Num=5,Size=[8,8],FontSize=10);
colors = fh.colors.colorspecer(6,"qual","midcon");
colors = colors([2,1,3,4,5,6],:);
plot(TrainingSet(:,6)/1000,TrainingSet(:,7)*100,'.',Color=colors(1,:),DisplayName='Training Data')
LegendLabels = {'GP/GA','GP/PSO','GP/Grad','NN/GA','PCE/GA'};

for i = 5:-1:1
    plot(BF(i,6),BF(i,7)*100,'s',Color='k',MarkerFaceColor=colors(i+1,:),MarkerSize=7,LineWidth=1.5,DisplayName=LegendLabels{i})
    p = plot(DOC(i,6),DOC(i,7)*100,'d',Color='k',MarkerFaceColor=colors(i+1,:),MarkerSize=7,LineWidth=1.5);
    p.Annotation.LegendInformation.IconDisplayStyle = 'off';
end
xlabel('Block Fuel Mass [t]')
ylabel('Direct Operating Cost (DOC) [cent/PAX/km]')

plot(nan,nan,DisplayName='\bf Objective Func.',Color='w');
cg = [1 1 1]*0.7;
plot(BF(i,6),BF(i,7)*100,'s',Color='k',MarkerFaceColor=cg,MarkerSize=7,LineWidth=1.5,DisplayName='DOC')
plot(DOC(i,6),DOC(i,7)*100,'d',Color='k',MarkerFaceColor=cg,MarkerSize=7,LineWidth=1.5,DisplayName='Block Fuel');

lg = legend();
lg.Location = "east";
lg.FontSize = 9;
ylim([3,5.5])
xlim([12,22])
copygraphics(gcf)

exportgraphics(gcf,'swoosh.pdf','ContentType','vector');
