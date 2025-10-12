clear all
close all
load('example_data/A220_simple.mat')
ads.Log.setLevel('Debug');

debug = true;

ADP.BuildBaff;
tic;
[CoM,m] = ADP.Baff.GetCoM;

[rho,a] = ads.util.atmos(ADP.ADR.Alt_cruise);
v_cruise = ADP.ADR.M_c * a;

%% create vlm model
if debug
profile on;
end
% convert baff to LACA model
wings = {};
% for i = 1:numel(ADP.Baff.Wing)
for i = 1:6
    bw = ADP.Baff.Wing(i);
    % extract LE points and Chord lengths at each aero station
    chords = bw.AeroStations.Chord;
    LE = bw.GetGlobalWingPos(bw.AeroStations.Eta,0);
    TE = bw.GetGlobalWingPos(bw.AeroStations.Eta,1);
    wings{end+1} = laca.model.Wing.From_LE_TE(LE,TE,{});
    wings{end}.Name = bw.Name;
end
model = laca.model.Aircraft(wings);
model.Name = 'test';

% convert to VLM model
vlm_tmp = laca.vlm.Model.From_laca_model(model,10,1,true);
vlm_tmp.Stitch();
vlm = vlm_tmp.Simplify();

% assume flat wake
vlm = vlm.generate_te_horseshoe([10;0;0]);
vlm = vlm.generate_AIC();

%% trim the aircraft
weight = (m*9.81);

f0 = [0;0];
for i= 1:100
    f0 = trim(f0,CoM,weight,vlm,rho,v_cruise);
    [~,~,~,~,~,dw] = enforce_dist(vlm,3-f0(1),v_cruise);
    if sum(abs(dw))<1e-6
        break
    end
end
vlm.apply_result_katz(rho);
toc;
disp('done')
if debug
profile off;
end

%% enforce wing lift distribution
% get lift dist
function W = trim_sol(vlm,AoA,HTP_AoA,CoM,rho,V)
    % set HTP Angle
    idx = [5,6];
    sign = [1,-1];
    for i = 1:length(idx)
        vlm.Normalwash(vlm.WingIDs{idx(i)}) = deg2rad(HTP_AoA)*sign(i);
    end
    % set wind direction
    Beta = 0;
    V_func = dcrg.rotyd(-AoA)*dcrg.rotzd(-Beta)*[1 0 0]'*V;
    % solve VLM
    vlm = vlm.solve(V_func);
    vlm = vlm.apply_result_simple(rho);
    % get force and moment about CoM
    W = vlm.get_forces_and_moments(CoM);
    W = W([3,5],1);
end

function f0 = trim(f0,CoM,weight,vlm,rho,V)
    cost = @(X)trim_sol(vlm,X(1),X(2),CoM,rho,V)-[weight;0];
    idx = 1;
    while true
        [J,err] = mbd.jacobiancd(cost,f0);
        if norm(err)<1e-4
            break
        end
        f0 = f0 - J\err;
        idx = idx + 1;
        if idx >100
            error('Didn''t Converge')
        end
    end
end

function [spans,Gs,Ls,IDs,idx,dw] = enforce_dist(vlm,dalpha,V)
    [spans,Gs,Ls,IDs,idx] = get_lift_dist(vlm);
    % fit fourier series
    ys = (spans-min(spans))/(max(spans)-min(spans))*2-1;
    thetas = acos(ys);
    [~,b,~] = laca.util.Fseries(thetas,Gs,20,false,'sine');
    % fit fourier to target
    target = gamma_prandtl(abs(ys),0);
    [a_target,b_target,~] = laca.util.Fseries(thetas,target,20,false,'sine');
    b_target = b_target./b_target(1).*b(1);   % scale target to same area - special property of sine dist, area = 2*a_1
    % get delta Gamma required
    dG = laca.util.Fseriesval(a_target*0,b_target-b,thetas,false);
    dGamma = vlm.Gamma*0;
    
    rIDs = vlm.WingIDs(1:2);
    lIDs = vlm.WingIDs(3:4);
    iIDs = [-1*[rIDs{:}],[lIDs{:}]];
    iIDs = sign(iIDs(idx))';
    dGamma(IDs) = dG(2:end-1).*iIDs;
    
    % calc required downwash
    dw = vlm.AIC*dGamma;
    %apply to wings
    Widx = [1,2,3,4];
    Wsign = [1,1,-1,-1];
    for i = 1:length(Widx)
        ii = vlm.WingIDs{Widx(i)};
        vlm.Normalwash(ii) =  vlm.Normalwash(ii) + atan(dw(ii)./V) - deg2rad(dalpha) * Wsign(i);
    end
end

function [spans,Gs,Ls,IDs,idx] = get_lift_dist(vlm)
    IDs = vlm.WingIDs(1:4);
    IDs = [IDs{:}];
    spans = vlm.Centroid(2,IDs)';
    [spans,idx] = sort(spans);
    IDs = IDs(idx);
    Gs = vlm.G(IDs);
    Ls = vlm.Lprime(IDs);

    spans = [spans(1)-vlm.PanelSpan(IDs(1))/2;spans;spans(end)+vlm.PanelSpan(IDs(end))/2];
    Gs = [0;Gs;0];
    Ls = [0;Ls;0];
end

%% plot result

%plot vlm
f = figure(1);clf;
% subplot(2,1,1)
vlm.draw('param','Lprime');
ax = gca;
ax.Clipping = 'off';
axis equal
colorbar;
hold on
plot3(CoM(1),CoM(2),CoM(3),'k+')

%plot lift dist
[spans,Gs,Ls,IDs,idx] = get_lift_dist(vlm);
ys = (spans-min(spans))/(max(spans)-min(spans))*2-1;
thetas = acos(ys);

[~,b,yfit] = laca.util.Fseries(thetas,Gs,20,false,'sine');
target = gamma_prandtl(abs(ys),0);
[a_target,b_target,yfit_target] = laca.util.Fseries(thetas,target,20,false,'sine');
b_target = b_target./b_target(1).*b(1);   % scale target to same area - special property of sine dist, area = 2*a_1

target = gamma_prandtl(abs(ys),0);

f = figure(2);clf;
hold on
plot(spans,Gs)
plot(spans,yfit,':')
plot(spans,laca.util.Fseriesval(a_target,b_target,thetas,false),'-.')
ylabel('Circulation distribution')
yyaxis right
plot(spans(2:end-1),vlm.Cn(IDs))
ylabel('lift distribution')

if debug
profile viewer;
end

function G = gamma_jones(y,R)
a = (1-4*R/(3*pi))/(2*(1-4/(3*pi)));
b = R/2-a;
G = 2*(a+b/pi).*sqrt(1-y.^2) + 2*b./pi.*y.^2.*acosh(1./abs(y));
G(y==0) = 2*(a+b/pi);
end
function G = gamma_prandtl(y,R)
G = ((1-R.*y.^2).*sqrt(1-y.^2));
end
