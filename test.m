clear all
%load('C:\Users\sa14378\OneDrive - University of Bristol\Documents\MATLAB\Sprint0626-master\example_data\UB321_simple.mat')
load('example_data/A220_simple.mat');

wb = ADP.WingBoxParams;
ADP.BuildBaff;


RHS_wing = ADP.Baff.Wing(2);
wb_cEta = ADP.WingboxEtas;


fe = ads.fe.Component();
fe.Name = ADP.Name;

%% add nodes at each eta

% make global coordinate system
fe.CoordSys(1) = ads.fe.CoordSys("Origin",RHS_wing.GetGlobalPos(0,[0;0;0])  ,"A",RHS_wing.GetGlobalA);
CS = fe.CoordSys(1);

% make material 'card'
fe.Materials(end+1) = ads.fe.Material(99,0.3,1.22);




%make points
etas = wb.Eta;
wingpointsfront=RHS_wing.GetGlobalWingPos(etas,0.15);
wingpointsmid=RHS_wing.GetGlobalWingPos(etas,0.25);
wingpointsrear=RHS_wing.GetGlobalWingPos(etas,0.65);
heights=ADP.WingBoxParams(1,2).Height;
skinthicknesses=ADP.WingBoxParams(1,2).Skin.Skin_Thickness;
sparwebthicknesses=ADP.WingBoxParams(1,2).SparWeb_Thickness;

for i = 1:length(etas)
    wingpointfront=wingpointsfront(:,i);
    wingpointrear=wingpointsrear(:,i);
    wingpointmid=wingpointsmid(:,i);
    height=heights(i);

    
    z1=wingpointfront(3)+0.5*height;
    z2=wingpointfront(3)-0.5*height;
    
    z3=wingpointrear(3)+0.5*height;
    z4=wingpointrear(3)-0.5*height;


    fe.Points(end+1) = ads.fe.Point([wingpointfront(1);wingpointfront(2);z1],InputCoordSys=CS);
    fe.Points(end+1) = ads.fe.Point([wingpointfront(1);wingpointfront(2);z2],InputCoordSys=CS);

    fe.Points(end+1) = ads.fe.Point([wingpointrear(1);wingpointrear(2);z3],InputCoordSys=CS);
    fe.Points(end+1) = ads.fe.Point([wingpointrear(1);wingpointrear(2);z4],InputCoordSys=CS);
    
    fe.Points(end+1) = ads.fe.Point([wingpointmid(1);wingpointmid(2);wingpointmid(3)],InputCoordSys=CS);
    %fe.Points(end+1) = ads.fe.Point([nan;nan;nan],InputCoordSys=CS);
end

% for i = 1:length(etas)
%     wingpointmid=wingpointsmid(i);
%     fe.Points(end+1) = ads.fe.Point([wingpointmid(1);wingpointmid(2);wingpointmid(3)],InputCoordSys=CS);
%     %fe.Points(end+1) = ads.fe.Point([nan;nan;nan],InputCoordSys=CS);
% end


init=0;
%start=init;

% make shell elements


for i = 1:(length(etas)-1)
    s = init + 5*(i-1);
    skinthick = skinthicknesses(i);
    sparthick = sparwebthicknesses(i);

    % build a vector of node‐indices:
    idx1 = [ s+1;  s+2;  s+6;  s+7 ];
    idx2 = [ s+1;  s+3;  s+6;  s+8 ];
    idx3 = [ s+2;  s+4;  s+7;  s+9 ];
    idx4 = [ s+3;  s+4;  s+8;  s+9 ];

    % now pull out the corresponding Point objects as a 4×1 vector:
    G1 = fe.Points(idx1);  % this yields a 4×1 array of ads.fe.Point
    G2 = fe.Points(idx2);
    G3 = fe.Points(idx3);
    G4 = fe.Points(idx4);

    fe.Shells(end+1) = ads.fe.Shell(G1, fe.Materials(end), sparthick);
    fe.Shells(end+1) = ads.fe.Shell(G2, fe.Materials(end), skinthick);
    fe.Shells(end+1) = ads.fe.Shell(G3, fe.Materials(end), sparthick);
    fe.Shells(end+1) = ads.fe.Shell(G4, fe.Materials(end), skinthick);


end



WTi={12,12,12};
fe.RigidBodyElements=ads.fe.RigidBodyElement(1,1,1);



NPoints = 100;
etas = wb.Eta;
for i = 1:length(etas)
    le = RHS_wing.GetGlobalWingPos(etas,wb_cEta(1));
    fe.Points()
end

wb_te = RHS_wing.GetGlobalWingPos(etas,wb_cEta(2));


f = figure(1);
clf;hold on;
plot(wb_le(2,:),wb_le(1,:),'s-')
plot(wb_te(2,:),wb_te(1,:),wb)


%Make RBE3 elements

for i = 1:length(etas)

    


end


