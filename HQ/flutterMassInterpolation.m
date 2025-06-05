%saved data......
input = data_all(:,1:3); 
output = data_all(:,4);

%% INTERPOLATION 

AR_lower_bound = 10; AR_upper_bound = 22;
HingeEta_lower_bound = 0.5; HingeEta_upper_bound = 0.9;
SweepAngle_lower_bound = 0; SweepAngle_upper_bound = 40;

N_grid_size = 20;
AR_grid = linspace(AR_lower_bound, AR_upper_bound, N_grid_size);
HingeEta_grid = linspace(HingeEta_lower_bound, HingeEta_upper_bound, N_grid_size);
SweepAngle_grid = linspace(SweepAngle_lower_bound, SweepAngle_upper_bound, N_grid_size);

% we are interested at N_query_SweepAngle (equally spaced) 
% N_query_SweepAngle = 4;
% SweepAngle_query_location = floor(linspace(1, N_grid_size, N_query_SweepAngle));
% SweepAngle_query = SweepAngle_grid(SweepAngle_query_location);

% N_query_HingeEta = 4;
% HingeEta_query_location = floor(linspace(1, N_grid_size, N_query_HingeEta));
% HingeEta_query = HingeEta_grid(HingeEta_query_location);

N_query_AR = 4;
AR_query_location = floor(linspace(1, N_grid_size, N_query_AR));
AR_query = AR_grid(AR_query_location);

% for ii = 1:size(masses_data, 1)
%     mass_interp = scatteredInterpolant(HP_data(:, active_HP), reshape(masses_data(ii, :), [], 1));
%     [xq,yq,zq] = meshgrid(AR_grid, HingeEta_grid, SweepAngle_grid);
%     total_flutter_mass = total_flutter_mass + max(mass_interp(xq, yq, zq), 0);
% end

x_interp = scatteredInterpolant(input, reshape(output, [], 1));
[xq,yq,zq] = meshgrid(AR_grid, SweepAngle_grid, HingeEta_grid);

x_out = x_interp(xq, yq, zq);

%% make plots
for jj = 1:N_query_HingeEta
    % [xq2d,yq2d] = meshgrid(AR_grid, SweepAngle_grid);
    [yq2d,zq2d] = meshgrid(SweepAngle_grid, HingeEta_grid);
    figure
    % surf(xq2d, yq2d, x_out(:, :, HingeEta_query_location(jj)))
    surf(yq2d, zq2d, reshape(x_out(AR_query_location(jj), :, :), [N_grid_size N_grid_size]))
    xlabel('Sweep angle')
    ylabel('Hinge Eta')
    % xlabel('AR')
    % ylabel('Sweep angle')
    zlabel('x0')
    % title(sprintf('Total mass to be added to avoid flutter (sweep angle fixed at: %.2f deg)', SweepAngle_query(jj)))
end

% figure
% surf(xq2d, yq2d, zeros(size(xq2d)))
% xlabel('AR')
% ylabel('HingeEta')
% zlabel('Total Flutter Mass (kg)')
% zlim([0, 1])
% title(sprintf('Total mass to be added to avoid flutter (sweep angle fixed at: %.2f deg)', SweepAngle_query(jj)))

% it works, but prefer 'surf' plot:
% xslice = [];
% yslice = [];
% zslice = [SweepAngle_query(jj)];
% slice(xq, yq, zq, masses_slices, xslice, yslice, zslice)
% colorbar

%%
% N_linspace_mach_to_sweep = 1e3;
% mach_number_candidates = linspace(0.5, 0.85, N_linspace_mach_to_sweep );
% adp_mstar = 0.935;
% sweep_angle_candidates = zeros(N_linspace_mach_to_sweep, 1);
% for ii =1:N_linspace_mach_to_sweep 
%     sweep_angle_candidates(ii) = real(acosd(0.75.*adp_mstar/mach_number_candidates(ii)));
% end    
% 
% %%
% figure
% plot(mach_number_candidates, sweep_angle_candidates)