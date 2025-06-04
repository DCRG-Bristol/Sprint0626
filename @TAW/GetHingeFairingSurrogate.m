function [K_fair,M_fair] = GetHingeFairingSurrogate(ADP)
%GETHINGEFAIRINGSURROGATE Summary of this function goes here
% Calculates the added torsional stiffness and mass by the hinge fairing 

% Variables
AR = ADP.AR;
SweepAngle = ADP.SweepAngle;
HingeEta = ADP.HingeEta;
FlareAngle = ADP.FlareAngle;
M_c = ADP.ADR.M_c;


%% Checking for ranges
% Values
values = {
    'AR', AR;
    'SweepAngle', SweepAngle;
    'HingeEta', HingeEta;
    'FlareAngle', FlareAngle;
    'M_c', M_c
};

% Ranges
ranges = {
    'AR', [12, 22];
    'SweepAngle', [0, 40];
    'HingeEta', [0.5, 0.99];
    'FlareAngle', [5, 35];
    'M_c', [0.5, 0.85]
};

% Check ranges and raise error if out of range
for i = 1:size(ranges, 1)
    param = ranges{i, 1};
    range = ranges{i, 2};
    value = values{i, 2};

    if isempty(value)
        error('Value for %s is empty', param);
    end
   
    if value < range(1) || value > range(2)
        error('Value for %s is out of range: %f (expected between %f and %f)', param, value, range(1), range(2));
    end
end


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
if ~obj.EnableFairingStiffness
    K_fair = 0;
else
    K_fair = interpn(V1,V2,V3,V4,V5,V6,AR,SweepAngle,HingeEta,FlareAngle, M_c); 
end
M_fair = interpn(V1,V2,V3,V4,V5,V7,AR,SweepAngle,HingeEta,FlareAngle, M_c);


end