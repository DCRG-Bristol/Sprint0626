f = fh.pubFig(Num=2,Size=[10,10],Layout=[1,1]);

load('Trainingset_500_full.mat')
% clear invalid runs
idx = TrainingSet(:,6)==0 & TrainingSet(:,7) == 0;
TrainingSet = TrainingSet(~idx,:);
plot(TrainingSet(:,6),TrainingSet(:,7),'r.');


load('Trainingset_500_reduced_aero.mat')
plot(TrainingSet(:,6),TrainingSet(:,7),'b.');


lg = legend('Full','Simple Aero');
xlabel('Fuel Burn')
ylabel('DOC')


%% parrallel coord plot
load('Trainingset_500_full.mat')
% clear invalid runs
idx = TrainingSet(:,6)==0 & TrainingSet(:,7) == 0;
TrainingSet = TrainingSet(~idx,:);

f = fh.pubFig(Num=3,Size=[10,10],Layout=[1,1]);

groupIdx = TrainingSet(:,6)<(1e4);
groups = repmat("Fuel $>$ 1e4",size(TrainingSet,1),1);
groups(groupIdx) = "Fuel $<$ 1e4";

labels = {'AR','HingePos','Flare','M','Sweep','FuelBurn','DOC'};

p = parallelcoords(TrainingSet(:,[1:7]),Group=groups,Labels=labels,Standardize="on");

ax = gca;
ax.XTickLabel = labels;
ylabel('Norm. Std.')
% lg = legend('Fuel $>$ 1e4','Fuel $<$ 1e4');
% lg.FontSize = 12;