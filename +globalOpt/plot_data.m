clear all
load("+globalOpt\Trainingset_500.mat")

f = fh.pubFig();
plot(TrainingSet(:,6),TrainingSet(:,7),'.')