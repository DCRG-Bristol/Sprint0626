% clear all
% close all
% load('example_data/A220_simple.mat')
% ads.Log.setLevel('Debug');
% 
% % ADP.TaperRatio = 1;
% % ADP.SweepAngle = 0;
% % ADP.Dihedral = 0;
% ADP.BuildBaff;
% 
% % f = figure(1);clf;
% % ADP.Baff.draw(f,Type="mesh");
% % axis equal
% 
% % convert baff to LACA model
% wings = {};
% % for i = 1:numel(ADP.Baff.Wing)
% for i = 1:6
%     bw = ADP.Baff.Wing(i);
%     % extract LE points and Chord lengths at each aero station
%     chords = bw.AeroStations.Chord;
%     LE = bw.GetGlobalWingPos(bw.AeroStations.Eta,0);
%     TE = bw.GetGlobalWingPos(bw.AeroStations.Eta,1);
%     wings{end+1} = laca.model.Wing.From_LE_TE(LE,TE,{});
%     wings{end}.Name = bw.Name;
% end
% 
% model = laca.model.Aircraft(wings);
% model.Name = 'test';
% 
% [CoM,m] = ADP.Baff.GetCoM;
%% convert to VLM model
vlm_tmp = laca.vlm.Model.From_laca_model(model,10,1,true);
vlm_tmp.Stitch();
vlm = vlm_tmp.Simplify();

f = figure(3);clf;
vlm.draw
f.CurrentAxes.ZDir = 'Reverse';
ax = gca;
ax.Clipping = 'off';
axis equal

%% make rings
V_func = [200 0 0]';
V_dir = V_func./vecnorm(V_func);
vlm = vlm.generate_te_horseshoe(V_dir * 100);

%% solve
vlm = vlm.generate_AIC();

trim_sol(vlm,1,1,CoM)

f = figure(5);clf;
% subplot(2,1,1)
vlm.draw('param','Lprime');
ax = gca;
ax.Clipping = 'off';
axis equal
colorbar;
hold on
plot3(CoM(1),CoM(2),CoM(3),'k+')

function W = trim_sol(vlm,AoA,HTP_AoA,CoM)
idx = [5,6];
sign = [1,-1];
for i = 1:length(idx)
    vlm.Normalwash(vlm.WingIDs{idx(i)}) = deg2rad(HTP_AoA)*sign(i);
end
Beta = 0;
V_func = dcrg.rotyd(-AoA)*dcrg.rotzd(-Beta)*[1 0 0]'*200;
vlm = vlm.solve(V_func);
vlm = vlm.apply_result_katz(1.225);
W = vlm.get_forces_and_moments(CoM);
W = W([3,5],1);
end

%% trim
Widx = [1,2,3,4];
for i = 1:length(Widx)
    ii = vlm.WingIDs{Widx(i)};
    vlm.Normalwash(ii) = vlm.Normalwash(ii)*0;
end

weight = (m*9.81);
% profile on;
tic;
f0 = trim([0;0],CoM,weight,vlm);
toc;
% profile off;
disp(f0)

% profile viewer;

function f0 = trim(f0,CoM,weight,vlm)
cost = @(X)trim_sol(vlm,X(1),X(2),CoM)-[weight;0];
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

% plot Lift distribution

f = figure(1);
clf
IDs = vlm.WingIDs(1:4);
IDs = [IDs{:}];

spans = vlm.Centroid(2,IDs)';
[spans,idx] = sort(spans);
IDs = IDs(idx);

Ls = vlm.G(IDs);
Cls = vlm.Cl(IDs);

% add tips
spans = [spans(1)-vlm.PanelSpan(IDs(1))/2;spans;spans(end)+vlm.PanelSpan(IDs(end))/2];
Ls = [0;Ls;0];
Cls = [0;Cls;0];

% Ls = Ls./max(Ls);

plot(spans,Ls)
% fit cosine distribution
ys = (spans-min(spans))/(max(spans)-min(spans))*2-1;
thetas = acos(ys);

[a,b,yfit] = laca.util.Fseries(thetas,Ls,5,false,'sine');
hold on
plot(spans,yfit,':')
gamma_prandtl(abs(ys),0)
plot(spans,gamma_prandtl(abs(ys),0))
[ae,be,yfite] = laca.util.Fseries(thetas,gamma_prandtl(abs(ys),0),2,false,'sine');
disp([ae';be',0])
plot(spans,yfite,':')

ylabel('lift distribution')
yyaxis right
plot(spans,Cls)
ylabel('Cl distribution')
xlabel('Span [m]')


% update lift distribution to be target shape



rIDs = vlm.WingIDs(1:2);
lIDs = vlm.WingIDs(3:4);
iIDs = [-1*[rIDs{:}],[lIDs{:}]];
iIDs = sign(iIDs(idx))';

f = figure(11);
clf;
plot(spans,Ls)

[a,b,yfit] = laca.util.Fseries(thetas,Ls,20,false,'sine');
hold on
plot(spans,yfit,':')
plot(spans,laca.util.Fseriesval([0,0],b(1),thetas,false))
dG = -laca.util.Fseriesval(a,[0;b(2:end)],thetas,false);
plot(spans,dG)
plot(spans(2:end-1),vlm.Gamma(IDs))

dGamma = vlm.Gamma*0;
dGamma(IDs) = dG(2:end-1).*iIDs;

dw = vlm.AIC*dGamma;

Widx = [1,2,3,4];
Wsign = [1,1,1,1];
for i = 1:length(Widx)
    ii = vlm.WingIDs{Widx(i)};
    vlm.Normalwash(ii) = atan(dw(ii)./200)*Wsign(i);
end

% rerun vlm
trim_sol(vlm,f0(1),f0(2),CoM);

f = figure(5);clf;
% subplot(2,1,1)
vlm.draw('param','Lprime');
ax = gca;
ax.Clipping = 'off';
axis equal
colorbar;
hold on
plot3(CoM(1),CoM(2),CoM(3),'k+')


f = figure(6);
clf
IDs = vlm.WingIDs(1:4);
IDs = [IDs{:}];

spans = vlm.Centroid(2,IDs)';
[spans,idx] = sort(spans);
IDs = IDs(idx);

Ls = vlm.G(IDs);
Cls = vlm.Cl(IDs);

% add tips
spans = [spans(1)-vlm.PanelSpan(IDs(1))/2;spans;spans(end)+vlm.PanelSpan(IDs(end))/2];
Ls = [0;Ls;0];
Cls = [0;Cls;0];
twists = vlm.Normalwash(IDs);

% Ls = Ls./max(Ls);

plot(spans,Ls)
% fit cosine distribution
ys = (spans-min(spans))/(max(spans)-min(spans))*2-1;
thetas = acos(ys);

[a,b,yfit] = laca.util.Fseries(thetas,Ls,5,false,'sine');
hold on
plot(spans,yfit,':')
plot(spans,laca.util.Fseriesval([0,0],b(1),thetas,false),'-.')

ylabel('lift distribution')
yyaxis right
plot(spans(2:end-1),rad2deg(twists).*iIDs)
ylabel('Cl distribution')
xlabel('Span [m]')



function G = gamma_jones(y,R)
a = (1-4*R/(3*pi))/(2*(1-4/(3*pi)));
b = R/2-a;
G = 2*(a+b/pi).*sqrt(1-y.^2) + 2*b./pi.*y.^2.*acosh(1./abs(y));
G(y==0) = 2*(a+b/pi);
end
function G = gamma_prandtl(y,R)
G = ((1-R.*y.^2).*sqrt(1-y.^2));
end
