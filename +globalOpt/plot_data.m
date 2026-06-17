clear all
load("+globalOpt\Trainingset_5000.mat")

f = fh.pubFig();
plot(TrainingSet(:,6),TrainingSet(:,7),'.')
xlabel('M_fuel')
ylabel('DOC')

f = fh.pubFig(Num=10);
plot(TrainingSet(:,9),TrainingSet(:,8),'.')
hold on
xs = [min(TrainingSet(:,9)),max(TrainingSet(:,9))];
plot(xs,xs,'-')
xlabel('Span')
ylabel('Ground Span')
