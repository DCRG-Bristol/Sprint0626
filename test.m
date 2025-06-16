clear all
%load('C:\Users\sa14378\OneDrive - University of Bristol\Documents\MATLAB\Sprint0626-master\example_data\UB321_simple.mat')
load('example_data/A220_simple.mat');

wb = ADP.WingBoxParams(2);
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




%get eta of forces
eta_forces = wb.Eta;

% get spanwise etas for mesh
MaxDeltaEta = 0.01; % defines spanwise discretisation
eta_mesh = eta_forces(1);
%eta_forces
%eta_force_idx = 1;
for i = 1:length(eta_forces)-1
    points = linspace(eta_forces(i),eta_forces(i+1),ceil((eta_forces(i+1)-eta_forces(i))/MaxDeltaEta)+1);
    eta_mesh = [eta_mesh,points(2:end)];
    %eta_force_idx(end+1) = length(eta_mesh);
end

I=ismember(eta_mesh,eta_forces);

eta_force_idx=find(I);
% starting from bottum left going clockwise corners are ABCD
N_spar = 4; % discretisations on spar webs3
N_skin = 8; % discretisations on skin4
N_section = (N_spar+1)*2 + (N_skin-1)*2; % nodes per section

% interpolate heights and thicknesses
hs = interp1(eta_forces,wb.Height,eta_mesh);
Skins = interp1(eta_forces,wb.Skin.Skin_Thickness,eta_mesh);
Spars = interp1(eta_forces,wb.SparWeb_Thickness,eta_mesh);
caps = interp1(eta_forces,wb.SparCap_Thickness,eta_mesh);
Spars=Spars+0.2*caps;
ts = [repmat(Spars,N_spar,1);repmat(Skins,N_skin,1);repmat(Spars,N_spar,1);repmat(Skins,N_skin,1)];


%% create FE points
WingPoints = ads.fe.Point.empty;
MeshPoints = ads.fe.Point.empty;
for i = 1:length(eta_mesh)
    % Get Vertical Vector
    nz = [0;0;1];
    % get ABCD
    A = RHS_wing.GetWingPos(eta_mesh(i),wb_cEta(1)) - nz*hs(i)/2;
    B = RHS_wing.GetWingPos(eta_mesh(i),wb_cEta(1)) + nz*hs(i)/2;
    C = RHS_wing.GetWingPos(eta_mesh(i),wb_cEta(2)) + nz*hs(i)/2;
    D = RHS_wing.GetWingPos(eta_mesh(i),wb_cEta(2)) - nz*hs(i)/2;

    idx = 1;
    % create points A->B
    neta = linspace(0,1,N_spar+1);
    neta = neta(1:end-1);
    vec = B-A;
    for j = 1:length(neta)
        fe.Points(end+1) = ads.fe.Point(A+vec*neta(j),InputCoordSys=CS);
        MeshPoints(idx,i) =fe.Points(end);
        idx = idx+1;
    end
    % create points B->C
    neta = linspace(0,1,N_skin+1);
    neta = neta(1:end-1);
    vec = C-B;
    for j = 1:length(neta)
        fe.Points(end+1) = ads.fe.Point(B+vec*neta(j),InputCoordSys=CS);
        MeshPoints(idx,i) =fe.Points(end);
        idx = idx+1;
    end
    % create points C->D
    neta = linspace(0,1,N_spar+1);
    neta = neta(1:end-1);
    vec = D-C;
    for j = 1:length(neta)
        fe.Points(end+1) = ads.fe.Point(C+vec*neta(j),InputCoordSys=CS);
        MeshPoints(idx,i) =fe.Points(end);
        idx = idx+1;
    end
    % create points D->A
    neta = linspace(0,1,N_skin+1);
    neta = neta(1:end-1);
    vec = A-D;
    for j = 1:length(neta)
        fe.Points(end+1) = ads.fe.Point(D+vec*neta(j),InputCoordSys=CS);
        MeshPoints(idx,i) =fe.Points(end);
        idx = idx+1;
    end
end
%idx=1;
for i = 1:length(eta_force_idx)
    wingpointmid=RHS_wing.GetWingPos(eta_mesh(eta_force_idx(i)),0.25);
    fe.Points(end+1) = ads.fe.Point(wingpointmid,InputCoordSys=CS);
    WingPoints(i) =fe.Points(end);
    %idx = idx+1;
end

%% build shell Elements
for i = 1:size(MeshPoints,2)-1
    for j = 1:size(MeshPoints,1)
        if j == size(MeshPoints,1)
            ps = [MeshPoints(j,i),MeshPoints(j,i+1),MeshPoints(1,i+1),MeshPoints(1,i)]; % go around in circle (wrap around to start)
        else
            ps = [MeshPoints(j,i),MeshPoints(j,i+1),MeshPoints(j+1,i+1),MeshPoints(j+1,i)]; % go around in circle            
        end
        fe.Shells(end+1) = ads.fe.Shell(ps, fe.Materials(end), ts(j,i));
    end
end

%for i = 1:length(eta_force_idx)
    



% %% plot the nodes
% Xs = [fe.Points.GlobalPos];
% f = figure(1);clf;hold on
% % plot all points
% plot3(Xs(1,:),Xs(2,:),Xs(3,:),'k.')
% % higlight poitns on 'force rings'
% ps = MeshPoints(:,eta_force_idx);
% ps = ps(:);
% Xs = [ps.GlobalPos];
% plot3(Xs(1,:),Xs(2,:),Xs(3,:),'rs')
% axis equal
% for i = 1:size(MeshPoints,2)
%     ps = MeshPoints(:,i);
%     ps = ps([1:end,1]);
%     Xs = [ps.GlobalPos];
%     plot3(Xs(1,:),Xs(2,:),Xs(3,:),'k-')
% end
% 
% %% plot QUAD4's
% 

f = figure(11);clf;hold on
for i = 1:length(fe.Shells)
Xs = [fe.Shells(i).G1([1:4,1]).GlobalPos];
plot3(Xs(1,:),Xs(2,:),Xs(3,:),'k-')
end
axis equal


for i = 1:length(eta_force_idx)

    %for j = 1:size(MeshPoints,1)
        %if j == size(MeshPoints,1)
        %    ps = [MeshPoints(j,i),MeshPoints(j,i+1),MeshPoints(1,i+1),MeshPoints(1,i)]; % go around in circle (wrap around to start)
        %else
        pmid=WingPoints(i);
        idx=eta_force_idx(i);
        ps = [MeshPoints(:,idx)];% go around in circle            
        %end
        REFC=123456;%[1;2;3];
        %v = [-1, ones(1,N)/N];
        Wti = 1.0/N_section;%[-1, ones(1,N_section) / N_section]';
        Ci = 123456;%[1;2;3];
        fe.RigidBodyElements(end+1) = ads.fe.RigidBodyElement(pmid,REFC,Wti,Ci,ps);
        %Fnom=[0,0,1];
        %fe.Forces(end+1)=ads.fe.Force(Fnom,pmid)
    %end
end

% pmids=WingPoints(:);
% Fnom=[0,0,1];
% fe.Forces(end+1)=ads.fe.Force(Fnom,pmids);



ps_1 = [MeshPoints(:,1)];

for i = 1:length(ps_1)
    ps_con_i=ps_1(i);
    fe.Constraints(end+1)=ads.fe.Constraint(ps_con_i,123456);
end
%ps_con=MeshPoints(:,1);

%fe.Constraints(end+1)=ads.fe.Constraint(ps_con,123456);
% 
halfchord=ADP.MainWingRHS.GetMGC(0);
[rho,a,~,P] = ads.util.atmos(ADP.ADR.Alt_cruise);
TAS = a*ADP.ADR.M_c;


%for i=
%omega=w*halfchord/TAS;

L=2500/3.2808;

%phi(end+1)=(L/pi())*((1+(8/3)*((1.339*omega*L)^2))/((1+((1.339*omega*L)^2))^(11/6)));
Nbase = 100;
w_base = linspace(0.1, 50, Nbase);

% --- 2) Ten extra points between 0.1 and 1 Hz ---
w_extra = linspace(0.1, 1, 10);

% --- 3) Combine, sort, and remove duplicates ---
w = unique([w_base, w_extra]);
% --- 2) Convert to angular freq (rad/s) and form nondimensional k ---
omega = 2*pi * w;                   
k     = (omega * halfchord) / TAS;  

% --- 3) Compute phi(k) (vectorized) ---
phi = (L/pi) * ...
      ( (1 + (8/3)*( (1.339 * k * L).^2 )) ...
      ./ ( (1 + ( (1.339 * k * L).^2 )).^(11/6) ) );

% % --- 4) Convert phi to decibels ---
% phi_dB = 20*log10(abs(phi));
% 
% % --- 5) Plot phi_dB vs. w on a logarithmic x‐axis ---
% figure;
% semilogx(w, phi_dB, 'b-o', 'LineWidth', 1.2, 'MarkerSize', 4);
% grid on;
% xlabel('Frequency w (Hz)');
% ylabel('\phi (dB)');
% title('Plot of \phi (dB) vs. Frequency (logarithmic Hz)');
% 
% figure;
% plot(w, phi_dB, 'b-o', 'LineWidth', 1.2, 'MarkerSize', 4);
% grid on;
% 
% xlabel('Frequency w (Hz)');
% ylabel('\phi (dB)');
% title('Plot of \phi (dB) vs. Frequency (Hz)');
% 
% 
% figure;
% plot(w, phi, 'b-o', 'LineWidth', 1.2, 'MarkerSize', 4);
% grid on;
% 
% xlabel('Frequency w (Hz)');
% ylabel('\phi (dB)');
% title('Plot of \phi vs. Frequency (Hz)');
% 
% set(gca, 'Color', 'w');  % White background for the axes
% set(gcf, 'Color', 'w');  % White background for the figure window
% 
% 
% 
%     mni.printing.bdf.writeColumnDelimiter(fid,"short")
%     %for i = 1:length(obj)
% 
% TID=1;
% tmpCard = mni.printing.cards.TABLEM1(TID,w,phi);
% tmpCard.writeToFile(fid);

            %tmpCard = mni.printing.cards.TABLEM1(obj(i).E,obj(i).REFGRID,obj(i).REFC,obj(i).WTi,obj(i).Ci,obj(i).Gi);
            



ads.nast.gust.Writeinputgust();

IDs=fe.UpdateIDs();
fe.Export('testoutput.bdf');

fid=fopen('testoutput.bdf','a+');

TID=9001;

mni.printing.cards.TABRND1(TID,w,phi).writeToFile(fid);%'LINEAR','LINEAR'
fclose(fid);





%% old
    % s = init + 5*(i-1);
    % skinthick = skinthicknesses(i);
    % sparthick = sparwebthicknesses(i);
    % 
    % % build a vector of node‐indices:
    % idx1 = [ s+1;  s+2;  s+6;  s+7 ];
    % idx2 = [ s+1;  s+3;  s+6;  s+8 ];
    % idx3 = [ s+2;  s+4;  s+7;  s+9 ];
    % idx4 = [ s+3;  s+4;  s+8;  s+9 ];
    % 
    % % now pull out the corresponding Point objects as a 4×1 vector:
    % G1 = fe.Points(idx1);  % this yields a 4×1 array of ads.fe.Point
    % G2 = fe.Points(idx2);
    % G3 = fe.Points(idx3);
    % G4 = fe.Points(idx4);
    % 
    % fe.Shells(end+1) = ads.fe.Shell(G1, fe.Materials(end), sparthick);
    % fe.Shells(end+1) = ads.fe.Shell(G2, fe.Materials(end), skinthick);
    % fe.Shells(end+1) = ads.fe.Shell(G3, fe.Materials(end), sparthick);
    % fe.Shells(end+1) = ads.fe.Shell(G4, fe.Materials(end), skinthick);










% wingpointsfront=RHS_wing.GetGlobalWingPos(etas,0.15);
% wingpointsmid=RHS_wing.GetGlobalWingPos(etas,0.25);
% wingpointsrear=RHS_wing.GetGlobalWingPos(etas,0.65);
% heights=ADP.WingBoxParams(1,2).Height;
% skinthicknesses=ADP.WingBoxParams(1,2).Skin.Skin_Thickness;
% sparwebthicknesses=ADP.WingBoxParams(1,2).SparWeb_Thickness;

% for i = 1:length(etas)
%     wingpointfront=wingpointsfront(:,i);
%     wingpointrear=wingpointsrear(:,i);
%     wingpointmid=wingpointsmid(:,i);
%     height=heights(i);
% 
% 
%     z1=wingpointfront(3)+0.5*height;
%     z2=wingpointfront(3)-0.5*height;
% 
%     z3=wingpointrear(3)+0.5*height;
%     z4=wingpointrear(3)-0.5*height;
% 
% 
%     fe.Points(end+1) = ads.fe.Point([wingpointfront(1);wingpointfront(2);z1],InputCoordSys=CS);
%     fe.Points(end+1) = ads.fe.Point([wingpointfront(1);wingpointfront(2);z2],InputCoordSys=CS);
% 
%     fe.Points(end+1) = ads.fe.Point([wingpointrear(1);wingpointrear(2);z3],InputCoordSys=CS);
%     fe.Points(end+1) = ads.fe.Point([wingpointrear(1);wingpointrear(2);z4],InputCoordSys=CS);
% 
%     fe.Points(end+1) = ads.fe.Point([wingpointmid(1);wingpointmid(2);wingpointmid(3)],InputCoordSys=CS);
%     %fe.Points(end+1) = ads.fe.Point([nan;nan;nan],InputCoordSys=CS);
% end
% 
% % for i = 1:length(etas)
% %     wingpointmid=wingpointsmid(i);
% %     fe.Points(end+1) = ads.fe.Point([wingpointmid(1);wingpointmid(2);wingpointmid(3)],InputCoordSys=CS);
% %     %fe.Points(end+1) = ads.fe.Point([nan;nan;nan],InputCoordSys=CS);
% % end
% 
% 
% init=0;
% %start=init;
% 
% % make shell elements
% 
% 
% for i = 1:(length(etas)-1)
%     s = init + 5*(i-1);
%     skinthick = skinthicknesses(i);
%     sparthick = sparwebthicknesses(i);
% 
%     % build a vector of node‐indices:
%     idx1 = [ s+1;  s+2;  s+6;  s+7 ];
%     idx2 = [ s+1;  s+3;  s+6;  s+8 ];
%     idx3 = [ s+2;  s+4;  s+7;  s+9 ];
%     idx4 = [ s+3;  s+4;  s+8;  s+9 ];
% 
%     % now pull out the corresponding Point objects as a 4×1 vector:
%     G1 = fe.Points(idx1);  % this yields a 4×1 array of ads.fe.Point
%     G2 = fe.Points(idx2);
%     G3 = fe.Points(idx3);
%     G4 = fe.Points(idx4);
% 
%     fe.Shells(end+1) = ads.fe.Shell(G1, fe.Materials(end), sparthick);
%     fe.Shells(end+1) = ads.fe.Shell(G2, fe.Materials(end), skinthick);
%     fe.Shells(end+1) = ads.fe.Shell(G3, fe.Materials(end), sparthick);
%     fe.Shells(end+1) = ads.fe.Shell(G4, fe.Materials(end), skinthick);
% 
% 
% end
% 
% 
% 
% WTi={12,12,12};
% fe.RigidBodyElements=ads.fe.RigidBodyElement(1,1,1);
% 
% 
% 
% NPoints = 100;
% etas = wb.Eta;
% for i = 1:length(etas)
%     le = RHS_wing.GetGlobalWingPos(etas,wb_cEta(1));
%     fe.Points()
% end
% 
% wb_te = RHS_wing.GetGlobalWingPos(etas,wb_cEta(2));
% 
% 
% f = figure(1);
% clf;hold on;
% plot(wb_le(2,:),wb_le(1,:),'s-')
% plot(wb_te(2,:),wb_te(1,:),wb)
% 
% 
% %Make RBE3 elements
% 
% for i = 1:length(etas)
% 
% 
% 
% 
% end


