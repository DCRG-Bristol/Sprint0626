function uncertain_variables_exploration(surrogates, inputs_names, outputs_names, plots_title, N_eval, seed, plotsfolderName)
%% Title section - Plots generator for parameter sweeps for the uncertain variables
%{
--------------------------------------------------------
Comments:
* This code generates plots for each quantity of interest (QI; outputs) as a function of the uncertain variables (inputs)
* The maps between the uncertain variables and the QIs are provided by pre-trained surrogate models (PCE or Kriging)
* If there is more than one uncertain variable, the code makes 2D contour plots for each combination of two uncertain variables 
* It only works for independent Gaussian or Uniform variables (use UQLab for other probability distributions)
* In the context of optimisation (e.g., want to minimise various QIs), this function can be used for design exploration, sensitivity analysis, ...
    * Without loss of generality, the design variables are treated as uncertain variables:
        * Each design variable x with bounds for optimisation: [lb_x, ub_x] is defined in UQLab as an uncertain variable with a Uniform probability distribution over the interval [lb_x, ub_x]
--------------------------------------------------------
Input:
* surrogates        : UQLab object; contains one independent surrogate for each QI
* input_names       : list of the names of the uncertain variables
* output_names      : list of the names of the QIs
* plots_title       : descriptive title for the plots 
* N_eval            : number of discretisation points for each uncertain variable
* seed              : seed for reproducibility due to randomness in sampling the data for the parallel coordinate plots (PCP) and histograms
* plotsfolderName   : the name of subfolder where the plots will be added
--------------------------------------------------------
Output:
* This code generates various plots for each QI as a function of the uncertain variables (including sensitivity analysis, ...)  
--------------------------------------------------------
%}

%% 0. Set seed for reproducibility
rng(seed, 'twister')

%% 1. Extract some properties of the physical system
input_distributions = surrogates.Options.Input;         % probability distributions of the uncertain variables

%% 2. Discretise the uncertain variables in preparation for plotting
N_variables = length(input_distributions.Marginals);    % number of uncertain variables
N_outputs = size(surrogates.ExpDesign.Y, 2);            % number of quantities of interest (QIs)
eval_locations = zeros(N_eval, N_variables);            % initialise the discretisation matrix for plots 
lower_bounds = zeros(N_variables, 1);                   % initialise the lower bounds for discretisation
upper_bounds = zeros(N_variables, 1);                   % initialise the upper bounds for discretisation

for ii = 1:N_variables
    if strcmp(input_distributions.Marginals(ii).Type, 'Gaussian')
        % extract the mean and sigma
        mean_value = input_distributions.Marginals(ii).Parameters(1);
        sigma_value = input_distributions.Marginals(ii).Parameters(2);
        lower_bounds(ii) = mean_value - 2*sigma_value;
        upper_bounds(ii) = mean_value + 2*sigma_value; 
        % discretise the uncertain variable in preparation for the contour plots
        eval_locations(:, ii) = linspace(lower_bounds(ii), upper_bounds(ii), N_eval)'; 
    elseif strcmp(input_distributions.Marginals(ii).Type, 'Uniform')
        % extract the whole uncertain interval
        lower_bounds(ii) = input_distributions.Marginals(ii).Parameters(1);
        upper_bounds(ii) = input_distributions.Marginals(ii).Parameters(2);
        % discretise the uncertain variable in preparation for the contour plots
        eval_locations(:, ii) = linspace(lower_bounds(ii), upper_bounds(ii), N_eval)';
    else 
        disp('This function only works for independent Uniform or Gaussian variables')
        return;
    end    
end

%% 3. 1D parameter sweeps 
% Plot each quantity of interest (QI) as a function of the uncertain variables
eval_points = zeros(N_eval, N_variables);   % initialise using the total number of discretisation points
for jj = 1:N_variables
    eval_points(:, jj) = (upper_bounds(jj)+lower_bounds(jj))/2;     % the uncertain variables are fixed to their mean value
end
for ii = 1:N_variables
    eval_points(:, ii) = eval_locations(:, ii);                     % discretisation of the uncertain variable in preparation for the plot
    surrogates_output = uq_evalModel(surrogates, eval_points);      % evaluate the surrogates at the discretisation points (i.e., get all QIs)
    for kk = 1:N_outputs
        % make a plot for each QI as a function of the uncertain variable
        fig = figure();
        plot(eval_locations(:, ii), surrogates_output(:, kk));
        title(plots_title)         % description of the surrogate
        xlabel(inputs_names(ii))   % name of the uncertain variable
        ylabel(outputs_names(kk))  % name of the QI
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variable_%u_1D_plot.png', kk, ii)))
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variable_%u_1D_plot.fig', kk, ii)))
    end
    eval_points(:, ii) = (upper_bounds(ii)+lower_bounds(ii))/2;     % the uncertain variables are fixed to their mean value
end

%% 4. 2D contour plots
% for each QI, collect data for 2D contour plots for all pairs of uncertain variables 
if N_variables >= 2
    pairwise_combinations = nchoosek(1:N_variables, 2); 
    for ii = 1:size(pairwise_combinations, 1)
        [Eval_locations_x, Eval_locations_y] = meshgrid(eval_locations(:, pairwise_combinations(ii, 1)), eval_locations(:, pairwise_combinations(ii, 2)));
        eval_points = zeros(length(Eval_locations_x(:)), N_variables); % initialise using the total number of discretisation points
        for jj = 1:N_variables
            if jj == pairwise_combinations(ii, 1)
                eval_points(:, jj) = Eval_locations_x(:); % discretisation for the uncertain variable to be ploted on the x-axis
            elseif jj == pairwise_combinations(ii, 2)
                eval_points(:, jj) = Eval_locations_y(:); % discretisation for the uncertain variable to be ploted on the y-axis
            else
                eval_points(:, jj) = (upper_bounds(jj)+lower_bounds(jj))/2; % the other uncertain variables are fixed to their mean value
            end
        end
        surrogates_output = uq_evalModel(surrogates, eval_points); % evaluate the surrogates at the discretisation points (i.e., get all QIs)
        % extract the training set (a.k.a. experimental design) points that are within the plotting bounds
        rowsToKeep = all(surrogates.ExpDesign.X(:, pairwise_combinations(ii, 1)) >= lower_bounds(pairwise_combinations(ii, 1)) & surrogates.ExpDesign.X(:, pairwise_combinations(ii, 1)) <= upper_bounds(pairwise_combinations(ii, 1)) & ...
            surrogates.ExpDesign.X(:, pairwise_combinations(ii, 2)) >= lower_bounds(pairwise_combinations(ii, 2)) & surrogates.ExpDesign.X(:, pairwise_combinations(ii, 2)) <= upper_bounds(pairwise_combinations(ii, 2)), 2);
        filteredMatrix = surrogates.ExpDesign.X(rowsToKeep, :);
        if size(filteredMatrix, 1) > 5e2
            sampleSize = 5e2;
            idx = randperm(size(filteredMatrix, 1), sampleSize);
            filteredMatrix_sample = filteredMatrix(idx, :);
        else
            filteredMatrix_sample = filteredMatrix;
        end
        for kk = 1:N_outputs
            % for each QI, make a contour plot for each combination of two uncertain variables 
            fig = figure();
            contourf(Eval_locations_x, Eval_locations_y, reshape(surrogates_output(:, kk), [N_eval, N_eval]), 40);
            hold on
            scatter(filteredMatrix_sample(:, pairwise_combinations(ii, 1)), filteredMatrix_sample(:, pairwise_combinations(ii, 2)), 100, 'r', 'filled', 'DisplayName', 'Training Data');
            title(sprintf('%s; %s', outputs_names(kk), plots_title))                                 % description of the surrogate
            xlabel(inputs_names(pairwise_combinations(ii, 1))) % name of the uncertain variable to be ploted on the x-axis
            ylabel(inputs_names(pairwise_combinations(ii, 2))) % name of the uncertain variable to be ploted on the y-axis
            legend('Contour Lines', 'Training Data', 'Location', 'best');
            colorbar
            set(gcf, 'Position',  [100, 100, 800, 800])
            saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variables_%u_and_%u_2D_contour_plot.png', kk, pairwise_combinations(ii, 1), pairwise_combinations(ii, 2))))
            saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variables_%u_and_%u_2D_contour_plot.fig', kk, pairwise_combinations(ii, 1), pairwise_combinations(ii, 2))))
        end
    end    
end    

% %% 5. Parallel coordinate plots (PCP) 
% N_MC = 10^5;
% inputs_for_pcp = uq_getSample(input_distributions, N_MC, 'LHS');            % generate N_MC Latin Hypercube points in the uncertain variables' space
% outputs_for_pcp = uq_evalModel(surrogates, inputs_for_pcp);                 % evaluate the surrogates to get QIs data for the PCP
% for kk = 1:N_outputs
%     % for each QI, make a PCP as a function of all the uncertain variables 
%     fig = figure();
%     p = parallelplot([inputs_for_pcp, outputs_for_pcp(:, kk)]);
%     p.CoordinateTickLabels = [inputs_names, outputs_names(kk)];
%     lower_bin = quantile(outputs_for_pcp(:, kk), 0.05);                      % only 10% of the observations are below this value
%     upper_bin = quantile(outputs_for_pcp(:, kk), 0.95);                      % only 10% of the observations are above this value
%     bin_edges = [min(outputs_for_pcp(:, kk)), lower_bin, upper_bin, max(outputs_for_pcp(:, kk))];
%     % split the data into 3 bins (groups)
%     bins = ["low", "med", "high"];                                          
%     groupHeight = discretize(outputs_for_pcp(:, kk), bin_edges, 'categorical', bins);
%     p.GroupData = groupHeight;
%     p.Title = sprintf('%s; %s', outputs_names(kk), plots_title);
%     set(gcf, 'Position',  [100, 100, 800, 800])
%     saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variables_parallel_coordinates_plot.png', kk)))
%     saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variables_parallel_coordinates_plot.fig', kk)))
% end

%% 5. Parallel coordinate plots (PCP) 
N_MC = 10^5;
inputs_for_pcp = uq_getSample(input_distributions, N_MC, 'LHS');            % generate N_MC Latin Hypercube points in the uncertain variables' space
outputs_for_pcp = uq_evalModel(surrogates, inputs_for_pcp);                 % evaluate the surrogates to get QIs data for the PCP
for kk = 1:N_outputs
    var_qi = outputs_for_pcp(:, kk);
    group = repmat("Mid", size(outputs_for_pcp, 1), 1);
    group(var_qi > quantile(outputs_for_pcp(:, kk), 0.95)) = "High";
    group(var_qi < quantile(outputs_for_pcp(:, kk), 0.05)) = "Low";
    % Sample 10,000 rows for plotting
    sampleSize = 1e4;
    idx = randperm(size(outputs_for_pcp, 1), sampleSize);
    inputs_for_pcp_sample = inputs_for_pcp(idx, :);
    outputs_for_pcp_sample = outputs_for_pcp(idx, :);
    groupSample = group(idx);
    T = array2table([inputs_for_pcp_sample outputs_for_pcp_sample(:, kk)], 'VariableNames', [inputs_names, outputs_names(kk)]);
    T.Group = groupSample;
    % Define custom colors: [Mid, Low, High]
    if groupSample(1) == "Low"
        customColors = [
        0.4, 0.5, 1.0;   % Low (light blue)
        0.7 0.7 0.7;   % Mid (light gray)
        1.0 0.4 0.4   % High (light red)
        ];
    elseif groupSample(1) == "High"
        customColors = [
        1.0 0.4 0.4   % High (light red)
        0.7 0.7 0.7;   % Mid (light gray)
        0.4, 0.5, 1.0;   % Low (light blue)
        ];
    else
        customColors = [
        0.7 0.7 0.7;   % Mid (light gray)
        0.4, 0.5, 1.0;   % Low (light blue)
        1.0 0.4 0.4   % High (light red)
        ];
    end
    fig = figure();
    % Plot using parallelplot
    parallelplot(T, ...
        'GroupVariable', 'Group', ...
        'CoordinateVariables', [inputs_names, outputs_names(kk)], ...
        'LineWidth', 0.5, ...
        'Color', customColors);
    title(sprintf('%s; %s', outputs_names(kk), plots_title));
    set(gcf, 'Position',  [100, 100, 800, 800])
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variables_parallel_coordinates_plot.png', kk)))
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variables_parallel_coordinates_plot.fig', kk)))
end    

%% 6. Histograms
N_MC = 10^5;
inputs_for_histograms = uq_getSample(input_distributions, N_MC, 'MC');      % generate N_MC Monte Carlo points in the uncertain variables' space
outputs_for_histograms = uq_evalModel(surrogates, inputs_for_histograms);   % evaluate the surrogates to get QIs data for the histograms
mean_outputs_for_histograms = mean(outputs_for_histograms, 1);              % mean of each QI: to be added to the histogram legend
median_outputs_for_histograms = median(outputs_for_histograms, 1);          % median of each QI: to be added to the histogram legend
std_outputs_for_histograms = std(outputs_for_histograms, 1);                % sigma of each QI: to be added to the histogram legend
for ii = 1:N_variables
    % for each uncertain variable, make a histogram showing its probability distribution       
    fig = figure();
    h = histogram(inputs_for_histograms(:, ii));
    hold on;
    % Plot mean line
    xline(input_distributions.Marginals(ii).Moments(1), 'r--', 'LineWidth', 2, 'Label', 'Mean');
    % Plot standard deviation lines
    xline(input_distributions.Marginals(ii).Moments(1) - input_distributions.Marginals(ii).Moments(2), 'g--', 'LineWidth', 2, 'Label', '-1 Sigma');
    xline(input_distributions.Marginals(ii).Moments(1) + input_distributions.Marginals(ii).Moments(2), 'g--', 'LineWidth', 2, 'Label', '+1 Sigma');
    title('Histogram for one of the uncertain variables')
    xlabel(inputs_names(ii)) 
    legend('Histogram', sprintf('Mean:%.2e', input_distributions.Marginals(ii).Moments(1)), sprintf('-1 Sigma:%.2e', input_distributions.Marginals(ii).Moments(1)-input_distributions.Marginals(ii).Moments(2)), sprintf('+1 Sigma:%.2e', input_distributions.Marginals(ii).Moments(1)+input_distributions.Marginals(ii).Moments(2)));
    % legend(sprintf('mean: %.2e\nsigma: %.2e', input_distributions.Marginals(ii).Moments(1), input_distributions.Marginals(ii).Moments(2)))
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('uncertain_variable_%u_histogram.png', ii)))
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('uncertain_variable_%u_histogram.fig', ii)))
end    
for kk = 1:N_outputs
    % for each QI, make a histogram given all the uncertain variables 
    fig = figure();
    h = histogram(outputs_for_histograms(:, kk));
    hold on;
    % Kernel density estimation
    [f_tmp, xi_tmp] = ksdensity(outputs_for_histograms(:, kk));
    % Find the local maxima (modes)
    % [~, locs_tmp] = findpeaks(f_tmp);
    % Extract the modes
    % modes_tmp = xi_tmp(locs_tmp);
    [~, idx_tmp] = max(f_tmp);       % Index of the maximum density
    mode_estimate = xi_tmp(idx_tmp); % Corresponding value of the mode
    % Plot mean line
    xline(mean_outputs_for_histograms(kk), 'r--', 'LineWidth', 2, 'Label', 'Mean');
    % Plot standard deviation lines
    xline(mean_outputs_for_histograms(kk) - std_outputs_for_histograms(kk), '--', 'Color', [1 0.5 0], 'LineWidth', 2, 'Label', '-1 Sigma');
    xline(mean_outputs_for_histograms(kk) + std_outputs_for_histograms(kk), '--', 'Color', [1 0.5 0], 'LineWidth', 2, 'Label', '+1 Sigma');
    % Plot median line
    xline(median_outputs_for_histograms(kk), 'g--', 'LineWidth', 2, 'Label', 'Median');
    % plot(modes_tmp, f_tmp(locs_tmp), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    xline(mode_estimate, 'm--', 'LineWidth', 2, 'Label', 'Mode');  % Plot the main mode as a vertical line
    title(sprintf('Histogram for QI; %s', plots_title)); 
    xlabel(outputs_names(kk)) 
    % formatted_modes = compose('%.2e', modes_tmp);
    % legend('Histogram', sprintf('Mean:%.2e', mean_outputs_for_histograms(kk)), sprintf('-1 Sigma:%.2e', mean_outputs_for_histograms(kk)-std_outputs_for_histograms(kk)), sprintf('+1 Sigma:%.2e', mean_outputs_for_histograms(kk)+std_outputs_for_histograms(kk)), sprintf('Median:%.2e', median_outputs_for_histograms(kk)), "Modes: " + join(formatted_modes, ", "), 'Location', 'best');
    legend('Histogram', sprintf('Mean:%.2e', mean_outputs_for_histograms(kk)), sprintf('-1 Sigma:%.2e', mean_outputs_for_histograms(kk)-std_outputs_for_histograms(kk)), sprintf('+1 Sigma:%.2e', mean_outputs_for_histograms(kk)+std_outputs_for_histograms(kk)), sprintf('Median:%.2e', median_outputs_for_histograms(kk)), sprintf('Mode:%.2e', mode_estimate), 'Location', 'best');
    set(gcf, 'Position',  [100, 100, 800, 800])
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_histogram.png', kk)))
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_histogram.fig', kk)))
end    

%% 7. Cumulative distribution functions (CDFs)
% for each uncertain variable, use the data from the histograms and make a plot showing its CDF
for ii = 1:N_variables
    [ecdf_values, ecdf_locations] = ecdf(inputs_for_histograms(:, ii));
    fig = figure();
    plot(ecdf_locations, ecdf_values, 'LineWidth', 1.5);
    xlabel(inputs_names(ii)) 
    ylabel('Empirical Cumulative Distribution Function (CDF)');
    title('CDF for one of the uncertain variables')
    grid on;
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('uncertain_variable_%u_cdf.png', ii)))
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('uncertain_variable_%u_cdf.fig', ii)))
end    
% for each QI, use the data from the histograms and make a plot of its CDF given all the uncertain variables
for kk = 1:N_outputs
    [ecdf_values, ecdf_locations] = ecdf(outputs_for_histograms(:, kk));
    fig = figure();
    plot(ecdf_locations, ecdf_values, 'LineWidth', 1.5);
    xlabel(outputs_names(kk));
    ylabel('Empirical Cumulative Distribution Function (CDF)');
    title(sprintf('CDF for QI; %s', plots_title));
    grid on;
    set(gcf, 'Position',  [100, 100, 800, 800])
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_cdf.png', kk)))
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_cdf.fig', kk)))
end 

%% 8. Pairwise correlation plots for the QIs
% use the data from the histograms to make pairwise correlation plots for the QIs
corrMatrix = corr(outputs_for_histograms); % Compute correlation matrix
corrMatrix_spearman = corr(outputs_for_histograms, 'Type', 'Spearman'); % Compute Spearman correlation matrix
if N_outputs >= 2
    % Heatmap (pairwise correlations for the QIs)
    fig = figure();
    heatmap(corrMatrix, 'Colormap', parula, 'ColorLimits', [-1, 1]);
    title('Correlation Matrix Heatmap');
    xlabel('QIs');
    ylabel('QIs');
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', 'qi_heatmap_correlation_plot.fig'))
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', 'qi_heatmap_correlation_plot.png'))

    % Heatmap (Spearman pairwise correlations for the QIs)
    fig = figure();
    heatmap(corrMatrix_spearman, 'Colormap', parula, 'ColorLimits', [-1, 1]);
    title('Spearman Correlation Matrix Heatmap');
    xlabel('QIs');
    ylabel('QIs');
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', 'qi_heatmap_correlation_plot_spearman.fig'))
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', 'qi_heatmap_correlation_plot_spearman.png'))
    
    %pairwise correlation plots for the QIs
    pairwise_combinations = nchoosek(1:N_outputs, 2); 
    for ii = 1:size(pairwise_combinations, 1)
        fig = figure();
        scatter(outputs_for_histograms(:, pairwise_combinations(ii, 1)), outputs_for_histograms(:, pairwise_combinations(ii, 2)), 'filled', DisplayName='QIs');
        hold on;
        p = polyfit(outputs_for_histograms(:, pairwise_combinations(ii, 1)), outputs_for_histograms(:, pairwise_combinations(ii, 2)), 1); % Fit a linear regression line
        y_fit = polyval(p, outputs_for_histograms(:, pairwise_combinations(ii, 1)));
        plot(outputs_for_histograms(:, pairwise_combinations(ii, 1)), y_fit, 'r-', 'LineWidth', 2, DisplayName=sprintf('correlation: %.2f', corrMatrix(pairwise_combinations(ii, 1), pairwise_combinations(ii, 2))));
        xlabel(outputs_names(pairwise_combinations(ii, 1)));
        ylabel(outputs_names(pairwise_combinations(ii, 2)));
        legend(Location='best')
        title('Correlation Plot with Regression Line');
        grid on;
        hold off;
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%d_vs_qi_%d_correlation_plot.fig', pairwise_combinations(ii, 1), pairwise_combinations(ii, 2))))
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%d_vs_qi_%d_correlation_plot.png', pairwise_combinations(ii, 1), pairwise_combinations(ii, 2))))
    end    
end

%% 9. Global sensitivity analysis (Sobol indices)
% prepare a UQLab object for sensitivity analysis
SobolSensOpts.Type = 'Sensitivity';
SobolSensOpts.Method = 'Sobol';
SobolSensOpts.Input = input_distributions;  % probability distributions of the uncertain variables
SobolSensOpts.Model = surrogates;           % UQLab object; contains one independent surrogate for each QI

if strcmp(surrogates.Options.MetaType, 'PCE') % Sobol indices for PCE surrogates are available analytically
    SobolAnalysis = uq_createAnalysis(SobolSensOpts);
    %plots - first-order Sobol indices for each QI 
    for kk = 1:N_outputs
        fig = figure();
        data = SobolAnalysis.Results.FirstOrder(:, kk); % extract the first-order Sobol index for each the uncertain variable
        bar(data)
        set(gca, 'XTick', 1:length(inputs_names), 'XTickLabel', inputs_names); % x-axis: uncertain variables
        title(sprintf('%s; %s', outputs_names(kk), plots_title));              % y-axis: first-order sobol index 
        ylabel('First-order Sobol index')   
        grid on;
        set(gcf, 'Position',  [100, 100, 800, 800])
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_senstivity_analysis_first_order_Sobol_index.png', kk)))
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_senstivity_analysis_first_order_Sobol_index.fig', kk)))
    end 
    % plots - total sobol indices for each QI
    for kk = 1:N_outputs
        fig = figure();
        data = SobolAnalysis.Results.Total(:, kk);     % extract the total Sobol index for each the uncertain variable
        bar(data)
        set(gca, 'XTick', 1:length(inputs_names), 'XTickLabel', inputs_names); % x-axis: uncertain variables
        title(sprintf('%s; %s', outputs_names(kk), plots_title));              % y-axis: total sobol index
        ylabel('Total Sobol index')   
        grid on;
        set(gcf, 'Position',  [100, 100, 800, 800])
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_senstivity_analysis_total_Sobol_index.png', kk)))
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_senstivity_analysis_total_Sobol_index.fig', kk)))
    end 
    else    % Sobol indices for Kriging surrogates need to be estimated using large MC samples
        SobolSensOpts.SaveEvaluations = false;
        SobolSensOpts.Sobol.SampleSize = 200000;              % large MC sample to estimate the Sobol indices
        SobolAnalysis = uq_createAnalysis(SobolSensOpts);
        %plots - first-order Sobol indices for each QI
        for kk = 1:N_outputs
            fig = figure();
            data = SobolAnalysis.Results.FirstOrder(:, kk);  % extract the first-order Sobol index for each the uncertain variable
            bar(data)
            set(gca, 'XTick', 1:length(inputs_names), 'XTickLabel', inputs_names); % x-axis: uncertain variables
            title(sprintf('%s; %s', outputs_names(kk), plots_title));              % y-axis: first-order sobol index 
            ylabel('First-order Sobol index')  % 
            grid on;
            set(gcf, 'Position',  [100, 100, 800, 800])
            saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_senstivity_analysis_first_order_Sobol_index.png', kk)))
            saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_senstivity_analysis_first_order_Sobol_index.fig', kk)))
        end 
        % plots - total sobol indices for each QI
        for kk = 1:N_outputs
            fig = figure();
            data = SobolAnalysis.Results.Total(:, kk);   % extract the total Sobol index for each the uncertain variable
            bar(data)
            set(gca, 'XTick', 1:length(inputs_names), 'XTickLabel', inputs_names);  % x-axis: uncertain variables
            title(sprintf('%s; %s', outputs_names(kk), plots_title));               % y-axis: total sobol index
            ylabel('Total Sobol index')  % 
            grid on;
            set(gcf, 'Position',  [100, 100, 800, 800])
            saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_senstivity_analysis_total_Sobol_index.png', kk)))
            saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_senstivity_analysis_total_Sobol_index.fig', kk)))
        end 
end    

%% 10. Partial dependence function (PDP) and Individual Conditional Expectation (ICE) lines 
% For each QI: 1D parameter sweep w.r.t. each uncertain input variable (let's call this input the active variable)
%   - for each parameter sweep, the rest of the input variables (inactive) are sampled at random
%   - one parameter sweep (line) is generated for each random sample (called Individual Conditional Expectation (ICE) line)
%   - finally, the Partial dependence function (PDP) is the average over all these ICE lines
if strcmp(input_distributions.Marginals(1).Type, 'Uniform') % this code works only for uniform distributions 
    N_ICE = 100;                                            % number of ICE lines to be plotted for each uncertain variable
    N_eval_ICE = 100;                                        % number of locations at which each variable is discretised
    eval_locations_ICE = zeros(N_eval_ICE, N_variables);    % initialise the discretisation matrix for plots 
    lower_bounds = zeros(N_variables, 1);                   % initialise the lower bounds for discretisation
    upper_bounds = zeros(N_variables, 1);                   % initialise the upper bounds for discretisation
    for ii = 1:N_variables      
        lower_bounds(ii) = input_distributions.Marginals(ii).Parameters(1);
        upper_bounds(ii) = input_distributions.Marginals(ii).Parameters(2);
        % discretise the uncertain variable in preparation for the plots
        eval_locations_ICE(:, ii) = linspace(lower_bounds(ii), upper_bounds(ii), N_eval_ICE)';
    end
    for ii = 1:N_variables
        % 1D parameter sweep w.r.t. each uncertain input variable (let's call this input the active variable)
        %   - for each parameter sweep, the rest of the input variables (inactive) are sampled at random N_ICE times
        for jj = 1:N_ICE
            inputs_for_ICE{jj} = uq_getSample(input_distributions, 1, 'MC');
            inputs_for_ICE{jj} = repmat(inputs_for_ICE{jj}, N_eval_ICE, 1);
            inputs_for_ICE{jj}(:, ii) = eval_locations_ICE(:, ii);
            outputs_for_ICE{jj} = uq_evalModel(surrogates, inputs_for_ICE{jj});  
        end
        for kk = 1:N_outputs
            mean_outputs_for_ICE = zeros(N_eval_ICE, N_ICE);
            % one parameter sweep (line) is generated for each random sample (called Individual Conditional Expectation (ICE) line)
            fig = figure();
            for jj = 1:N_ICE
                if jj ~= N_ICE
                    mean_outputs_for_ICE(:, jj) = outputs_for_ICE{jj}(:, kk);
                    plot(eval_locations_ICE(:, ii), outputs_for_ICE{jj}(:, kk), 'b-','LineWidth',0.1);
                    hold on
                else
                  mean_outputs_for_ICE(:, jj) = outputs_for_ICE{jj}(:, kk);
                  plot(eval_locations_ICE(:, ii), outputs_for_ICE{jj}(:, kk), 'b-','LineWidth',0.1, DisplayName='Samples (ICE)');
                  hold on
                end
            end
            % Partial dependence function (PDP): average over all the ICE lines
            mean_outputs_for_ICE = mean(mean_outputs_for_ICE, 2); 
            plot(eval_locations_ICE(:, ii), mean_outputs_for_ICE, 'r-','LineWidth',1.15, DisplayName='Mean (PDP)');
            % Get all line objects from the current axes
            lines = findobj(gca, 'Type', 'line');
            % Filter lines with non-empty DisplayName
            lines_with_names = lines(~cellfun(@isempty, get(lines, 'DisplayName')));
            title(plots_title)         % description of the surrogate
            legend(lines_with_names, Location='best')
            xlabel(inputs_names(ii))   % name of the uncertain variable
            ylabel(outputs_names(kk))  % name of the QI
            saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variable_%u_1D_plot_ICE_PDP.png', kk, ii)))
            saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variable_%u_1D_plot_ICE_PDP.fig', kk, ii)))
        end
    end       
end    

%% 11. Raw correlation data
% use the raw data to make pairwise correlation plots for the QIs
corrMatrix_raw = corr(surrogates.ExpDesign.Y); % Compute correlation matrix
corrMatrix_spearman_raw = corr(surrogates.ExpDesign.Y, 'Type', 'Spearman'); % Compute Spearman correlation matrix
if N_outputs >= 2
    % Heatmap (pairwise correlations for the QIs)
    fig = figure();
    heatmap(corrMatrix_raw, 'Colormap', parula, 'ColorLimits', [-1, 1]);
    title('Correlation Matrix Heatmap (raw data)');
    xlabel('QIs');
    ylabel('QIs');
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', 'qi_heatmap_correlation_plot_raw_data.fig'))
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', 'qi_heatmap_correlation_plot_raw_data.png'))

    % Heatmap (Spearman pairwise correlations for the QIs)
    fig = figure();
    heatmap(corrMatrix_spearman_raw, 'Colormap', parula, 'ColorLimits', [-1, 1]);
    title('Spearman Correlation Matrix Heatmap (raw data)');
    xlabel('QIs');
    ylabel('QIs');
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', 'qi_heatmap_correlation_plot_spearman_raw_data.fig'))
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', 'qi_heatmap_correlation_plot_spearman_raw_data.png'))
    
    %pairwise correlation plots for the QIs
    pairwise_combinations = nchoosek(1:N_outputs, 2); 
    for ii = 1:size(pairwise_combinations, 1)
        fig = figure();
        scatter(surrogates.ExpDesign.Y(:, pairwise_combinations(ii, 1)), surrogates.ExpDesign.Y(:, pairwise_combinations(ii, 2)), 'filled', DisplayName='QIs');
        hold on;
        p = polyfit(surrogates.ExpDesign.Y(:, pairwise_combinations(ii, 1)), surrogates.ExpDesign.Y(:, pairwise_combinations(ii, 2)), 1); % Fit a linear regression line
        y_fit = polyval(p, surrogates.ExpDesign.Y(:, pairwise_combinations(ii, 1)));
        plot(surrogates.ExpDesign.Y(:, pairwise_combinations(ii, 1)), y_fit, 'r-', 'LineWidth', 2, DisplayName=sprintf('correlation: %.2f', corrMatrix_raw(pairwise_combinations(ii, 1), pairwise_combinations(ii, 2))));
        xlabel(outputs_names(pairwise_combinations(ii, 1)));
        ylabel(outputs_names(pairwise_combinations(ii, 2)));
        legend(Location='best')
        title('Correlation Plot with Regression Line (raw data)');
        grid on;
        hold off;
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%d_vs_qi_%d_correlation_plot_raw_data.fig', pairwise_combinations(ii, 1), pairwise_combinations(ii, 2))))
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%d_vs_qi_%d_correlation_plot_raw_data.png', pairwise_combinations(ii, 1), pairwise_combinations(ii, 2))))
    end    
end

close all;

%% 12. Write a readme file
fileID = fopen(fullfile(plotsfolderName, 'plots_uq', 'readme.txt'), 'w');
fprintf(fileID, 'Plots generated for each quantity of interest (QI) as a function of the uncertain variables.\n\n');
fprintf(fileID, 'Legend:\n');
for kk = 1:N_outputs
    fprintf(fileID, 'QI %d: %s\n', kk, outputs_names(kk));
end   
for ii = 1:N_variables
    fprintf(fileID, 'Uncertain variable %d: %s\n', ii, inputs_names(ii));
end    
fprintf(fileID, 'Methodology: %s\n', plots_title);  
fclose(fileID);
disp('Readme file for the uncertain variable exploration plots has been created successfully.');