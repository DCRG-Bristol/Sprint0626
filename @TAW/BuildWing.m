function [Connector,Wing,FFWT,FuelMassTotal,L_ldg,Masses] = BuildWing(obj,isRight,D_c,opts)
arguments
    obj
    isRight
    D_c
    opts.Mass_factor = 1;
    opts.BeamElements = 25;
    opts.Retracted = false;
    opts.EnginePos = 5.5;
    opts.KinkPos = 5.75;
end
% create tag
if isRight
    Tag = '_RHS';
else
    Tag = '_LHS';
end

% define some top-level params
M_c = obj.ADR.M_c;
[rho,a] = ads.util.atmos(obj.ADR.Alt_cruise);
if obj.NoKink
    opts.KinkPos = D_c/2;
end
KinkEta = (opts.KinkPos)/(obj.Span/2);
Cl_cruise = obj.MTOM*obj.Mf_TOC*9.81/(0.5*rho*(M_c*a)^2*obj.WingArea);

if isempty(obj.SweepAngle) || isnan(obj.SweepAngle)
    sweep_qtr = real(acosd(0.75.*obj.Mstar./M_c));
    if obj.ForwardSwept
        sweep_qtr = sweep_qtr*-1;
    end
else
    sweep_qtr = obj.SweepAngle;
end

% get wing thickness ratios
if obj.Size_wing
    obj.TCR_root = cast.geom.dim.Thickness2Chord(M_c,Cl_cruise,sweep_qtr,obj.Mstar);
    obj.TCR_root = 0.15;
end
tc_tip = obj.TCR_root - 0.03;

% calculate wing planform shape
D_join = sqrt((D_c/2)^2-(D_c/4)^2)*2;
tr_out = 0.35;
tr_in = 0.61;
S = @(x)wingArea(obj.WingArea,obj.AR,tr_out,tr_in,KinkEta,x,D_join,sweep_qtr);
c = fminsearch(@(x)(S(x)-obj.WingArea).^2,obj.WingArea./sqrt(obj.WingArea*obj.AR)); % get root chord
[~,cs,LE_sweeps,TE_sweeps] = wingArea(obj.WingArea,obj.AR,tr_out,tr_in,KinkEta,c,D_join,sweep_qtr); % get final parameters

%% calc properties of interest
HasFoldingWingtip = ~isnan(obj.HingeEta) & obj.HingeEta<1;
if HasFoldingWingtip
    etas_centre2tip = [0 D_join/obj.Span KinkEta obj.HingeEta 1];   % from centre to tip (including kink + hinge)
    LE_sweeps = [LE_sweeps,LE_sweeps(end)];
    TE_sweeps = [TE_sweeps,TE_sweeps(end)];
    cs = [cs(1:end-1),interp1([KinkEta, 1],cs([end-1,end]),obj.HingeEta),cs(end)];
else
    etas_centre2tip = [0 D_join/obj.Span KinkEta 1];                % from centre to tip (including kink)
end
etas = linspace(0,1,opts.BeamElements);
for i = 1:length(etas_centre2tip)
    etas = etas(abs(etas-etas_centre2tip(i))>(1/(opts.BeamElements*3)));
end
etas = unique([etas,etas_centre2tip]);
% eles = ceil((etas_centre2tip(2:end)-etas_centre2tip(1:end-1))*opts.BeamElements); % elements per section
seg_lengths = (etas_centre2tip(2:end)-etas_centre2tip(1:end-1))*obj.Span/2;
% eles(eles<4) = 4;   % make sure at least 4 elemets per section
tr = [obj.TCR_root,interp1(etas_centre2tip([2,end]),[obj.TCR_root,tc_tip],etas_centre2tip(2:end),"linear")];
% calc number of elements per section

%% create connector
wingMat = baff.Material.Aluminium;
wingMat.rho = wingMat.rho*obj.WingDensityFactor;
Connector = baff.Wing.FromLETESweep(seg_lengths(1),cs(1),[0 1],LE_sweeps(1),TE_sweeps(1),0.4,wingMat,ThicknessRatio=tr([1,2]),Dihedral=0);
Connector.A = baff.util.rotz(90)*baff.util.rotx(180);
Connector.Eta = obj.WingEta;
Connector.Offset = [0;0;-D_c/4];
Connector.Name = string(['Wing_Connector',Tag]);
con_etas = (etas(etas<=etas_centre2tip(2) & etas>=etas_centre2tip(1))-etas_centre2tip(1))/(etas_centre2tip(2)-etas_centre2tip(1));
Connector.Stations = Connector.Stations.interpolate(con_etas);
deltaEta = (obj.Span/2)/20/Connector.EtaLength;
Connector.AeroStations = Connector.AeroStations.interpolate(cast.util.AddUntillFill([Connector.AeroStations.Eta],deltaEta));
if obj.UpdateRoot
    % apply wing twist
    aero_eta = [Connector.AeroStations.Eta]*(etas_centre2tip(2)-etas_centre2tip(1))+etas_centre2tip(1);
    twists = interp1(obj.InterpEtas,obj.InterpTwists,aero_eta);
    for ti = 1:length(Connector.AeroStations)
        Connector.AeroStations(ti).Twist = twists(ti);
    end
end

if ~isRight
    for i = 1:length(Connector.Stations)
        Connector.Stations(i).EtaDir(1) = -Connector.Stations(i).EtaDir(1);
    end
end

%% fuel volume
ConFuelVol = Connector.AeroStations.GetNormVolume([0.15 0.65])*Connector.EtaLength;
% if enforced volume adjust scaling factor
if ~isnan(obj.EnforcedConnectorFuelMass) && obj.EnforcedConnectorFuelMass>0
    obj.ConnectorFuelScaling = obj.EnforcedConnectorFuelMass/(ConFuelVol.*cast.SI.litre.*0.785);
end
ConFuelMassTotal = obj.ConnectorFuelScaling*ConFuelVol.*cast.SI.litre.*0.785;
if ~obj.IsDry
    Connector.DistributeMass(ConFuelMassTotal,10,"Method","ByVolume","tag",string(['centre_fuel',Tag]),"isFuel",true);
end

%% create inner wing
idx_node = 2:(length(etas_centre2tip));
if HasFoldingWingtip
    idx_node = idx_node(1:end-1);
end
idx_ele = idx_node(1:end-1);
inner_etas = etas_centre2tip(idx_node)-etas_centre2tip(idx_node(1));
inner_etas = inner_etas./inner_etas(end);
inner_length = sum(seg_lengths(idx_ele));
Wing = baff.Wing.FromLETESweep(inner_length,cs(2),inner_etas,LE_sweeps(idx_ele),TE_sweeps(idx_ele),0.4,...
    wingMat,ThicknessRatio=tr(idx_node),Dihedral=-obj.Dihedral*ones(1,nnz(idx_ele)));
Wing.Eta = 1;
Wing.Name = string(['Wing',Tag]);
% create enough beam stations
wing_etas = (etas(etas<=etas_centre2tip(4) & etas>=etas_centre2tip(2))-etas_centre2tip(2))/(etas_centre2tip(4)-etas_centre2tip(2));
Wing.Stations = Wing.Stations.interpolate(wing_etas);
deltaEta = (obj.Span/2)/20/Wing.EtaLength;

% make cosine distribution if no wingtip
aero_eta = linspace(0,1,max(3,round(1/deltaEta)));
delta_eta = Wing.AeroStations(end).Eta-Wing.AeroStations(1).Eta;
if HasFoldingWingtip
    aero_eta = aero_eta.*delta_eta + Wing.AeroStations(1).Eta;
else
    aero_eta = round(fliplr(cos(2*pi/4*aero_eta)),5).*delta_eta + Wing.AeroStations(1).Eta;
end
if length(aero_eta)<2
    warning('hello')
end
Wing.AeroStations = Wing.AeroStations.interpolate(aero_eta);

% Wing.AeroStations = Wing.AeroStations.interpolate(cast.util.AddUntillFill([Wing.AeroStations.Eta],deltaEta));
% apply wing twist
aero_eta = [Wing.AeroStations.Eta]*(etas_centre2tip(4)-etas_centre2tip(2))+etas_centre2tip(2);
twists = interp1(obj.InterpEtas,obj.InterpTwists,aero_eta);
for ti = 1:length(Wing.AeroStations)
    Wing.AeroStations(ti).Twist = twists(ti);
end

%convert to draggable item
Wing = cast.drag.DraggableWing(Wing);
if ~isRight
    for i = 1:length(Wing.Stations)
        Wing.Stations(i).EtaDir(1) = -Wing.Stations(i).EtaDir(1);
    end
end
Connector.add(Wing);


%% create FFWT if required
if HasFoldingWingtip
    %% create hinge
    hinge = baff.Hinge();
    if isRight
        hinge.HingeVector = baff.util.rotz(-obj.FlareAngle)*[0;-1;0];
        hinge.Rotation = -0;
        hinge.A = ads.util.roty(obj.Dihedral(end));
    else
        hinge.HingeVector = baff.util.rotz(obj.FlareAngle)*[0;-1;0];
        hinge.Rotation = 0;
        hinge.A = ads.util.roty(-obj.Dihedral(end));
    end
    [K_fair,M_fair] = obj.GetHingeFairingSurrogate();
    hinge.isLocked = 0;
    hinge.Eta = 1;
    hinge.K = 1e-3 + K_fair;
    hinge.Name = strcat("SAH",Tag);
    Wing.add(hinge);
    %create hinge mass
    if obj.IsLightHinge
        hingeMass = 0;
    else
        hingeMass = SAH_massFraction(obj.HingeEta)*obj.WingMass/2;
        hingeMass = hingeMass.* obj.k_hinge + M_fair;
    end
    obj.Masses.HingeMass = hingeMass*2;
    SAH_mass = baff.Mass(hingeMass,"eta",1,"Name",strcat("SAH_mass",Tag));
    Wing.add(SAH_mass);
    %% create wingtip
    idx_node = [-1 0] + length(etas_centre2tip);
    idx_ele = idx_node(1);
    inner_etas = etas_centre2tip(idx_node)-etas_centre2tip(idx_node(1));
    inner_etas = inner_etas./inner_etas(end);
    inner_length = sum(seg_lengths(idx_ele));
    FFWT = baff.Wing.FromLETESweep(inner_length,cs(idx_ele),inner_etas,LE_sweeps(idx_ele),TE_sweeps(idx_ele),0.4,...
        wingMat,ThicknessRatio=tr(idx_node),Dihedral=-obj.Dihedral*ones(1,nnz(idx_ele)));
    FFWT.Eta = 1;
    FFWT.Name = string(['FFWT',Tag]);
    % create enough beam stations
    ffwt_etas = (etas(etas<=etas_centre2tip(5) & etas>=etas_centre2tip(4))-etas_centre2tip(4))/(etas_centre2tip(5)-etas_centre2tip(4));
    FFWT.Stations = FFWT.Stations.interpolate(ffwt_etas);
    deltaEta = (obj.Span/2)/20/FFWT.EtaLength;


    % make cosine distribution
    aero_eta = linspace(0,1,max(3,round(1/deltaEta)));
    delta_eta = FFWT.AeroStations(end).Eta-FFWT.AeroStations(1).Eta;
    % aero_eta = aero_eta.*delta_eta + FFWT.AeroStations(1).Eta;
    aero_eta = fliplr(round(cos(2*pi/4*aero_eta),5).*delta_eta + FFWT.AeroStations(1).Eta);
    if length(aero_eta)<2
        warning('hello')
    end
    FFWT.AeroStations = FFWT.AeroStations.interpolate(aero_eta);

    % aero_eta = linspace(0,1,round(1/deltaEta));
    % FFWT.AeroStations = FFWT.AeroStations.interpolate(cos(2*pi/4*aero_eta));

    % FFWT.AeroStations = FFWT.AeroStations.interpolate(cast.util.AddUntillFill([FFWT.AeroStations.Eta],deltaEta));
    
    % apply wing twist
    aero_eta = [FFWT.AeroStations.Eta]*(etas_centre2tip(5)-etas_centre2tip(4))+etas_centre2tip(4);
    twists = interp1(obj.InterpEtas,obj.InterpTwists,aero_eta);
    for ti = 1:length(FFWT.AeroStations)
        FFWT.AeroStations(ti).Twist = twists(ti);
    end

    %convert to draggable item
    FFWT = cast.drag.DraggableWing(FFWT);
    if ~isRight
        FFWT.A = ads.util.roty(obj.Dihedral(end));
        for i = 1:length(FFWT.Stations)
            FFWT.Stations(i).EtaDir(1) = -FFWT.Stations(i).EtaDir(1);
        end
    else
        FFWT.A = ads.util.roty(-obj.Dihedral(end));
    end
    hinge.add(FFWT);
else
    FFWT = baff.Wing.empty;
    obj.Masses.HingeMass = 0;
end

%% add fuselage connection mass penelty (Torenbekk 11.61)

%% fuel volume
WingFuelVol = sum(Wing.AeroStations.GetNormVolumes([0.15 0.65],[0 0.75]))*Wing.EtaLength;
if ~isnan(obj.EnforcedWingFuelMass) && obj.EnforcedWingFuelMass>0
    obj.WingFuelScaling = obj.EnforcedWingFuelMass/(WingFuelVol.*cast.SI.litre.*0.785);
end
WingFuelMassTotal = obj.WingFuelScaling*WingFuelVol.*cast.SI.litre.*0.785;
% FuelMassTotal = (18.7e3/2)/122.4
if ~obj.IsDry
    Wing.DistributeMass(WingFuelMassTotal,10,"Method","ByVolume","tag",string(['wing_fuel',Tag]),"isFuel",true);
end
%% Winglet
if obj.WingletHeight>0
    if HasFoldingWingtip
        tmp_wing = FFWT;
    else
        tmp_wing = Wing;
    end
    h = obj.WingletHeight;
    cr = tmp_wing.AeroStations(end).Chord;
    taper = tmp_wing.AeroStations(end).Chord/tmp_wing.AeroStations(1).Chord;
    LE_sweep = LE_sweeps(end);
    c_bar = tand(LE_sweep)*h+cr*taper-cr;
    te_sweep = sign(c_bar)*atand(abs(c_bar)/h);
    Winglet = baff.Wing.FromLETESweep(h,cr,[0 1],LE_sweep,te_sweep,0.4,...
        baff.Material.Stiff,"ThicknessRatio",[1 1]*tr(end));
    Winglet.A = baff.util.roty(90);
    Winglet.Eta = 1;
    Winglet = cast.drag.DraggableWing(Winglet);
    Winglet.Name = string(['winglet',Tag]);
    Winglet.Meta.ads.GenerateAeroPanels = false;
    %estimate mass (Torenbeck 11.70)
    sigma_ref = 56;
    g = 9.81;
    W_mto = obj.MTOM*g;
    if obj.Size_wing
        obj.M_winglet = 2.5 * sigma_ref * (W_mto*obj.WingletHeight/(1e6*5))^0.145/g * Winglet.PlanformArea;
    end
    Winglet.DistributeMass(obj.M_winglet,2,"Method","ByVolume","tag",string(['winglet_mass',Tag]));
    tmp_wing.add(Winglet);
    obj.Masses.WingletMass = obj.M_winglet*2;
else
    obj.Masses.WingletMass = 0;
end

%% Wing Ballast
if obj.WingBallast>0
    obj.Masses.WingletMass = obj.Masses.WingletMass + obj.WingBallast;
    ballast = baff.Mass(obj.WingBallast,"eta",obj.WingBallastEta,"Name","BallastMass");
    Wing.add(ballast);
end


%% Engine
% rubberise engine to get required thrust
if obj.Size_Eng
    obj.Engine = obj.Engine.Rubberise(obj.Thrust/obj.N_eng);
end
% engine insatllation mass (Raymer 15.52)
m_engi = 1*(2.575*(obj.Engine.Mass*cast.SI.lb)^0.922)./cast.SI.lb - obj.Engine.Mass;
% m_nac = 0.065*obj.Engine.T_Static/9.81; % Snorri 6-75
m_nac = 0;
obj.Masses.Engine = (obj.Engine.Mass+m_nac)*2;
obj.Masses.EnginePylon = m_engi*2;

engine_mat = baff.Material.Stiff;
eta = [0 0.6 1];
radius = [1 1 1/1.4]*obj.Engine.Diameter/2;
engine = baff.BluffBody.FromEta(obj.Engine.Length,eta,radius,"Material",engine_mat,"NStations",4);
engine.A = baff.util.rotz(-90);
engine.Eta = (opts.EnginePos-D_join/2)/(Wing.EtaLength);
engine.Offset = [0;obj.Engine.Length*1.4;obj.Engine.Diameter/2+0.1];
engine.Name = string(['engine',Tag]);
%make engine contribute to Drag
engine = cast.drag.DraggableBluffBody(engine);
engine.InterferanceFactor = 1.3; % Raymer section 12.5.5
%add to wing
Wing.add(engine);
% add mass to engine
eng_mass = baff.Mass(obj.Masses.Engine/2,"eta",0.4,"Name",string(['engine_mass',Tag]));
pylon_mass = baff.Mass(obj.Masses.EnginePylon/2,"eta",0.8,"Name",string(['engine_installation_mass',Tag]));
engine.add(eng_mass);
engine.add(pylon_mass);

%% ADDED - SJ: adding flutter control masses

if obj.inclFlutterMass

    %VALENTINE'S FUNCTION GOES HERE...please follow the output format :)
    [masses, eta, massId, isInnerWing] = obj.flutterMassInterpolation;
    ADP.FlutterMass = sum(masses)*2;

    %update innerwing_____________________________________________________

    %find offsets....
    eta_data = [Wing.AeroStations.Eta];
    LE_ofst_data = [Wing.AeroStations.Chord].*[Wing.AeroStations.BeamLoc];
    LE_ofst = interp1(eta_data(:), LE_ofst_data(:), eta(isInnerWing)); %le positions at requested

    wingMasses = util.MassFromArray(masses(isInnerWing), eta(isInnerWing),LE_ofst,{massId{isInnerWing}});
    Wing.add(wingMasses);

    % Wing = obj.addMass(Wing, masses(isInnerWing), eta(isInnerWing),...
    %     LE_ofst, {massId{isInnerWing}});

    %update floating wing__________________________________________________
    if HasFoldingWingtip
        %find offsets....
        eta_data = [FFWT.AeroStations.Eta];
        LE_ofst_data = [FFWT.AeroStations.Chord].*[FFWT.AeroStations.BeamLoc];
        LE_ofst = interp1(eta_data(:), LE_ofst_data(:), eta(~isInnerWing)); %le positions at requested
        wingMasses = util.MassFromArray(masses(~isInnerWing), eta(~isInnerWing),0*LE_ofst, {massId{~isInnerWing}});
        FFWT.add(wingMasses);
    end

end

% add main landing gear
l_offset = 0.15;
if obj.Size_ldg    
    z_e = abs(engine.Offset(3)) + obj.Engine.Diameter/2 + tand(5)*(opts.EnginePos - D_c*l_offset);
    L_ldg = sind(85)/sind(50)*z_e/sqrt(2);
    obj.L_ldg = L_ldg;
    obj.Eta_ldg = (obj.L_ldg + D_c*l_offset-D_join/2)/Wing.EtaLength;
    M_ldg = obj.MTOM*obj.Mf_Ldg*cast.SI.lb; % estamate of landing mass
    m_ldg = 0.095*(1*1.5*M_ldg)^0.768*(obj.L_ldg*cast.SI.ft)^0.409;
    obj.m_main_ldg = m_ldg ./ cast.SI.lb * obj.ldg_scale_factor; % 0.8 factor to match Ceras and LH2 paper
else
    L_ldg = obj.L_ldg;
    obj.Eta_ldg = (obj.L_ldg + D_c*l_offset-D_join/2)/Wing.EtaLength;
end
ldg = baff.Mass(obj.m_main_ldg,"eta",obj.Eta_ldg,"Name",string(['ldg_main',Tag]));
st = Wing.AeroStations.interpolate(obj.Eta_ldg);
if opts.Retracted
    if isRight
        ldg.Offset = [-L_ldg/2;-((st.Chord-1)-st.Chord*st.BeamLoc);0];
    else
        ldg.Offset = [L_ldg/2;-((st.Chord-1)-st.Chord*st.BeamLoc);0];
    end
else
    ldg.Offset = [0;-((st.Chord-1)-st.Chord*st.BeamLoc);L_ldg];
end
Wing.add(ldg);
obj.Masses.LandingGear = obj.m_main_ldg*2;
Masses = obj.Masses;

% add beam nodes at engine and landing gear etas.
Wing.Stations = Wing.Stations.interpolate(unique([wing_etas,engine.Eta,ldg.Eta]));

% add up fuel mass
FuelMassTotal = ConFuelMassTotal + WingFuelMassTotal;
end


function [S,cs,le_sweep,te_sweep] = wingArea(S,AR,lambda1,lambda2,k,c,D_f,LambdaQtr)
b = sqrt(AR*S)/2;
R_f = D_f/2;
c_t = lambda1*c;
c_r = c/lambda2;

A_1 = c_r*R_f;
L2 = k*b-R_f;
A_2 = (c_r+c)/2*L2;
L3 =  b*(1-k);
A_3 = (c+c_t)/2*L3;
S = 2*(A_1+A_2+A_3);

cs = [c_r,c_r,c,c_t];

x_qtr = [0 0 tand(LambdaQtr)*L2 tand(LambdaQtr)*(L2+L3)];
x_le = -cs.*0.25 + x_qtr;
x_te = cs.*0.75 + x_qtr;

le_sweep = atand((x_le(2:end)-x_le(1:end-1))./[R_f L2 L3]);
te_sweep = atand((x_te(2:end)-x_te(1:end-1))./[R_f L2 L3]);

% correct to ensure straight LE
le_sweep = [0 1 1].* le_sweep(end);
te_sweep(2) = atand((-c_r + tand(le_sweep(2))*L2 + c)/L2);
end


% function [S,cs,le_sweep,te_sweep] = wingArea(S,AR,lambda,k,c,Lambda_LE,Lambda_TE,D_f)
% b = sqrt(AR*S)/2;
% Lambda_LE = atand(c/4*(1-lambda)/(b*(1-k))+tand(Lambda_LE));
% R_f = D_f/2;
% c_t = lambda*c;
% c_r = c+(tand(Lambda_LE)-tand(Lambda_TE))*(k*b-R_f);
% A_1 = (c+c_t)/2*b*(1-k);
% A_2 = (c_r+c)/2*(k*b-D_f/2);
% A_3 = c_r*R_f;
% S = 2*(A_1+A_2+A_3);
% cs = [c_r,c_r,c,c_t];
% le_sweep = [0 1 1]*Lambda_LE;
% L = b*(1-k);
% te_sweep_end = atand((tand(Lambda_LE)*L+c_t-c)/L);
% te_sweep = [0,Lambda_TE te_sweep_end];
% end

function vals = linspaceConstrained(xs,N)
if N<length(xs)
    error('N less than length of array')
elseif N == length(xs)
    vals = xs;
    return
end
N = N - length(xs);
delta = xs(2:end)-xs(1:end-1);
delta = delta./(xs(end)-xs(1));
Ns = round(delta*N);
while sum(Ns)~= N
    if sum(Ns)>N
        [~,idx] = max(Ns);
        Ns(idx) = Ns(idx)-1;
    else
        [~,idx] = min(Ns);
        Ns(idx) = Ns(idx)+1;
    end
end
vals = linspace(xs(1),xs(2),2+Ns(1));
for i = 2:length(xs)-1
    tmp = linspace(xs(i),xs(i+1),2+Ns(i));
    vals = [vals,tmp(2:end)];
end
end

function vals = AddUntillFill(vals,gap)
delta = vals(2:end)-vals(1:end-1);
[md,idx] = max(abs(delta));
while md>gap
    new_val = vals(idx) + (vals(idx+1)-vals(idx))*0.5;
    vals = [vals(1:idx),new_val,vals((idx+1):end)];
    delta = vals(2:end)-vals(1:end-1);
    [md,idx] = max(abs(delta));
end
end
