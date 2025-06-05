function obj = BuildBaff(obj,opts)
arguments
    obj
    opts.Retracted = true;
    opts.WingBeamElements = obj.WingBeamElements;
end
%% calculate fuselage

% cruise condition
M_c = obj.ADR.M_c;
[rho,a] = ads.util.atmos(obj.ADR.Alt_cruise);
q_c = 0.5*rho*(M_c*a)^2;
Cl_cruise = obj.MTOM*obj.Mf_TOC*9.81/(0.5*rho*(M_c*a)^2*obj.WingArea);

FuelMass = obj.MTOM * obj.Mf_Fuel + obj.ExtraFuel;


% estimate fuselage size
[L_c,D_c] = cast.geom.dim.cabin(obj.ADR.PAX,N_sr=obj.N_seatsPerRow); % enforce 6 seats per row
[fuselage,Ls] = cast.geom.fuselage(L_c+D_c,D_c);
L_f = Ls(end);


M_dg = obj.MTOM*obj.Mf_TOC*cast.SI.lb; % design mass (taking at M_TOC)
M_ldg = obj.MTOM*obj.Mf_Ldg*cast.SI.lb;

% mass of fuselage (Torenbeek 8.3)
m_f = (60*D_c^2*(L_f+1.5)+160*(1.5*2.5)^0.5*D_c*L_f)./9.81*1;
% mass of furniture (Torenbeek 8.10)
m_furn = (12*L_f*D_c*(3*D_c+0.5*1+1)+3500)./9.81*1.0;
% Systems Mass (Torenbeek 8.9)
% m_av = 1.73*1400^0.983/cast.SI.lb;
% m_elec = 12.57*(250+m_av)^0.51;
% m_hyd = M_dg^0.8*0.12*M_c/cast.SI.lb;
% m_control = 0.053*(L_f*cast.SI.ft)^1.536*(obj.Span*cast.SI.ft)^0.371*(1.5*2.5*M_dg*1e-5)^0.8;
% m_control = m_control./cast.SI.lb;
% m_sys = m_av + m_elec+m_hyd+m_control;
m_sys = (270*D_c+150)*L_f/9.81-300;
% operator Equipment (Torenbeek Table 8.1)
m_op = (350*obj.ADR.PAX)./9.81;

obj.Masses.Fuselage = m_f;
obj.Masses.Furniture = m_furn;
obj.Masses.FuelSys = nan; % to be added after tank number/volumes known
obj.Masses.FuelTanks = nan; % to be added after tank number/volumes known
obj.Masses.Systems = m_sys;
obj.Masses.OperatorItems = m_op;

% distribute masses on the fuselage
fuselage.DistributeMass(m_f+m_sys,14,"tag","fus_struct");
fuselage.DistributeMass(m_furn + m_op,14,"tag","fus_cabin","Etas",Ls(2:3)./L_f);
fuselage.DistributeMass(obj.ADR.Payload,14,"tag","fus_Payload","isPayload",true,"Etas",Ls(2:3)./L_f);

%% create wings
% get common properties
[Connector_RHS,Wing_RHS,FFWT_RHS,fuelCap_RHS,obj.L_ldg,obj.Masses] = obj.BuildWing(true,D_c,"Retracted",opts.Retracted,"BeamElements",opts.WingBeamElements);
fuselage.add(Connector_RHS);
[Connector_LHS,Wing_LHS,FFWT_LHS,fuelCap_LHS,obj.L_ldg,obj.Masses] = obj.BuildWing(false,D_c,"Retracted",opts.Retracted,"BeamElements",opts.WingBeamElements);
fuselage.add(Connector_LHS);
obj.MainWingRHS = [Connector_RHS,Wing_RHS,FFWT_RHS];
obj.MainWingLHS = [Connector_LHS,Wing_LHS,FFWT_LHS];

% if not enough capaicty in wings add a fuel tank in fuselage
fus_fuel_mass = max(0,(FuelMass - fuelCap_RHS - fuelCap_LHS));
if fus_fuel_mass>0
    N_fuelTank = 4;
    % add fuel mass
    fus_fuel = baff.Fuel(fus_fuel_mass*1.01,"eta",0,"Name",'Fuselage Fuel Tank');
else
    %dummy extra fuel incase we need to add some.
    fus_fuel = baff.Fuel(0,"eta",0,"Name",'Fuselage Fuel Tank');
    N_fuelTank = 3;
end
fus_fuel.Offset = [0;0;0];
Connector_RHS.add(fus_fuel);
%fuel system mass Torenbeek(10.1007/s13272-022-00601-6 Eq. 8)
V_t = FuelMass/obj.FuelType.Density*cast.SI.litre;
m_fuelsys = (36.3*(obj.N_eng+N_fuelTank-1)+4.366*N_fuelTank^0.5*V_t^(1/3));
f_tank = baff.Mass(m_fuelsys,"eta",0,"Name","FuelSystemMass");
f_tank.Offset = [0;0;0];
Connector_RHS.add(f_tank);
obj.Masses.FuelSys = m_fuelsys;
obj.Masses.FuelTanks = 0;

%% add ballast mass
if obj.BallastMass>0
    ballast = baff.Mass(obj.BallastMass,"eta",0,"Name","BallastMass");
    ballast.Offset = [0;0;0];
    Connector_RHS.add(ballast);
    obj.Masses.FuelSys = obj.Masses.FuelSys + obj.BallastMass;
end

%% add nose landing gear

L_ldg_nose = obj.L_ldg -D_c/4 + D_c*0.1;
if obj.Size_ldg
    m_ldg = 0.125*(1*1.5*M_ldg)^0.566*(L_ldg_nose*cast.SI.ft)^0.845;
    obj.m_nose_ldg = m_ldg ./ cast.SI.lb * obj.ldg_scale_factor; % 0.8 factor to match Ceras and LH2 paper
end
ldg = baff.Mass(obj.m_nose_ldg,"eta",5/fuselage.EtaLength,"Name","ldg_nose");
if opts.Retracted
    ldg.Offset = [L_ldg_nose/2;0;-0.4*D_c];
else
    ldg.Offset = [0;0;-(L_ldg_nose+0.4*D_c)];
end
fuselage.add(ldg);
obj.Masses.LandingGear = obj.Masses.LandingGear + obj.m_nose_ldg;



%% inner loop to size and HTP and VTP and place Wing
mgc = obj.MainWingRHS.GetMGC(0.25);
%% add HTP
% etaHTP =0.87*37.57/fuselage.EtaLength;
etaHTP = (fuselage.EtaLength-(0.13*37.57))/fuselage.EtaLength; % start ~same distance away from end of fuselage as a320

sweep_qtr = real(acosd(0.75.*obj.Mstar./M_c));
if obj.SizeEmpenage
    obj.HTP_TCR_root = cast.geom.dim.Thickness2Chord(M_c,Cl_cruise,sweep_qtr,obj.Mstar);
end
tc_tip = obj.HTP_TCR_root - 0.03;

%enforce TE of HTP to be 2m away from tail
eta_te = (fuselage.EtaLength-2)/fuselage.EtaLength;
tr = 0.32;
idx = 0;
AR = 4.93;
while idx==0 || (abs((1-eta_te)*fuselage.EtaLength) - 2)^2 >0.05
    etaHTP = etaHTP + ((1-eta_te) - 2/fuselage.EtaLength);
    if obj.SizeEmpenage
        obj.HTPArea = obj.WingArea*mgc*obj.V_HT/(fuselage.EtaLength*(etaHTP-obj.AftEta));
    else
       obj.V_HT = obj.HTPArea/(obj.WingArea*mgc)*(fuselage.EtaLength*(etaHTP-obj.AftEta));
    end
    b_HT = sqrt(AR*obj.HTPArea);
    c_r = obj.HTPArea/(b_HT*(1+tr)/2);
    eta_te = etaHTP + c_r*0.75/fuselage.EtaLength;
    idx = 1;
end
sweep_le = atand(c_r/4*(1-tr)/(b_HT/2)+tand(sweep_qtr));
sweep_te = atand(tand(sweep_qtr)+3/4*c_r*(tr-1)/(b_HT/2));
mgc = 2/3*c_r*(1+tr+tr^2)/(1+tr);
y_mgc_ht = b_HT/6*(1+2*tr)/(1+tr);
x_mgc_ht = y_mgc_ht*tan(sweep_qtr)+mgc*0.25;

if obj.SizeEmpenage || ~isfield(obj.Masses,'HTP')
    m_HT = 0.016*(1.5*2.5*M_dg)^0.414*(cast.SI.lb/cast.SI.ft^2*q_c)^0.168*(obj.HTPArea*cast.SI.ft^2)^0.896*...
        (100*(obj.HTP_TCR_root+tc_tip)/2/cosd(sweep_le))^-0.12*(AR/cosd(sweep_le)^2)^0.043*tr^-0.02;
    m_HT = m_HT./cast.SI.lb;
    obj.Masses.HTP = m_HT;
else
    m_HT = obj.Masses.HTP;
end

HT_RHS = baff.Wing.FromLETESweep(b_HT/2,c_r,[0 1],sweep_le,sweep_te,0.25,...
    baff.Material.Stiff,"ThicknessRatio",[obj.HTP_TCR_root,tc_tip]);
HT_RHS.A = baff.util.rotz(90)*baff.util.rotx(180);
HT_RHS.Eta = etaHTP;
HT_RHS.Offset = [0;0;0];
HT_RHS.DistributeMass(m_HT/2,10,"Method","ByVolume","tag","HTP_RHS_mass","BeamOffset",-0.15);
HT_RHS = cast.drag.DraggableWing(HT_RHS);
HT_RHS.InterferanceFactor = 1.04;
HT_RHS.Name = 'HTP_RHS';
HT_RHS.AeroStations = HT_RHS.AeroStations.interpolate(0:0.2:1);
fuselage.add(HT_RHS);

% create elevator RHS
HT_RHS.ControlSurfaces = baff.ControlSurface('ele_RHS',[0.2 1],[0.4 0.4]);

HT_LHS = baff.Wing.FromLETESweep(b_HT/2,c_r,[0 1],sweep_le,sweep_te,0.25,...
    baff.Material.Stiff,"ThicknessRatio",[obj.HTP_TCR_root,tc_tip]);
for i = 1:length(HT_LHS.Stations)
    HT_LHS.Stations(i).EtaDir(1) = -HT_LHS.Stations(i).EtaDir(1);
end
HT_LHS.A = baff.util.rotz(90)*baff.util.rotx(180);
HT_LHS.Eta = etaHTP;
HT_LHS.Offset = [0;0;0];
HT_LHS.DistributeMass(m_HT/2,10,"Method","ByVolume","tag","HTP_LHS_mass","BeamOffset",-0.15);
HT_LHS = cast.drag.DraggableWing(HT_LHS);
HT_LHS.InterferanceFactor = 1.04;
HT_LHS.Name = 'HTP_LHS';
HT_LHS.AeroStations = HT_LHS.AeroStations.interpolate(0:0.2:1);
fuselage.add(HT_LHS);
% create elevator LHS
HT_LHS.ControlSurfaces = baff.ControlSurface('ele_LHS',[0.2 1],[0.4 0.4]);
HT_LHS.ControlSurfaces.LinkedSurface = HT_RHS.ControlSurfaces(1);
HT_LHS.ControlSurfaces.LinkedCoefficent = 1;

%% add VTP
etaVTP = (fuselage.EtaLength-(0.17*37.57))/fuselage.EtaLength; % start ~same distance away from end of fuselage as a320

%enforce TE of VTP to be 2.15m away from tail
eta_te = (fuselage.EtaLength-2.15)/fuselage.EtaLength;
tr = 0.33;
idx = 0;
AR = 3.1;
while idx==0 || (abs((1-eta_te)*fuselage.EtaLength) - 2.15)^2 >0.05
    etaVTP = etaVTP + ((1-eta_te) - 2.15/fuselage.EtaLength);
    if obj.SizeEmpenage
        obj.VTPArea =  obj.WingArea*obj.Span*obj.V_VT/(fuselage.EtaLength*(etaVTP-obj.AftEta));
    else
        obj.V_VT = obj.VTPArea*(fuselage.EtaLength*(etaVTP-obj.AftEta))/(obj.WingArea*obj.Span);
    end
    if obj.VTPArea>obj.WingArea/3
        obj.VTPArea = obj.WingArea/3; % Ensure VTP area does not exceed one-third of wing area
    end
    b_VT = sqrt(AR*obj.VTPArea*2)/2;
    c_r = obj.VTPArea/(b_VT*(1+tr)/2);
    eta_te = etaVTP + c_r*0.75/fuselage.EtaLength;
    idx = 1;
end

mgc = 2/3*c_r*(1+tr+tr^2)/(1+tr);
y_mgc_vt = b_VT/6*(1+2*tr)/(1+tr);
sweep_qtr = 35;
sweep_le = atand(c_r/4*(1-tr)/(b_VT)+tand(sweep_qtr));
sweep_te = atand(tand(sweep_qtr)+3/4*c_r*(tr-1)/b_VT);
x_mgc_vt = y_mgc_vt*tan(sweep_le)+mgc*0.25;

VT = baff.Wing.FromLETESweep(b_VT,c_r,[0 1],sweep_le,sweep_te,0.25,...
    baff.Material.Stiff,"ThicknessRatio",[obj.HTP_TCR_root,tc_tip]);
VT.A = baff.util.rotz(90)*baff.util.rotx(180)*baff.util.roty(90);
VT.Eta = etaVTP;
R = fuselage.Stations.interpolate(etaVTP).Radius;
VT.Offset = [0;0;R];
if obj.SizeEmpenage || ~isfield(obj.Masses,'VTP')
    m_VT = 0.073*(1+0.2*0)*(1.5*2.5*M_dg)^0.376*(cast.SI.lb/cast.SI.ft^2*q_c)^0.122*(obj.VTPArea*cast.SI.ft^2)^0.873*...
        (100*(obj.HTP_TCR_root+tc_tip)/2/cosd(sweep_le))^-0.49*(AR/cosd(sweep_le)^2)^0.357*tr^0.039;
    m_VT = m_VT./cast.SI.lb;
    obj.Masses.VTP = m_VT;
else
    m_VT = obj.Masses.VTP;
end
VT.DistributeMass(m_VT,10,"Method","ByVolume","tag","VTP_mass","BeamOffset",-0.15);
VT = cast.drag.DraggableWing(VT);
VT.InterferanceFactor = 1.04;
VT.Name = 'VTP';
VT.AeroStations = VT.AeroStations.interpolate(0:0.2:1);
fuselage.add(VT);

%% create model
obj.Baff = baff.Model;
obj.Baff.AddElement(fuselage);

if isempty(obj.WingBoxParams)
    obj.SetupWings();
else
    old_params = obj.WingBoxParams;
    obj.WingBoxParams = cast.size.WingBoxSizing.empty; % set as empty so new one created when setting up wing
    obj.SetupWings(); % build new WingBoxParams
    obj.InterpOldParams(old_params); % interp old params onto new params
end
obj.ApplyWingParams();

% rebuild to ensure tree is correct / all items accounted for at top-level
obj.Baff = obj.Baff.Rebuild();
obj.Baff.UpdateIdx();
obj.OEM = obj.Baff.GetOEM;

%% adjust wing position to have CoM at 35% of MAC
eta_old = obj.MainWingRHS(1).Eta;
obj.AdjustCoM(obj.StaticMargin);
delta_wing_eta = abs(eta_old-obj.MainWingRHS(1).Eta);
obj.WingEta = obj.MainWingRHS(1).Eta;

% get aft most CG position 
xs = obj.GetCoMRange();
x_aft = max(xs);
delta_com = abs(x_aft/fuselage.EtaLength - obj.AftEta);
obj.AftEta = x_aft/fuselage.EtaLength;

if max(delta_wing_eta,delta_com)>0.001
    optsCell = namedargs2cell(opts);
    obj.BuildBaff(optsCell{:});
end
end