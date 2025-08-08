clear all
load('example_data\A220_simple.mat')

% ========================= Set Hyper-parameters =========================
load("+globalOpt\Trainingset_500.mat")
idx = find(TrainingSet(:,end)==0 | isnan(TrainingSet(:,end)))';
ads.util.printing.title(sprintf('%.0f Errors',length(idx)))
ii = idx(3);
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
% conduct sizing
input = [ADP.AR,ADP.HingeEta,ADP.FlareAngle,ADP.ADR.M_c,ADP.SweepAngle];
sizeSample(input,true,true)


%% ======================== Get Mission Fuel Burn =========================
% [~,~,trip_fuel,trip_time] = ADP.MJperPAX(3000./cast.SI.Nmile,1);
% fh.printing.title('','Length',60,'Symbol','=')
% fh.printing.title(sprintf('Trip Fuel: %.3f t',trip_fuel./1e3),'Length',60,'Symbol','=')
% fh.printing.title(sprintf('Trip Time: %.0f t',trip_time),'Length',60,'Symbol','=')
% fh.printing.title(sprintf('MTOM: %.2f t',ADP.MTOM),'Length',60,'Symbol','=')