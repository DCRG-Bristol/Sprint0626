function StaticStabilityCorrections(obj)
%STATICSTABILITYCORRECTIONS Summary of this function goes here
%   Detailed explanation goes here

ar = obj.AR;
he = obj.HingeEta;
fa = obj.FlareAngle;
Mc = obj.ADR.M_c;
sa = obj.SweepAngle;

% buid Surrogate 
source = load(fullfile(fileparts(mfilename('fullpath')),'private','SM_x_data.mat'),'data_all');

input = source.data_all(:,1:3); 
output = source.data_all(:,4);
output = reshape(output, [], 1);
[input,idx] = unique(input,'rows');
output = output(idx);
x_interp = scatteredInterpolant(input, reshape(output, [], 1));

obj.StaticMargin = x_interp(ar,sa, he);

%% 

% obj.V_HT = 1.4626;
% obj.V_VT = 0.0847;

end







