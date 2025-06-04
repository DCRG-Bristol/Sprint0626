load('C:\git\Sprint0626\+loads\+sandbox\LiftDistData.mat')
% convert to struct
res = struct.empty;
for i = 1:length(data)
    res = dcrg.struct.concat(res,data{i});
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
tmp = dcrg.struct.filter(res_LD,struct('IsFree',false));
ys = tmp(1).Ys;
Y = [tmp.L];
P = [[tmp.AR];[tmp.HingeEta];[tmp.SweepAngle];[tmp.G]]';
P_mean = mean(P);
P_std = std(P);
P_norm = (P - P_mean) ./ P_std;

% PCA analysis on lift dists
k = 6;
[coeff, score, ~, ~, explained, mu] = pca(Y','NumComponents', k);  % Y' is 200×1000

% coeff = coeff(:,1:k);
% score = score(:,1:k);

% plot PCAs
f = figure(12);
clf;
hold on
for i = 1:k
    plot(ys,coeff(:,i))
end

% build model for each PCA direction
mdl_LD = {};
for i = 1:k
    % mdl_LD{i} = fitrgp(P, score(:, i));
    mdl_LD{i} = fitrnet(P_norm, score(:, i), 'LayerSizes', 10);
end


%% tst pred
tmp = dcrg.struct.filter(res_LD,struct('IsFree',false));

%predict lift dist
score_pred = zeros(1, k);
% p_new = [15,0.8,0,1];
idx = 1;
p_new = [tmp(idx).AR,tmp(idx).HingeEta,tmp(idx).SweepAngle,tmp(idx).G];
p_new = [22,0.8,0,1];
p_new= (p_new-P_mean)./P_std;
% p_new = [0 0 0 0];
% p_new = P(1,:);
for j = 1:k
    score_pred(j) = predict(mdl_LD{j}, p_new);  % p_new is 1×4
end
% Reconstruct full 1000×1 vector
y_pred = coeff * score_pred' + mu';

f = figure(1);

clf;
plot(ys,y_pred)
hold on
% for i = 1:length(tmp)
    plot(ys,tmp(idx).L)
% end


%% make plot
f = figure(2);
tmp = dcrg.struct.filter(res_LD,struct('IsFree',false,'G',[2.5]));
clf;
% plot(ys,y_pred)
hold on
for i = 1:length(tmp)
    plot(ys,tmp(i).L)
end





% f = figure(1);
% clf;
% 
% tmp = dcrg.struct.filter();
% plot()
