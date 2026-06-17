% clear all
load('example_data\A220_simple.mat')

% ========================= Count Error =========================
filename = "+globalOpt\Trainingset_5000.mat";
load(filename)
idx = find(TrainingSet(:,end)==0 | isnan(TrainingSet(:,end)))';


ads.Log.info(sprintf('%.0f Errors',length(idx)),"High")
ads.Log.setLevel("Info","High")

% ========================= Build it =========================
ii = idx(1);
% idx =2;
disp(TrainingSet(ii,:))

ADP.AR = TrainingSet(ii,1);
ADP.HingeEta = TrainingSet(ii,2);
ADP.FlareAngle = TrainingSet(ii,3);
ADP.ADR.M_c = TrainingSet(ii,4);
ADP.SweepAngle = TrainingSet(ii,5); % if empty will link to mach number...
ADP.ConstraintAnalysis();
ADP.BuildBaff("Retracted",false);

f = figure(1);clf;ADP.Baff.draw(f);axis equal

%% ============================ Re-run Sizing =============================
input = [ADP.AR,ADP.HingeEta,ADP.FlareAngle,ADP.ADR.M_c,ADP.SweepAngle];
sizeSample(input,true,true)

%% append data 
for i = 1:length(idx)
try
    load('example_data\A220_simple.mat')
    input = TrainingSet(idx(i),1:5);
    TrainingSet(idx(i),6:end) = sizeSample(input,true,true);
    ads.util.printing.title(sprintf('Run %.0f Success',idx(i)),"Symbol",'*');
catch
    ads.util.printing.title(sprintf('Run %.0f Failed',idx(i)),"Symbol",'$');
end
end

save(filename,'TrainingSet')
%% ======================== Get Mission Fuel Burn =========================
% [~,~,trip_fuel,trip_time] = ADP.MJperPAX(3000./cast.SI.Nmile,1);
% ads.Log.info('')
% ads.Log.info(sprintf('Trip Fuel: %.3f t',trip_fuel./1e3))
% ads.Log.info(sprintf('Trip Time: %.0f t',trip_time))
% ads.Log.info(sprintf('MTOM: %.2f t',ADP.MTOM))