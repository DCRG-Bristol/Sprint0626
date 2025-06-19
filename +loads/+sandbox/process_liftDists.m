load('C:\git\Sprint0626\+loads\bin\LiftDistData2.mat')
% convert to struct
res = struct.empty;
for i = 1:length(data)
    if ~isempty(data{i})
        res = dcrg.struct.concat(res,data{i});
    end
end
% extract key distributions
res_LD = struct.empty;
for i = 1:length(res)
    tmp = struct();
    tmp.AR = res(i).AR;
    tmp.HingeEta = res(i).HingeEta;
    tmp.SweepAngle = res(i).SweepAngle;
    tmp.IsFree = true;
    tmp.G = nan;
    tmp.Ys = res(i).Lds(1).Meta(1).LiftDistYs';
    tmp.Ys = (tmp.Ys-min(tmp.Ys))/(max(tmp.Ys)-min(tmp.Ys));

    tmp.G = 2.5;
    tmp.L = res(i).Lds(1).Meta(2).LiftDist';
    tmp.L = tmp.L./trapz(tmp.Ys,tmp.L);
    res_LD = dcrg.struct.concat(res_LD,tmp);

    tmp.G = 1;
    tmp.L = res(i).Lds(1).Meta(4).LiftDist';
    tmp.L = tmp.L./trapz(tmp.Ys,tmp.L);
    res_LD = dcrg.struct.concat(res_LD,tmp);

    tmp.G = -1;
    tmp.L = res(i).Lds(1).Meta(5).LiftDist';
    tmp.L = tmp.L./trapz(tmp.Ys,tmp.L);
    res_LD = dcrg.struct.concat(res_LD,tmp);

    tmp.IsFree = false;
    tmp.G = 2.5;
    tmp.L = res(i).Lds(1).Meta(6).LiftDist';
    tmp.L = tmp.L./trapz(tmp.Ys,tmp.L);
    res_LD = dcrg.struct.concat(res_LD,tmp);

    tmp.G = 1;
    tmp.L = res(i).Lds(1).Meta(8).LiftDist';
    tmp.L = tmp.L./trapz(tmp.Ys,tmp.L);
    res_LD = dcrg.struct.concat(res_LD,tmp);

    tmp.G = -1;
    tmp.L = res(i).Lds(1).Meta(9).LiftDist';
    tmp.L = tmp.L./trapz(tmp.Ys,tmp.L);
    res_LD = dcrg.struct.concat(res_LD,tmp);
end


% fit locked distributions
tmp = dcrg.struct.filter(res_LD,struct('IsFree',false,'G',2.5));
ys = tmp(1).Ys;
Y = [tmp.L];
P = [[tmp.AR];[tmp.SweepAngle]]';
P_mean = mean(P);
P_std = std(P);
P_norm = (P - P_mean) ./ P_std;

% PCA analysis on lift dists
k = 10;
[coeff, score, ~, ~, explained, mu] = pca(Y','NumComponents', k);  % Y' is 200×1000

% coeff = coeff(:,1:k);
% score = score(:,1:k);

% plot PCAs
f = fh.pubFig(Num=2,Size = [12,6]);
for i = 1:k
    plot((ys-0.5)*2,coeff(:,i),LineWidth=1)
end
t = title('First 5 2.5G "Modes"');
t.FontSize = 14;
xlabel('Norm. Y')
ylabel('Norm $\bar{L}$')
copygraphics(gcf,"ContentType","vector")


% build model for each PCA direction
mdl_LD = {};
for i = 1:k
    % mdl_LD{i} = fitrgp(P, score(:, i));
    mdl_LD{i} = fitrnet(P_norm, score(:, i), 'LayerSizes', 10);
end


%% tst pred
% tmp = dcrg.struct.filter(res_LD,struct('IsFree',false));

%predict lift dist
score_pred = zeros(1, k);
% p_new = [15,0.8,0,1];
idx = 50;
p_new = P_norm(idx,:);
% p_new = [0 0 0 0];
% p_new = P(1,:);
for j = 1:k
    score_pred(j) = predict(mdl_LD{j}, p_new);  % p_new is 1×4
end
% Reconstruct full 1000×1 vector
y_pred = coeff * score_pred' + mu';


% plot PCAs
f = fh.pubFig(Num=3,Size = [12,6]);
plot((ys-0.5)*2,y_pred,LineWidth=1.5,DisplayName='Prediction')
plot((ys-0.5)*2,tmp(idx).L,'-.',LineWidth=1.5,DisplayName='Actual')
lg = legend();
lg.Location = 'south';
lg.FontSize = 14;
xlabel('Norm. Y')
ylabel('Norm $\bar{L}$')
copygraphics(gcf,"ContentType","vector")
t = title(sprintf('AR: %.0f, Sweep: %.1f',P(idx,1),P(idx,2)));
t.FontSize = 14;

%% fake wingtip
etas = (ys-0.5)*2;
offset = fminsearch(@(x)wt_cost(x,etas,0.7),0);
% idx = etas>=0.7;
[zs,~,~] = wt_lift_dist(etas,0.7,offset);

zs = zs*0.6;
f = fh.pubFig(Num=4,Size = [12,6]);
plot(etas,y_pred,LineWidth=1.5,DisplayName='Locked')
plot(etas,-zs,LineWidth=1.5,DisplayName='Wingtip Adjustment')
plot(etas,y_pred-zs,LineWidth=1.5,DisplayName='Final')
p=plot([0.7,0.7],[0,max(y_pred-zs)],'k--');
p.Annotation.LegendInformation.IconDisplayStyle = 'off';
p=plot([-0.7,-0.7],[0,max(y_pred-zs)],'k--');
p.Annotation.LegendInformation.IconDisplayStyle = 'off';

lg = legend();
lg.Location = 'south';
lg.FontSize = 12;
xlabel('Norm. Y')
ylabel('Norm $\bar{L}$')
copygraphics(gcf,"ContentType","vector")
t = title(sprintf('AR: %.0f, Sweep: %.1f',P(idx,1),P(idx,2)));
t.FontSize = 14;



%% make plot
f = fh.pubFig(Num=2,Size = [12,6]);
tmp = dcrg.struct.filter(res_LD,struct('IsFree',false,'G',[1],'HingeEta',1));
% plot(ys,y_pred)
hold on
for i = 1:length(tmp)
    plot((ys-0.5)*2,tmp(i).L,LineWidth=1)
end
xlabel('Norm. Y')
ylabel('Norm $\bar{L}$')
copygraphics(gcf,"ContentType","vector")







function [zs,A,A_wt] = wt_lift_dist(eta,hingeEta,offset)
l_wt = (1-hingeEta);
xs = abs(eta);
zs = ones(size(eta));
m_t = l_wt;
zs(xs>=hingeEta) = sqrt(1-(2*(xs(xs>=hingeEta)-hingeEta)/(l_wt*2)).^2);
zs = zs.*((1/2*((tanh((eta-hingeEta)*6/m_t)-tanh((eta+hingeEta)*6/m_t)))+1)*(1+offset)-offset);
A = trapz(eta,zs);
A_wt = abs(trapz(eta(xs<=hingeEta),zs(xs<=hingeEta)));
end

function val = wt_cost(offset,eta,hingeEta)
    [~,A] = wt_lift_dist(eta,hingeEta,offset);
    val = A^2;
end