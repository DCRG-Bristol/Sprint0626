function [res] = get_aero_force(filename)
%READ_DISPLACEMENTS Reads the displacements from the .h5 file 
% Author: Fintan Healy
% Contact: fintan.healy@bristol.ac.uk
% Created: 06/03/2023
% Modified: 06/03/2023
%
% Change Log:
%   - 
% ======================================================================= %

% get eigenvalues
meta = h5read(filename,'/INDEX/NASTRAN/RESULT/AERODYNAMIC/FORCE');
data = h5read(filename,'/NASTRAN/RESULT/AERODYNAMIC/FORCE');
%convert to familar format
res = struct();
for i = 1:length(meta.DOMAIN_ID)
    idx = data.DOMAIN_ID == meta.DOMAIN_ID(i);
    res(i).ID       =  data.GRID(idx);   %   grid point IDs
    res(i).Label    =  data.LABEL(idx);  %
    res(i).F       =  [data.T1(idx),data.T2(idx),data.T3(idx)];   %
    res(i).M =  [data.R1(idx),data.R2(idx),data.R3(idx)] ;  % 
end

end