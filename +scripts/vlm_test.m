clear all
load('example_data/A220_simple.mat')
ads.Log.setLevel('Debug');

ADP.BuildBaff;


f = figure(1);clf;
ADP.Baff.draw(f,Type="mesh");
axis equal

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

[CoM,m] = ADP.Baff.GetCoM;

f = figure(2);clf;
model.draw
% f.CurrentAxes.ZDir = 'Reverse';
ax = gca;
ax.Clipping = 'off';
axis equal

%% convert to VLM model

vlm_model = laca.vlm.Model.From_laca_model(model,0.5,1,true);

f = figure(3);clf;
vlm_model.draw
f.CurrentAxes.ZDir = 'Reverse';
ax = gca;
ax.Clipping = 'off';
axis equal

%% make rings
V_func = [200 0 0]';
V_dir = V_func./vecnorm(V_func);
% vlm_model = vlm_model.generate_rings();
vlm_model = vlm_model.generate_te_horseshoe(V_dir * 100);

f = figure(4);clf;
vlm_model.draw_rings;
ax = gca;
ax.Clipping = 'off';
axis equal

%% solve
vlm_model = vlm_model.generate_AIC();
% vlm_model = vlm_model.set_panel_filiments();

AoA = 2;
Beta = 0;
V_func = dcrg.rotyd(-AoA)*dcrg.rotzd(-Beta)*[1 0 0]'*200;

vlm_model = vlm_model.solve(V_func);
vlm_model = vlm_model.apply_result_katz(1.225);


f = figure(5);clf;
% subplot(2,1,1)
vlm_model = vlm_model.apply_result_katz(1.225);
vlm_model.draw('param','Cp');
ax = gca;
ax.Clipping = 'off';
axis equal
% subplot(2,1,2)
% vlm_model = vlm_model.apply_result_ring(1.225);
% vlm_model.draw('param','Cp')
% ax = gca;
% ax.Clipping = 'off';
% axis equal

%% try and solve a 'Lift problem'
weight = (m*9.81);

tic;
tt = fminsearch(@(aoa)(trim_sol(vlm_model,aoa,0,CoM)-weight)^2-weight,0)
toc;

tic;
tt = fminsearch(@(x)trim_cost(x,CoM,weight,vlm_model),[0;0])
toc;

f = figure(6);clf;
vlm_model = vlm_model.apply_result_katz(1.225);
vlm_model.draw('param','Cp');
ax = gca;
ax.Clipping = 'off';
axis equal


function val = trim_cost(X,CoM,weight,vlm_model)
[L,p] = trim_sol(vlm_model,X(1),X(2),CoM);
act = [L;p];
target = [weight;0];
val = norm(act-target);
end

function [L,p] = trim_sol(vlm_model,AoA,HTP_AoA,CoM)
idx = [5,6];
sign = [-1,1];
for i = 1:length(idx)
    tmp = vlm_model.Wings{idx(i)};
    for j = 1:length(tmp.Sections)
        tmp.Sections{j}.Normalwash = tmp.Sections{j}.Normalwash.*0 + deg2rad(HTP_AoA)*sign(i);
    end
end
Beta = 0;
V_func = dcrg.rotyd(-AoA)*dcrg.rotzd(-Beta)*[1 0 0]'*200;
vlm_model = vlm_model.solve(V_func);
vlm_model = vlm_model.apply_result_katz(1.225);
W = vlm_model.get_forces_and_moments(CoM);
L = W(3);
p = W(5);
end

%% try simplicifction

vlm_simple = laca.vlm.SimpleModel.from_model(vlm_model);

vlm_simple.generate_AIC();
% vlm_model = vlm_model.set_panel_filiments();

AoA = 2;
Beta = 0;
V_func = dcrg.rotyd(-AoA)*dcrg.rotzd(-Beta)*[1 0 0]'*200;

vlm_simple.solve(V_func);
vlm_simple.apply_result_katz(1.225);


f = figure(7);clf;
% subplot(2,1,1)
vlm_simple.apply_result_katz(1.225);
vlm_simple.draw('param','Cp');
ax = gca;
ax.Clipping = 'off';
axis equal

%% trim simple
weight = (m*9.81);

tic;
tt = fminsearch(@(aoa)(trim_sol_simple(vlm_simple,aoa,0,CoM)-weight)^2-weight,0)
toc;

tic;
tt = fminsearch(@(x)trim_cost_simple(x,CoM,weight,vlm_simple),[0;0])
toc;

% f = figure(6);clf;
% vlm_model = vlm_model.apply_result_katz(1.225);
% vlm_model.draw('param','Cp');
% ax = gca;
% ax.Clipping = 'off';
% axis equal


function val = trim_cost_simple(X,CoM,weight,vlm_model)
[L,p] = trim_sol(vlm_model,X(1),X(2),CoM);
act = [L;p];
target = [weight;0];
val = norm(act-target);
end

function [L,p] = trim_sol_simple(vlm_model,AoA,HTP_AoA,CoM)
idx = [5,6];
sign = [-1,1];
for i = 1:length(idx)
    vlm_model.Normalwash(vlm_model.WingIDs{idx(i)}) = deg2rad(HTP_AoA)*sign(i);
end
Beta = 0;
V_func = dcrg.rotyd(-AoA)*dcrg.rotzd(-Beta)*[1 0 0]'*200;
vlm_model = vlm_model.solve(V_func);
vlm_model = vlm_model.apply_result_katz(1.225);
W = vlm_model.get_forces_and_moments(CoM);
L = W(3);
p = W(5);
end

%% try newton raphson


function [N,NW,AIC,C,id] = setup_trim_problem(vlm_model)
    idx = [5,6];
    sign = [-1,1];
    tmpNW = {};
    vals = [0,cumsum(cellfun(@(x)x.NPanels,vlm_model.Wings))];
    id = {};
    for i = 1:length(idx)
        id{i} = (vals(idx-1)+1):vals(idx);
    end
    
    N = vlm_model.Normal;
    NW = vlm_model.Normalwash;
    AIC = vlm_model.AIC;
    C = vlm_model.Connectivity;
    
end