clear all
close all
clc

%%
load('example_data\A220_simple.mat')
ADP.SweepAngle = 26;
ADP.BuildBaff();

AS = aero.AeroSurrogateV1(ADP);
ASO = aero.AeroSurrogateV1(ADP,"useOriginal",true);



M_range = [0.6:0.01:0.85];


for i=1:length(M_range)
    CDn(i) = AS.Get_Cd(0.5,M_range(i),"Cruise");
    CDo(i) = ASO.Get_Cd(0.5,M_range(i),"Cruise");
end



ADP.SweepAngle = 10;
ADP.BuildBaff();

AS = aero.AeroSurrogateV1(ADP);
ASO = aero.AeroSurrogateV1(ADP,"useOriginal",true);

for i=1:length(M_range)
    CDn10(i) = AS.Get_Cd(0.5,M_range(i),"Cruise");
    CDo10(i) = ASO.Get_Cd(0.5,M_range(i),"Cruise");
end
%%


fig = figure(1); clf;
fig.Units = 'centimeters';
fig.Position = [1,1,14,12];
tt = tiledlayout(1,1);
tt.Padding = 'compact';
tt.TileSpacing = 'compact';

sp = nexttile(1);
sp.FontSize = 15;
hold all; grid on; box on;


plot(M_range,M_range .* 0.5./CDo,'k-','LineWidth',2,'DisplayName','NitaShevell - 26 deg')
plot(M_range,M_range .* 0.5./CDn,'b-','LineWidth',2,'DisplayName','MF Framework - 26 deg')

plot(M_range,M_range .* 0.5./CDo10,'k--','LineWidth',2,'DisplayName','NitaShevell - 10 deg')
plot(M_range,M_range .* 0.5./CDn10,'b--','LineWidth',2,'DisplayName','MF Framework - 10 deg')

legend('show')
xlabel('Mach')
ylabel('$M ~ C_L / C_D$')