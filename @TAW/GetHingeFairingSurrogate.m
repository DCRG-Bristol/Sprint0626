function [K_fair,M_fair] = GetHingeFairingSurrogate(ADP)
%GETHINGEFAIRINGSURROGATE Summary of this function goes here
% Calculates the added torsional stiffness and mass by the hinge fairing 

% Variables (bounded to interpolation range)
AR = min(max(ADP.AR,12),22);
SweepAngle = min(max(ADP.SweepAngle,0),40);
HingeEta = min(max(ADP.HingeEta,0.5),0.95);
FlareAngle = min(max(ADP.FlareAngle,5),35);
M_c = min(max(ADP.ADR.M_c,0.5),0.85);

%% interpolation

% load dataset
File = load(fullfile(fileparts(mfilename('fullpath')),'private','Fairing_Stiffness_Mass.mat'));
dataset = File.dataset;
sample_size = size(dataset);
sample_size(2) = sample_size(2)-2;

% Determine the size of each dimension
NumEachVar = sample_size(1)^(1/sample_size(2));

% Reshape each column of meshGrid back to the original dimensions
V1 = reshape(dataset(:, 1), [NumEachVar, NumEachVar, NumEachVar, NumEachVar, NumEachVar]);
V2 = reshape(dataset(:, 2), [NumEachVar, NumEachVar, NumEachVar, NumEachVar, NumEachVar]);
V3 = reshape(dataset(:, 3), [NumEachVar, NumEachVar, NumEachVar, NumEachVar, NumEachVar]);
V4 = reshape(dataset(:, 4), [NumEachVar, NumEachVar, NumEachVar, NumEachVar, NumEachVar]);
V5 = reshape(dataset(:, 5), [NumEachVar, NumEachVar, NumEachVar, NumEachVar, NumEachVar]);
V6 = reshape(dataset(:, 6), [NumEachVar, NumEachVar, NumEachVar, NumEachVar, NumEachVar]);
V7 = reshape(dataset(:, 7), [NumEachVar, NumEachVar, NumEachVar, NumEachVar, NumEachVar]);


% Assuming V6 and V7 are already reshaped as given
V_combined = cell(size(V6)); % Initialize a cell array of the same size
for i = 1:numel(V6)
    V_combined{i} = [V6(i), V7(i)];
end

% Interpolation
if ~ADP.EnableFairingStiffness
    K_fair = 0;
else
    K_fair = interpn(V1,V2,V3,V4,V5,V6,AR,SweepAngle,HingeEta,FlareAngle, M_c); 
end
M_fair = interpn(V1,V2,V3,V4,V5,V7,AR,SweepAngle,HingeEta,FlareAngle, M_c);


end