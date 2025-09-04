function surrogates = surrogates_uq(options_uq, N_train_increment, N_train_max, flag_parfor, seed, plotsfolderName, flag_test_for_mean_and_sigma)
%% Title section - Surrogates for UQ or optimisation (design space exploration) for a physical model 
%{
--------------------------------------------------------
Comments:
* 'surrogates_uq' builds surrogates (using UQLab) for functions derived from a physical model 
* The functions map from inputs - uncertain variables (UQ) or design variables (optimisation) - to key quantities of interest - QIs (outputs)
* The training set is iteratively updated until the surrogate validation error is low enough
* Options for the UQLab surrogates: Kriging or Polynomial Chaos Expansion (PCE)
--------------------------------------------------------
Input:
* options_uq               : UQLab object; key properties required to build the surrogate model
* N_train_increment        : increment for the training set size until convergence is reached
* N_train_max              : training budget (i.e., maximum number of training points allowed)
* flag_parfor              : can we run the physical model in parallel to build the training set? (True/False)
* seed                     : seed for reproducibility due to randomness in sampling the training set
* plotsfolderName          : the name of subfolder where the convergence plots will be added
* flag_test_for_mean_and_sigma : (UQ applications only) run a test (True - Yes/False - No) to check if surrogates are actually better than classical MC for mean and sigma estimation 
--------------------------------------------------------
Output:
* surrogates               : UQLab object; contains one independent surrogate for each QI
--------------------------------------------------------
%}

%% 1. Set seed for reproducibility
rng(seed, 'twister')

%% 2. Extract properties of the physical system and surrogate models
% P = options_uq.FullModel.Parameters;           % deterministic parameters of the physical model
model_uq = options_uq.FullModel;                 % the physical model as a UQLab object
input_distributions = options_uq.Input;          % UQ: probability distributions of the uncertain variables; Optimisation: bounds for the design variables
N_train = options_uq.ExpDesign.NSamples;         % initial number of training points (to be increased if needed) 

%% 3. Generate training data and train the surrogates
N_variables = length(input_distributions.Marginals);        % the number of uncertain variables (UQ) or design variables (optimisation)
X = uq_getSample(input_distributions, N_train, 'LHS');      % collect training inputs via Latin Hypercube sampling

if strcmp(input_distributions.Marginals(1).Type, 'Uniform') 
    % UQ: if the first uncertain variable is Uniformly distributed over an interval, we assume all uncertain variables are Uniform
    % Optimisation: the design variables are always Uniformly distributed between the lower and upper optimisation bounds
    if N_variables == 1
        % add the corners of the uncertain interval (UQ) or the design space (Optimisation) to the training set
        N_corners = 2;          
        X_corners = [input_distributions.Marginals(1).Parameters(1); input_distributions.Marginals(1).Parameters(2)];
        X = [X_corners; X];                                      % combine the corner points with the LHS inputs and construct the training set
        X_centre = input_distributions.Marginals(1).Moments(1);  % add the centre of the uncertain interval (UQ) or the design space (Optimisation) to the training set
        X = [X_centre; X];                                       % combine the centre with and the corner points and with the LHS inputs and construct the training set
        N_train = N_train+N_corners+1;                           % total number of training points
    elseif N_variables == 2     
        N_corners = 4;
        X_corners = [input_distributions.Marginals(1).Parameters(1), input_distributions.Marginals(2).Parameters(1);
                     input_distributions.Marginals(1).Parameters(1), input_distributions.Marginals(2).Parameters(2);
                     input_distributions.Marginals(1).Parameters(2), input_distributions.Marginals(2).Parameters(1);
                     input_distributions.Marginals(1).Parameters(2), input_distributions.Marginals(2).Parameters(2)];
        X = [X_corners; X];                                      % combine the corner points with the LHS inputs and construct the training set
        X_centre = [input_distributions.Marginals(1).Moments(1), input_distributions.Marginals(2).Moments(1)]; % add the centre of the uncertain interval (UQ) or the design space (Optimisation) to the training set
        X = [X_centre; X];                                       % combine the centre with and the corner points and with the LHS inputs and construct the training set
        N_train = N_train+N_corners+1;                           % total number of training points
    elseif N_variables == 3
        N_corners = 8;          
        X_corners = [input_distributions.Marginals(1).Parameters(1), input_distributions.Marginals(2).Parameters(1), input_distributions.Marginals(3).Parameters(1);
                     input_distributions.Marginals(1).Parameters(1), input_distributions.Marginals(2).Parameters(1), input_distributions.Marginals(3).Parameters(2);
                     input_distributions.Marginals(1).Parameters(1), input_distributions.Marginals(2).Parameters(2), input_distributions.Marginals(3).Parameters(1);
                     input_distributions.Marginals(1).Parameters(1), input_distributions.Marginals(2).Parameters(2), input_distributions.Marginals(3).Parameters(2);
                     input_distributions.Marginals(1).Parameters(2), input_distributions.Marginals(2).Parameters(1), input_distributions.Marginals(3).Parameters(1);
                     input_distributions.Marginals(1).Parameters(2), input_distributions.Marginals(2).Parameters(1), input_distributions.Marginals(3).Parameters(2);
                     input_distributions.Marginals(1).Parameters(2), input_distributions.Marginals(2).Parameters(2), input_distributions.Marginals(3).Parameters(1);
                     input_distributions.Marginals(1).Parameters(2), input_distributions.Marginals(2).Parameters(2), input_distributions.Marginals(3).Parameters(2)];            
        X = [X_corners; X];                                      % combine the corner points with the LHS inputs and construct the training set
        X_centre = [input_distributions.Marginals(1).Moments(1), input_distributions.Marginals(2).Moments(1), input_distributions.Marginals(3).Moments(1)];  % add the centre of the uncertain interval (UQ) or the design space (Optimisation) to the training set
        X = [X_centre; X];                                       % combine the centre with and the corner points and with the LHS inputs and construct the training set
        N_train = N_train+N_corners+1;                           % total number of training points
    %  elseif N_variables >= 4: don't add centre and corners and proceed with a LHS training set
    end 
end

% Extract the number of outputs (QIs) (we assume that the physical model does not crash for the first training point)
Y_tmp = uq_evalModel(model_uq, X(1, :));
nOutputs = size(Y_tmp, 2);

Y = nan(N_train, nOutputs);     % initialise the training outputs   
if flag_parfor
    parfor ii=1:N_train
        try
            Y(ii, :) = uq_evalModel(model_uq, X(ii, :));     % evaluate the physical model on the training inputs
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
else   
    for ii=1:N_train
        try
            Y(ii, :) = uq_evalModel(model_uq, X(ii, :));
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
end   
X = X(~any(isnan(Y), 2), :);                            % remove NaN physical model outputs from the training set
Y = Y(~any(isnan(Y), 2), :);                            % remove NaN physical model outputs from the training set
options_uq.ExpDesign.X = X;                             % 'experimental design' (ExpDesign): another word for 'training set'
options_uq.ExpDesign.Y = Y;
options_uq.ExpDesign.NSamples = size(X, 1);
surrogates = uq_createModel(options_uq);                % train the surrogate

% (only for UQ applications) run a test to check if surrogates are actually better than classical MC for mean and sigma estimation
if flag_test_for_mean_and_sigma                             
    N_MC = 1e4;                                         % maximum budget for this test (assumed large enough for an accurate estimation of mean and sigma)
    X_MC = uq_getSample(input_distributions, N_MC, 'MC');
    Y_MC = nan(N_MC, size(Y, 2));
    if flag_parfor
        parfor kk=1:N_MC
            try
                Y_MC(kk, :) = uq_evalModel(model_uq, X_MC(kk, :));
            catch ME
                fprintf('Error in sample %d: %s\n', kk, ME.message);
            end
        end
    else
        for kk=1:N_MC
            try
                Y_MC(kk, :) = uq_evalModel(model_uq, X_MC(kk, :));
            catch ME
                fprintf('Error in sample %d: %s\n', kk, ME.message);
            end
        end
    end    
    X_MC = X_MC(~any(isnan(Y_MC), 2), :);                   % remove NaN physical model outputs from the MC set
    Y_MC = Y_MC(~any(isnan(Y_MC), 2), :);                   % remove NaN physical model outputs from the MC set
    mean_exact = mean(Y_MC, 1);                             % true mean
    std_exact = std(Y_MC, 1);                               % true sigma
    mean_MC = mean(Y_MC(1:size(Y, 1), :), 1);               % mean estimated with classical MC of size equal to the number of training points
    std_MC = std(Y_MC(1:size(Y, 1), :), 1);                 % sigma estimated with classical MC of size equal to the number of training points  
    if strcmp(surrogates.Options.MetaType, 'PCE')           % mean and sigma for PCE surrogates are analytically available
        for ii = 1:size(Y, 2)      
            mean_surrogate(ii) = surrogates.PCE(ii).Moments.Mean;
            std_surrogate(ii) = sqrt(surrogates.PCE(ii).Moments.Var);
        end
    else                                                    % mean and sigma for Kriging surrogates need to be estimated using large MC samples
        N_MC_test = 10^5;
        inputs_for_mean_sigma_test = uq_getSample(input_distributions, N_MC_test, 'MC');      % generate N_MC Monte Carlo points in the uncertain variables' space
        outputs_for_mean_sigma_test = uq_evalModel(surrogates, inputs_for_mean_sigma_test);   % evaluate the surrogates to get QIs data
        mean_surrogate = mean(outputs_for_mean_sigma_test, 1);
        std_surrogate = std(outputs_for_mean_sigma_test, 1);
    end  
end

%% 4. Enrich the training set until the budget is exhausted or the leave-one-out (LOO) validation error is small enough   
validation_errors = zeros(1, size(Y, 2));             
N_train_iterations = size(surrogates.ExpDesign.X, 1);       % collect the number of training points
if strcmp(surrogates.Options.MetaType, 'PCE')
    for ii = 1:size(Y, 2)
        validation_errors(1, ii) = surrogates.Error(ii).ModifiedLOO;    % collect the validation error for each QI
    end 
    while any([surrogates.Error.ModifiedLOO] > 1e-12) & size(surrogates.ExpDesign.X, 1) < N_train_max      % leave-one-out (LOO) validation error (with special correction factor for PCE; see formula in UQLab docs)   
        if strcmp(input_distributions.Marginals(1).Type, 'Uniform') & N_variables<=3 
            Xnew = uq_LHSify(X(2^N_variables+2:end, :), N_train_increment, input_distributions);           % new training inputs that preserve the Latin Hypercube structure (ignore the 2^N_variables corners and the centre)    
        else
            Xnew = uq_LHSify(X, N_train_increment, input_distributions);   % new training inputs that preserve the Latin Hypercube structure
        end
        N_model_outputs = size(Y, 2);
        Ynew = nan(N_train_increment, N_model_outputs);     % initialise the new training outputs
        if flag_parfor
            parfor ii=1:N_train_increment
                try
                    Ynew(ii, :) = uq_evalModel(model_uq, Xnew(ii, :));     % evaluate the physical model on the new training inputs
                catch ME
                    fprintf('Error in sample %d: %s\n', ii, ME.message);
                end
            end  
        else
            for ii=1:N_train_increment
                try
                    Ynew(ii, :) = uq_evalModel(model_uq, Xnew(ii, :));     % evaluate the physical model on the new training inputs
                catch ME
                    fprintf('Error in sample %d: %s\n', ii, ME.message);
                end
            end  
        end   
        Xnew = Xnew(~any(isnan(Ynew), 2), :);
        Ynew = Ynew(~any(isnan(Ynew), 2), :);                          % remove NaN physical model outputs from the new training set
        % Use both old and new training samples and retrain the surrogate
        X = [X; Xnew];                                
        Y = [Y; Ynew];                                  
        options_uq.ExpDesign.X = X;                     
        options_uq.ExpDesign.Y = Y;                     
        surrogates = uq_createModel(options_uq);
        validation_errors_new = zeros(1, size(Y, 2));  
        for ii = 1:size(Y, 2)
            validation_errors_new(1, ii) = surrogates.Error(ii).ModifiedLOO;    % collect the validation error for each QI
        end 
        validation_errors = [validation_errors; validation_errors_new];         % collect the validation errors for all iterations
        N_train_iterations_new = size(surrogates.ExpDesign.X, 1);               % collect the number of training points
        N_train_iterations = [N_train_iterations; N_train_iterations_new];      % collect the number of training points for all iterations
        if flag_test_for_mean_and_sigma      
            for ii = 1:size(Y, 2)     
                mean_surrogate_new(ii) = surrogates.PCE(ii).Moments.Mean;           % mean and sigma estimation for each QI 
                std_surrogate_new(ii) = sqrt(surrogates.PCE(ii).Moments.Var);       % mean and sigma estimation for each QI 
            end
            mean_surrogate = [mean_surrogate; mean_surrogate_new];                  % collect the mean and sigma estimations with surrogates for all iterations
            std_surrogate = [std_surrogate; std_surrogate_new];                     % collect the mean and sigma estimations with surrogates for all iterations
            mean_MC_new = mean(Y_MC(1:size(Y, 1), :), 1);                           % mean estimated with classical MC of size equal to the number of training points
            std_MC_new = std(Y_MC(1:size(Y, 1), :), 1);                             % sigma estimated with classical MC of size equal to the number of training points
            mean_MC = [mean_MC; mean_MC_new];                                       % collect the mean and sigma estimations with classical MC for all iterations
            std_MC = [std_MC; std_MC_new];                                          % collect the mean and sigma estimations with classical MC for all iterations
        end
    end
else  % Kriging      
    for ii = 1:size(Y, 2)
        validation_errors(1, ii) = surrogates.Error(ii).LOO;    % collect the validation error for each QI
    end 
    while any([surrogates.Error.LOO] > 1e-12)  & size(surrogates.ExpDesign.X, 1) < N_train_max     % leave-one-out (LOO) validation error (see formula in UQLab docs)   
        if strcmp(input_distributions.Marginals(1).Type, 'Uniform') & N_variables<=3    
            Xnew = uq_LHSify(X(2^N_variables+2:end, :), N_train_increment, input_distributions);   % new training inputs that preserve the Latin Hypercube structure (ignore the 2^N_variables corners and the centre)    
        else
            Xnew = uq_LHSify(X, N_train_increment, input_distributions);   % new training inputs that preserve the Latin Hypercube structure
        end
        N_model_outputs = size(Y, 2);
        Ynew = nan(N_train_increment, N_model_outputs);     % initialise the new training outputs
        if flag_parfor
            parfor ii=1:N_train_increment
                try
                    Ynew(ii, :) = uq_evalModel(model_uq, Xnew(ii, :));     % evaluate the physical model on the new training inputs
                catch ME
                    fprintf('Error in sample %d: %s\n', ii, ME.message);
                end
            end  
        else
            for ii=1:N_train_increment
               try
                    Ynew(ii, :) = uq_evalModel(model_uq, Xnew(ii, :));     % evaluate the physical model on the new training inputs
                catch ME
                    fprintf('Error in sample %d: %s\n', ii, ME.message);
               end
            end  
        end  
        Xnew = Xnew(~any(isnan(Ynew), 2), :);
        Ynew = Ynew(~any(isnan(Ynew), 2), :);                          % remove NaN physical model outputs from the training set
        % Use both old and new training samples and retrain the surrogate
        X = [X; Xnew];                                
        Y = [Y; Ynew];                                  
        options_uq.ExpDesign.X = X;                     
        options_uq.ExpDesign.Y = Y;                     
        surrogates = uq_createModel(options_uq);
        validation_errors_new = zeros(1, size(Y, 2));  
        for ii = 1:size(Y, 2)
            validation_errors_new(1, ii) = surrogates.Error(ii).LOO;        % collect the validation error for each QI
        end 
        validation_errors = [validation_errors; validation_errors_new];     % collect the validation errors for all iterations
        N_train_iterations_new = size(surrogates.ExpDesign.X, 1);           % collect the number of training points
        N_train_iterations = [N_train_iterations; N_train_iterations_new];  % collect the number of training points for all iterations
        if flag_test_for_mean_and_sigma      
            outputs_for_mean_sigma_test = uq_evalModel(surrogates, inputs_for_mean_sigma_test);
            mean_surrogate_new = mean(outputs_for_mean_sigma_test, 1);
            std_surrogate_new = std(outputs_for_mean_sigma_test, 1);
            mean_surrogate = [mean_surrogate; mean_surrogate_new];
            std_surrogate = [std_surrogate; std_surrogate_new];
            mean_MC_new = mean(Y_MC(1:size(Y, 1), :), 1);                           % mean estimated with classical MC of size equal to the number of training points
            std_MC_new = std(Y_MC(1:size(Y, 1), :), 1);                             % sigma estimated with classical MC of size equal to the number of training points
            mean_MC = [mean_MC; mean_MC_new];                                       % collect the mean and sigma estimations with classical MC for all iterations
            std_MC = [std_MC; std_MC_new];                                          % collect the mean and sigma estimations with classical MC for all iterations
        end
    end
end

%% 5. Plot surrogate validation error convergence plot
for kk = 1:size(Y, 2)
    fig = figure();
    semilogy(N_train_iterations, validation_errors(:, kk), '-o', 'LineWidth', 2);
    xlabel('Number of training points');
    ylabel(sprintf('%s surrogate validation error', surrogates.Options.MetaType));
    title(sprintf('Convergence Plot for QI %d', kk));
    grid on;
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_surrogate_error_convergence_plot.png', kk)))
    saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_surrogate_error_convergence_plot.fig', kk)))
end

%% 6. Compare mean and sigma estimation with surrogates vs classic MC and compare UQ histograms of surrogate vs true model
if flag_test_for_mean_and_sigma      
    for kk = 1:size(Y, 2)
        % Define colors and markers '+','o','*','.'
        colors = {'r', 'g'};        
        labels = {'Mean MC', 'Sigma MC', sprintf('Mean %s', surrogates.Options.MetaType), sprintf('Sigma %s', surrogates.Options.MetaType)};
        fig = figure();
        semilogy(N_train_iterations, abs(mean_MC(:, kk)./mean_exact(kk)-1), [colors{1} '-+'], 'LineWidth', 2);
        hold on
        semilogy(N_train_iterations, abs(std_MC(:, kk)./std_exact(kk)-1), [colors{1} '--o'], 'LineWidth', 2);
        semilogy(N_train_iterations, abs(mean_surrogate(:, kk)./mean_exact(kk)-1), [colors{2} '-*'], 'LineWidth', 2);
        semilogy(N_train_iterations, abs(std_surrogate(:, kk)./std_exact(kk) - 1), [colors{2} '--x'], 'LineWidth', 2);
        xlabel('Number of training points');
        ylabel('Estimation error relative to the true mean and sigma');
        title(sprintf('Convergence Plot for QI %d', kk));
        legend(labels, 'Location', 'best');
        grid on;
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_mean_sigma_convergence_plot.png', kk)))
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_mean_sigma_convergence_plot.fig', kk)))
    end
    % for each QI, compare the histogram resulting from the surrogate approximation with the histogram resulting from a large number of MC evals with the physical model 
    N_MC_histogram_test = 10^6;
    inputs_for_histogram_test = uq_getSample(input_distributions, N_MC_histogram_test, 'MC'); % generate N_MC Monte Carlo points in the uncertain variables' space
    outputs_for_histogram_test = uq_evalModel(surrogates, inputs_for_histogram_test);         % for each QI, histogram resulting from the surrogate approximation
    for kk = 1:size(Y, 2)
        % Plot histograms
        fig = figure();
        histogram(Y_MC(:, kk), 'Normalization', 'pdf', 'FaceAlpha', 0.5, 'EdgeColor', 'none');                       % histogram with the physical model 
        hold on;
        histogram(outputs_for_histogram_test(:, kk), 'Normalization', 'pdf', 'FaceAlpha', 0.5, 'EdgeColor', 'none'); % histogram with the surrogate model 
        hold off;
        % Add labels and legend
        xlabel(sprintf('QI %d', kk));
        ylabel('Probability density function estimate');
        legend('Physical model', sprintf('%s surrogate', surrogates.Options.MetaType));
        title(sprintf('Comparison between physical and surrogate model for QI %d', kk));
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_histogram_physical_model_surrogate_comparison.png', kk)))
        saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_histogram_physical_model_surrogate_comparison.fig', kk)))
    end
end

%% 7. Further validation - 1D slices (surrogate vs true model)
if strcmp(input_distributions.Marginals(1).Type, 'Uniform') % this code works only for uniform distributions 
    N_eval = 8;                                             % How many evaluations of the physical model do you allow? (per uncertain variable (UQ) or design variable (optimisation))
    N_variables = length(input_distributions.Marginals);    % number of uncertain variables (UQ) or design variables (optimisation)
    N_outputs = size(surrogates.ExpDesign.Y, 2);            % number of quantities of interest (QIs)
    eval_locations = zeros(N_eval, N_variables);            % initialise the discretisation matrix for plots 
    lower_bounds = zeros(N_variables, 1);                   % initialise the lower bounds for discretisation
    upper_bounds = zeros(N_variables, 1);                   % initialise the upper bounds for discretisation
    for ii = 1:N_variables
        % extract the whole uncertain interval (UQ) or the whole design variable space (optimisation)
        lower_bounds(ii) = input_distributions.Marginals(ii).Parameters(1);
        upper_bounds(ii) = input_distributions.Marginals(ii).Parameters(2);
        % discretise the uncertain variable (UQ) or design variable (optimisation) in preparation for the contour plots
        eval_locations(:, ii) = linspace(lower_bounds(ii), upper_bounds(ii), N_eval)';
    end
    eval_points = zeros(N_eval, N_variables);   % initialise using the total number of discretisation points
    for jj = 1:N_variables
        eval_points(:, jj) = (upper_bounds(jj)+lower_bounds(jj))/2;     % the uncertain variables (UQ) or design variables (optimisation) are fixed to their mean value
    end
    for ii = 1:N_variables
        eval_points(:, ii) = eval_locations(:, ii);                     % discretisation of the uncertain variable in preparation for the plot
        surrogates_output = uq_evalModel(surrogates, eval_points);      % evaluate the surrogates at the discretisation points (i.e., get all QIs)
        true_model_output = nan(N_eval, N_outputs); 
        if flag_parfor
            parfor kk = 1:N_eval
                try
                    true_model_output(kk, :) = uq_evalModel(model_uq, eval_points(kk, :));
                catch ME
                    fprintf('Error in sample %d: %s\n', kk, ME.message);
                end  
            end
        else
            for kk = 1:N_eval
                try
                    true_model_output(kk, :) = uq_evalModel(model_uq, eval_points(kk, :));
                catch ME
                    fprintf('Error in sample %d: %s\n', kk, ME.message);
                end  
            end
        end
        true_model_output_clean = true_model_output(~any(isnan(true_model_output), 2), :);
        eval_inputs_for_plot = eval_locations(:, ii);
        eval_locations_clean = eval_inputs_for_plot(~any(isnan(true_model_output), 2), :);
        for kk = 1:N_outputs
            % make a plot for each QI as a function of the uncertain variable
            fig = figure();
            plot(eval_locations(:, ii), surrogates_output(:, kk), 'b-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
            hold on
            scatter(eval_locations_clean, true_model_output_clean(:, kk), 100, 'r', 'filled'); % plot true model evals
            title(sprintf('%s surrogate validation (1D slice)', surrogates.Options.MetaType))  % description of the surrogate
            xlabel(sprintf('Uncertain variable %d', ii))      % name of the uncertain variable (UQ) or design variable (optimisation)
            ylabel(sprintf('QI %d', kk))                   % name of the QI
            legend('Surrogate model', 'Raw data');
            saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variable_%u_1D_plot_validation.png', kk, ii)))
            saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variable_%u_1D_plot_validation.fig', kk, ii)))
        end
        eval_points(:, ii) = (upper_bounds(ii)+lower_bounds(ii))/2;   
    end
end    

%% 8. Further validation - 2D slices (surrogate vs true model)
% for each QI, collect data for 2D contour plots for all pairs of uncertain variables (UQ) or design variables (optimisation)
if strcmp(input_distributions.Marginals(1).Type, 'Uniform') % this code works only for uniform distributions 
    N_eval = 100;
    N_variables = length(input_distributions.Marginals);    % number of uncertain variables (UQ) or design variables (optimisation)
    N_outputs = size(surrogates.ExpDesign.Y, 2);            % number of quantities of interest (QIs)
    eval_locations = zeros(N_eval, N_variables);            % initialise the discretisation matrix for plots 
    lower_bounds = zeros(N_variables, 1);                   % initialise the lower bounds for discretisation
    upper_bounds = zeros(N_variables, 1);                   % initialise the upper bounds for discretisation
    for ii = 1:N_variables
        % extract the whole uncertain interval (UQ) or the whole design variable space (optimisation)
        lower_bounds(ii) = input_distributions.Marginals(ii).Parameters(1);
        upper_bounds(ii) = input_distributions.Marginals(ii).Parameters(2);
        % discretise the uncertain variable (UQ) or design variable (optimisation) in preparation for the contour plots
        eval_locations(:, ii) = linspace(lower_bounds(ii), upper_bounds(ii), N_eval)';
    end
    if N_variables >= 2
        pairwise_combinations = nchoosek(1:N_variables, 2); 
        for ii = 1:size(pairwise_combinations, 1)
            [Eval_locations_x, Eval_locations_y] = meshgrid(eval_locations(:, pairwise_combinations(ii, 1)), eval_locations(:, pairwise_combinations(ii, 2)));
            eval_points = zeros(length(Eval_locations_x(:)), N_variables); % initialise using the total number of discretisation points
            for jj = 1:N_variables
                if jj == pairwise_combinations(ii, 1)
                    eval_points(:, jj) = Eval_locations_x(:); % discretisation for the uncertain variable (UQ) or design variable (optimisation) to be ploted on the x-axis
                elseif jj == pairwise_combinations(ii, 2)
                    eval_points(:, jj) = Eval_locations_y(:); % discretisation for the uncertain variable (UQ) or design variable (optimisation) to be ploted on the y-axis
                else
                    eval_points(:, jj) = (upper_bounds(jj)+lower_bounds(jj))/2; % the other uncertain variables (UQ) or design variables (optimisation) are fixed to their mean value
                end
            end
            surrogates_output = uq_evalModel(surrogates, eval_points); % evaluate the surrogates at the discretisation points (i.e., get all QIs)
            N_eval_model = 3;                                          % How many evaluations of the physical model do you allow? (per uncertain variable (UQ) or design variable (optimisation))
            eval_locations_model = zeros(N_eval_model, N_variables);   % initialise the discretisation matrix for plots 
            for kk = 1:N_variables
                % discretise the uncertain variable (UQ) or design variable (optimisation) in preparation for the contour plots
                eval_locations_model(:, kk) = linspace(lower_bounds(kk), upper_bounds(kk), N_eval_model)';
            end
            [Eval_locations_model_x, Eval_locations_model_y] = meshgrid(eval_locations_model(:, pairwise_combinations(ii, 1)), eval_locations_model(:, pairwise_combinations(ii, 2)));
            eval_points_model = zeros(length(Eval_locations_model_x(:)), N_variables); % initialise using the total number of discretisation points
            for jj = 1:N_variables
                if jj == pairwise_combinations(ii, 1)
                    eval_points_model(:, jj) = Eval_locations_model_x(:); % discretisation for the uncertain variable (UQ) or design variable (optimisation) to be ploted on the x-axis
                elseif jj == pairwise_combinations(ii, 2)
                    eval_points_model(:, jj) = Eval_locations_model_y(:); % discretisation for the uncertain variable (UQ) or design variable (optimisation) to be ploted on the y-axis
                else
                    eval_points_model(:, jj) = (upper_bounds(jj)+lower_bounds(jj))/2; % the other uncertain variables (UQ) or design variables (optimisation) are fixed to their mean values
                end
            end
            true_model_output = nan(length(Eval_locations_model_x(:)), N_outputs); 
            if flag_parfor
                parfor kk = 1:length(Eval_locations_model_x(:))
                    try
                        true_model_output(kk, :) = uq_evalModel(model_uq, eval_points_model(kk, :));
                    catch ME
                        fprintf('Error in sample %d: %s\n', kk, ME.message);
                    end  
                end
            else
                for kk = 1:length(Eval_locations_model_x(:))
                    try
                        true_model_output(kk, :) = uq_evalModel(model_uq, eval_points_model(kk, :));
                    catch ME
                        fprintf('Error in sample %d: %s\n', kk, ME.message);
                    end  
                end
            end
            true_model_output_clean = true_model_output(~any(isnan(true_model_output), 2), :);
            eval_locations_clean = eval_points_model(~any(isnan(true_model_output), 2), :);
            for kk = 1:N_outputs
                % for each QI, make a contour plot for each combination of two uncertain variables 
                fig = figure();
                [~, hContour] = contourf(Eval_locations_x, Eval_locations_y, reshape(surrogates_output(:, kk), [N_eval, N_eval]), 40);
                colorbar;
                colormap('parula');  
                hold on
                hScatter = scatter(eval_locations_clean(:, pairwise_combinations(ii, 1)), eval_locations_clean(:, pairwise_combinations(ii, 2)), 100, 'r', 'filled', 'MarkerEdgeColor', 'k');
                scatter_x = eval_locations_clean(:, pairwise_combinations(ii, 1));
                scatter_y = eval_locations_clean(:, pairwise_combinations(ii, 2));
                % Annotate each point with its value using the same format as the colorbar
                for ll = 1:length(scatter_x)
                    text(scatter_x(ll), scatter_y(ll), ...
                        sprintf('%.2e', true_model_output_clean(ll, kk)), ...
                        'FontSize', 9, 'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'bottom', ...
                        'BackgroundColor', 'w', 'EdgeColor', 'k', ...
                        'Margin', 2, 'Interpreter', 'none');
                end
                title(sprintf('%s surrogate validation: QI %d (2D slice)', surrogates.Options.MetaType, kk))      % description of the surrogate
                xlabel(sprintf('Uncertain variable %d', pairwise_combinations(ii, 1))) % name of the uncertain variable (UQ) or design variable (optimisation) to be ploted on the x-axis
                ylabel(sprintf('Uncertain variable %d', pairwise_combinations(ii, 2))) % name of the uncertain variable (UQ) or design variable (optimisation) to be ploted on the y-axis
                legend([hContour, hScatter], {'Contour Levels', 'Raw data'}, 'Location', 'northeast')             
                set(gcf, 'Position',  [100, 100, 800, 800])
                % After plotting everything...

                % Get current axis limits
                xLimits = xlim;
                yLimits = ylim;
                
                % Add margin (e.g., 15% of the range)
                xMargin = 0.15 * diff(xLimits);
                yMargin = 0.15 * diff(yLimits);
                
                % Set new limits with extra white space
                xlim([xLimits(1) - xMargin, xLimits(2) + xMargin]);
                ylim([yLimits(1) - yMargin, yLimits(2) + yMargin]);

                saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variables_%u_and_%u_2D_contour_plot_validation.png', kk, pairwise_combinations(ii, 1), pairwise_combinations(ii, 2))))
                saveas(fig, fullfile(plotsfolderName, 'plots_uq', sprintf('qi_%u_vs_uncertain_variables_%u_and_%u_2D_contour_plot_validation.fig', kk, pairwise_combinations(ii, 1), pairwise_combinations(ii, 2))))
            end
        end    
    end   
end

end




