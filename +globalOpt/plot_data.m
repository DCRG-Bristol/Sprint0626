clear all
load("+globalOpt\Trainingset_5000.mat")

f = fh.pubFig();
plot(TrainingSet(:,6),TrainingSet(:,7),'.')
xlabel('M_fuel')
ylabel('DOC')