clear all
close all
clc

%%
load('example_data\A220_simple.mat')

CL = 0.5;
M = [0.6:0.0001:1.0];

ADP.SweepAngle = 0;
NDP = aero.NitaShevellPolar(ADP);
for i=1:length(M)

    CD_NSP_0(i) = NDP.Shevell(M(i),CL);

end

ADP.SweepAngle = 26;
NDP = aero.NitaShevellPolar(ADP);
for i=1:length(M)

    CD_NSP_26(i) = NDP.Shevell(M(i),CL);

end

ADP.SweepAngle = 40;
NDP = aero.NitaShevellPolar(ADP);
for i=1:length(M)

    CD_NSP_40(i) = NDP.Shevell(M(i),CL);

end


fig = figure(1); clf;
fig.Units = 'centimeters';
fig.Position = [1,1,14,12];
tt = tiledlayout(1,1);
tt.Padding = 'compact';
tt.TileSpacing = 'compact';

sp = nexttile(1);
sp.FontSize = 15;
hold all; grid on; box on;

plot(M,CD_NSP_0./0.0001,'b-','DisplayName','NitaShevellPolar','LineWidth',2)
plot(M,CD_NSP_26./0.0001,'k-','DisplayName','NitaShevellPolar','LineWidth',2)
plot(M,CD_NSP_40./0.0001,'k-','DisplayName','NitaShevellPolar','LineWidth',2)

ylim([0 ADP.AeroSurrogate.CDw_max*1.2./0.0001])

ylabel('$\Delta C_{D_w}$ [counts]')
xlabel('Mach')
legend('AR 0','AR 26','AR 40','Location','northwest')
