%% Title section - Block Fuel and Direct Operating Cost: design space exploration and optimisation
%{
--------------------------------------------------------
Comments:
* First goal is to analyse Block Fuel (BF) and Direct Operating Cost (DOC) as a function of design variables (AR, Mach no., ...)
* Surrogate models (Kriging, Polynomial Chaos Expansion) are used for design space exploration, sensitivity analysis, ...
* The surrogates are built using the UQLab package (https://www.uqlab.com/install)
* Without loss of generality, UQLab requires writing each design variable as an uncertain variable, as follows: 
    * each design variable x within the bounds [lb_x, ub_x] is defined in UQLab as an uncertain variable with a Uniform probability distribution over the interval [lb_x, ub_x]
    * when we sample from this Uniform distribution (e.g., using Latin Hypercube method), we obtain a training set that covers the design bounds [lb_x, ub_x], as desired 

* Second goal is to minimise BF and DOC as a function of the design variables
* This multi-objective optimisation problem is deterministic
* The surrogate models built during design exploration are also used for optimisation 
* More specifically, the surrogates replace the physical model inside a multi-objective Genetic Algorithm (GA)

* Third goal is to minimise the Total operating cost as a function of design variables in the presence of uncertainties (i.e., fuel price, oil price)
* This robust optimisation problem is solved efficiently using surrogate models
--------------------------------------------------------
%}

%% 1. Start a UQLab session
uqlab 

%% 2. Straight wing case (design variables: AR, Mach no.)

% This section generates many plots, which are saved rather than displayed on the screen
set(0, 'DefaultFigureVisible', 'off'); 

% Description of the uncertain variables for UQLab
InputOpts_straight_wing.Marginals(1).Type = 'Uniform';
InputOpts_straight_wing.Marginals(1).Parameters = [11, 23]; % (Aspect Ratio) lower and upper design optimisation bound
InputOpts_straight_wing.Marginals(2).Type = 'Uniform';
InputOpts_straight_wing.Marginals(2).Parameters = [0.45, 0.69]; % (Mach no.) lower and upper design optimisation bound - straight wing
% The uncertain variables are inputs for physical maps that output QIs (i.e., Block Fuel, DOC, ...)
myInput_straight_wing = uq_createInput(InputOpts_straight_wing);

plotsfolderName = 'straight_wing_uq'; 
mkdir(plotsfolderName)

% Description of the physical model for UQLab
ModelOpts_straight_wing.mFile = 'physical_model_straight_wing';
ModelOpts_straight_wing.isVectorized = false;
myModel_straight_wing = uq_createModel(ModelOpts_straight_wing);

N_train = 5;    % initial training set size (the set will be updated until the training budget is exhausted or until the surrogate validation error is low enough)
MetaOpts_straight_wing.Type = 'Metamodel';                 % 'metamodel': another word for 'surrogate'    
MetaOpts_straight_wing.MetaType = 'PCE';                   % Polynomial Chaos Expansion surrogate model
MetaOpts_straight_wing.Input = myInput_straight_wing;      % design variables
MetaOpts_straight_wing.FullModel = myModel_straight_wing;  % the physical model as a UQLab object
MetaOpts_straight_wing.ExpDesign.NSamples = N_train;       % 'experimental design' (ExpDesign): another word for 'training set'
if strcmp(MetaOpts_straight_wing.MetaType, 'Kriging')
    MetaOpts_straight_wing.ExpDesign.Sampling = 'User';
end

flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
N_train_increment = 8;          % we will increment the training set size until we reach convergence
N_train_max = 800;              % training budget (i.e., maximum number of training points allowed)
flag_test_for_mean_and_sigma = false;

% Plots generator for parameter sweeps for the design variables
inputs_name = ["Aspect Ratio (AR)", "Mach number"];  % list of the names of the design variables
outputs_name = ["Block fuel", "Direct operating cost", "Wingspan", "CD0", "CD cruise", "MTOM"];   % list of the names of the QIs
N_outputs = length(outputs_name);             % number of quantities of interest (QIs)
descriptive_title_for_plots = sprintf('%s surrogate', MetaOpts_straight_wing.MetaType);
N_eval = 100;                                        % number of discretisation points for each design variable (for plots)
plotsfolderName = 'straight_wing_uq'; 
mkdir(plotsfolderName, 'plots_uq');
surrogates_straight_wing =  surrogates_uq(MetaOpts_straight_wing, N_outputs, N_train_increment, N_train_max, flag_parfor, seed, plotsfolderName, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
elementToSave = surrogates_straight_wing;
save(fullfile(plotsfolderName, 'surrogates_straight_wing.mat'), 'elementToSave'); % save the surrogate
% visualise the outputs as a function of the design variables (i.e., design exploration)
uncertain_variables_exploration(elementToSave, inputs_name, outputs_name, descriptive_title_for_plots, N_eval, seed, plotsfolderName); % plots generator using the surrogates 

% add readme file
fileID = fopen(fullfile(plotsfolderName, 'readme.txt'), 'w');
fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables.\n\n');
fprintf(fileID, 'Legend:\n');
N_outputs = length(outputs_name);             % number of quantities of interest (QIs)
N_variables = length(inputs_name);            % number of uncertain variables
for kk = 1:N_outputs
    fprintf(fileID, 'QI %d: %s\n', kk, outputs_name(kk));
end   
for kk = 1:N_variables
    fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name(kk));
end    
fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots); 
fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
fclose(fileID);
disp('Readme file for the surrogates has been created successfully.');

set(0, 'DefaultFigureVisible', 'on');

% multi-objective optimisation using the surrogates
straight_nvars = 2;              % Number of design variables
straight_lb = [11, 0.45];        % Lower bounds
straight_ub = [23, 0.69];        % Upper bounds

plotsfolderName = 'straight_wing_uq'; 
addpath(plotsfolderName);
surrogates_straight_bf_doc = load('surrogates_straight_wing.mat');
surrogates_straight_bf_doc = surrogates_straight_bf_doc.elementToSave;
straight_objFun = @(x) myObjectives(x, surrogates_straight_bf_doc);

straight_options = optimoptions('gamultiobj', 'Display', 'iter', 'PlotFcn', @gaplotpareto);
[straight_wing_pareto, straight_fval] = gamultiobj(straight_objFun, straight_nvars, [], [], [], [], straight_lb, straight_ub, straight_options);
straight_pareto_size = size(straight_wing_pareto, 1);

true_model_straight_output_pareto = nan(straight_pareto_size, N_outputs);     
if flag_parfor
    parfor ii=1:straight_pareto_size
        try
            true_model_straight_output_pareto(ii, :) = uq_evalModel(myModel_straight_wing, straight_wing_pareto(ii, :));     
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
else   
    for ii=1:straight_pareto_size
        try
            true_model_straight_output_pareto(ii, :) = uq_evalModel(myModel_straight_wing, straight_wing_pareto(ii, :));
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
end   
straight_wing_pareto = straight_wing_pareto(~any(isnan(true_model_straight_output_pareto), 2), :);                           
true_model_straight_output_pareto = true_model_straight_output_pareto(~any(isnan(true_model_straight_output_pareto), 2), :); 

surrogate_output_straight_pareto = uq_evalModel(surrogates_straight_bf_doc, straight_wing_pareto);

for ii = 1:size(straight_wing_pareto, 1)
    relative_surrogate_error_straight_bf(ii) = abs(surrogate_output_straight_pareto(ii, 1)/true_model_straight_output_pareto(ii, 1)-1);
    relative_surrogate_error_straight_doc(ii) = abs(surrogate_output_straight_pareto(ii, 2)/true_model_straight_output_pareto(ii, 2)-1);
end

save(fullfile(plotsfolderName, 'opt_for_bf_and_doc_with_straight_wing.mat'), 'straight_wing_pareto', 'true_model_straight_output_pareto', 'relative_surrogate_error_straight_bf', 'relative_surrogate_error_straight_doc')

true_model_straight_sorted_points = sortrows(true_model_straight_output_pareto, 1);
surrogate_model_straight_sorted_points = sortrows(surrogate_output_straight_pareto, 1);

fig = figure();
plot(true_model_straight_sorted_points(:,1), true_model_straight_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Physical Model');
hold on 
plot(surrogate_model_straight_sorted_points(:,1), surrogate_model_straight_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Surrogate Model');
xlabel('Fuel Burn (FB)');
ylabel('Direct Operating Cost (DOC)');
title('Pareto Front (Genetic Algorithm with Kriging surrogates)');
grid on;
legend('Location', 'best');
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_straight_wing.png'))
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_straight_wing.fig'))

%% 3. Swept wing case (design variables: AR, Mach no.)
%{
--------------------------------------------------------
Comments:
* The same physical model is used as for the straight wing case
    * The only difference is that Mach no. can now be higher than 0.7, which introduces sweep (Sweep Angle is a function of Mach no.)
--------------------------------------------------------
%}

% This section generates many plots, which are saved rather than displayed on the screen
set(0, 'DefaultFigureVisible', 'off'); 

% Description of the uncertain variables for UQLab
InputOpts_swept_wing.Marginals(1).Type = 'Uniform';
InputOpts_swept_wing.Marginals(1).Parameters = [11, 23]; % (Aspect Ratio) lower and upper design optimisation bound
InputOpts_swept_wing.Marginals(2).Type = 'Uniform';
InputOpts_swept_wing.Marginals(2).Parameters = [0.45, 0.9]; % (Mach no.) lower and upper design optimisation bound
% The uncertain variables are inputs for physical maps that output QIs (i.e., Block Fuel, DOC, ...)
myInput_swept_wing = uq_createInput(InputOpts_swept_wing);

plotsfolderName = 'swept_wing_uq'; 
mkdir(plotsfolderName)

% Description of the physical model for UQLab
ModelOpts_swept_wing.mFile = 'physical_model_straight_wing'; 
ModelOpts_swept_wing.isVectorized = false;
myModel_swept_wing = uq_createModel(ModelOpts_swept_wing);

N_train = 5;    % initial training set size (the set will be updated until the training budget is exhausted or until the surrogate validation error is low enough)
MetaOpts_swept_wing.Type = 'Metamodel';                 % 'metamodel': another word for 'surrogate'    
MetaOpts_swept_wing.MetaType = 'Kriging';               % Kriging surrogate model
MetaOpts_swept_wing.Input = myInput_swept_wing;         % design variables
MetaOpts_swept_wing.FullModel = myModel_swept_wing;  % the physical model as a UQLab object
MetaOpts_swept_wing.ExpDesign.NSamples = N_train;       % 'experimental design' (ExpDesign): another word for 'training set'
if strcmp(MetaOpts_swept_wing.MetaType, 'Kriging')
    MetaOpts_swept_wing.ExpDesign.Sampling = 'User';
end

flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
N_train_increment = 8;          % we will increment the training set size until we reach convergence
N_train_max = 1500;             % training budget (i.e., maximum number of training points allowed)
flag_test_for_mean_and_sigma = false;

% Plots generator for parameter sweeps for the design variables
inputs_name = ["Aspect Ratio (AR)", "Mach number"];  % list of the names of the design variables
outputs_name = ["Block fuel", "Direct operating cost", "Wingspan", "CD0", "CD cruise", "MTOM"];   % list of the names of the QIs
N_outputs = length(outputs_name);             % number of quantities of interest (QIs)
descriptive_title_for_plots = sprintf('%s surrogate', MetaOpts_swept_wing.MetaType);
N_eval = 100;                                        % number of discretisation points for each design variable (for plots)
plotsfolderName = 'swept_wing_uq'; 
mkdir(plotsfolderName, 'plots_uq');
surrogates_swept_wing =  surrogates_uq(MetaOpts_swept_wing, N_outputs, N_train_increment, N_train_max, flag_parfor, seed, plotsfolderName, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
elementToSave = surrogates_swept_wing;
save(fullfile(plotsfolderName, 'surrogates_swept_wing.mat'), 'elementToSave'); % save the surrogate
% visualise the outputs as a function of the design variables (i.e., design exploration)
uncertain_variables_exploration(elementToSave, inputs_name, outputs_name, descriptive_title_for_plots, N_eval, seed, plotsfolderName); % plots generator using the surrogates 

% add readme file
fileID = fopen(fullfile(plotsfolderName, 'readme.txt'), 'w');
fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables.\n\n');
fprintf(fileID, 'Legend:\n');
N_outputs = length(outputs_name);             % number of quantities of interest (QIs)
N_variables = length(inputs_name);            % number of uncertain variables
for kk = 1:N_outputs
    fprintf(fileID, 'QI %d: %s\n', kk, outputs_name(kk));
end   
for kk = 1:N_variables
    fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name(kk));
end    
fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots); 
fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
fclose(fileID);
disp('Readme file for the surrogates has been created successfully.');

set(0, 'DefaultFigureVisible', 'on');

% multi-objective optimisation using the surrogates
swept_nvars = 2;              % Number of design variables
swept_lb = [11, 0.45];        % Lower bounds
swept_ub = [23, 0.9];         % Upper bounds

plotsfolderName = 'swept_wing_uq'; 
addpath(plotsfolderName);
surrogates_swept_bf_doc = load('surrogates_swept_wing.mat');
surrogates_swept_bf_doc = surrogates_swept_bf_doc.elementToSave;
swept_objFun = @(x) myObjectives(x, surrogates_swept_bf_doc);

swept_options = optimoptions('gamultiobj', 'Display', 'iter', 'PlotFcn', @gaplotpareto);
[swept_wing_pareto, swept_fval] = gamultiobj(swept_objFun, swept_nvars, [], [], [], [], swept_lb, swept_ub, swept_options);
swept_pareto_size = size(swept_wing_pareto, 1);

true_model_swept_output_pareto = nan(swept_pareto_size, N_outputs);     
if flag_parfor
    parfor ii=1:swept_pareto_size
        try
            true_model_swept_output_pareto(ii, :) = uq_evalModel(myModel_swept_wing, swept_wing_pareto(ii, :));     
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
else   
    for ii=1:swept_pareto_size
        try
            true_model_swept_output_pareto(ii, :) = uq_evalModel(myModel_swept_wing, swept_wing_pareto(ii, :));
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
end   
swept_wing_pareto = swept_wing_pareto(~any(isnan(true_model_swept_output_pareto), 2), :);                           
true_model_swept_output_pareto = true_model_swept_output_pareto(~any(isnan(true_model_swept_output_pareto), 2), :); 

surrogate_output_swept_pareto = uq_evalModel(surrogates_swept_bf_doc, swept_wing_pareto);

for ii = 1:size(swept_wing_pareto, 1)
    relative_surrogate_error_swept_bf(ii) = abs(surrogate_output_swept_pareto(ii, 1)/true_model_swept_output_pareto(ii, 1)-1);
    relative_surrogate_error_swept_doc(ii) = abs(surrogate_output_swept_pareto(ii, 2)/true_model_swept_output_pareto(ii, 2)-1);
end

save(fullfile(plotsfolderName, 'opt_for_bf_and_doc_with_swept_wing.mat'), 'swept_wing_pareto', 'true_model_swept_output_pareto', 'relative_surrogate_error_swept_bf', 'relative_surrogate_error_swept_doc')

true_model_swept_sorted_points = sortrows(true_model_swept_output_pareto, 1);
surrogate_model_swept_sorted_points = sortrows(surrogate_output_swept_pareto, 1);

fig = figure();
plot(true_model_swept_sorted_points(:,1), true_model_swept_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Physical Model');
hold on 
plot(surrogate_model_swept_sorted_points(:,1), surrogate_model_swept_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Surrogate Model');
xlabel('Fuel Burn (FB)');
ylabel('Direct Operating Cost (DOC)');
title('Pareto Front (Genetic Algorithm with Kriging surrogates)');
grid on;
legend();
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_swept_wing.png'))
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_swept_wing.fig'))

%% 4. Swept wing case (design variables: Sweep angle, Mach no.)
% For this section, the aspect ratio is fixed (AR=20)

% Description of the uncertain variables for UQLab
InputOpts_custom_swept_wing.Marginals(1).Type = 'Uniform';
InputOpts_custom_swept_wing.Marginals(1).Parameters = [0, 45]; % (Sweep angle) lower and upper design optimisation bound
InputOpts_custom_swept_wing.Marginals(2).Type = 'Uniform';
InputOpts_custom_swept_wing.Marginals(2).Parameters = [0.45, 0.9]; % (Mach no.) lower and upper design optimisation bound
% The uncertain variables are inputs for physical maps that output QIs (i.e., Block Fuel, DOC, ...)
myInput_custom_swept_wing = uq_createInput(InputOpts_custom_swept_wing);

% This section generates many plots, which are saved rather than displayed on the screen
set(0, 'DefaultFigureVisible', 'off');

plotsfolderName = 'indep_sweep_wing_uq'; 
mkdir(plotsfolderName)

% Description of the physical model for UQLab
ModelOpts_custom_swept_wing.mFile = 'physical_model_indep_sweep';
ModelOpts_custom_swept_wing.isVectorized = false;
myModel_custom_swept_wing = uq_createModel(ModelOpts_custom_swept_wing);

N_train = 5;    % initial training set size (the set will be updated until the training budget is exhausted or until the surrogate validation error is low enough)
MetaOpts_custom_swept_wing.Type = 'Metamodel';                        % 'metamodel': another word for 'surrogate'    
MetaOpts_custom_swept_wing.MetaType = 'Kriging';                      % Kriging surrogate model
MetaOpts_custom_swept_wing.Input = myInput_custom_swept_wing;         % design variables
MetaOpts_custom_swept_wing.FullModel = myModel_custom_swept_wing;     % the physical model as a UQLab object
MetaOpts_custom_swept_wing.ExpDesign.NSamples = N_train;              % 'experimental design' (ExpDesign): another word for 'training set'
if strcmp(MetaOpts_custom_swept_wing.MetaType, 'Kriging')
    MetaOpts_custom_swept_wing.ExpDesign.Sampling = 'User';
end

flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
N_train_increment = 8;          % we will increment the training set size until we reach convergence
N_train_max = 1500;             % training budget (i.e., maximum number of training points allowed)
flag_test_for_mean_and_sigma = false;

% Plots generator for parameter sweeps for the design variables
inputs_name = ["Sweep angle", "Mach number"];  % list of the names of the design variables
outputs_name = ["Block fuel", "Direct operating cost", "Wingspan", "CD0", "CD cruise", "MTOM"];   % list of the names of the QIs
N_outputs = length(outputs_name);             % number of quantities of interest (QIs)
descriptive_title_for_plots = sprintf('%s surrogate', MetaOpts_custom_swept_wing.MetaType);
N_eval = 100;                                        % number of discretisation points for each design variable (for plots)
plotsfolderName = 'indep_sweep_wing_uq'; 
mkdir(plotsfolderName, 'plots_uq');
surrogates_custom_swept_wing =  surrogates_uq(MetaOpts_custom_swept_wing, N_outputs, N_train_increment, N_train_max, flag_parfor, seed, plotsfolderName, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
elementToSave = surrogates_custom_swept_wing;
save(fullfile(plotsfolderName, 'surrogates_indep_sweep_wing.mat'), 'elementToSave'); % save the surrogate
% visualise the outputs as a function of the design variables (i.e., design exploration)
uncertain_variables_exploration(elementToSave, inputs_name, outputs_name, descriptive_title_for_plots, N_eval, seed, plotsfolderName); % plots generator using the surrogates 

% add readme file
fileID = fopen(fullfile(plotsfolderName, 'readme.txt'), 'w');
fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables.\n\n');
fprintf(fileID, 'Legend:\n');
N_outputs = length(outputs_name);             % number of quantities of interest (QIs)
N_variables = length(inputs_name);            % number of uncertain variables
for kk = 1:N_outputs
    fprintf(fileID, 'QI %d: %s\n', kk, outputs_name(kk));
end   
for kk = 1:N_variables
    fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name(kk));
end    
fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots); 
fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
fclose(fileID);
disp('Readme file for the surrogates has been created successfully.');

set(0, 'DefaultFigureVisible', 'on');

%multi-objective optimisation using the surrogates
custom_nvars = 2;              % Number of design variables
custom_lb = [0, 0.45];         % Lower bounds
custom_ub = [45, 0.9];         % Upper bounds

plotsfolderName = 'indep_sweep_wing_uq'; 
addpath(plotsfolderName);
surrogates_custom_bf_doc = load('surrogates_indep_sweep_wing.mat');
surrogates_custom_bf_doc = surrogates_custom_bf_doc.elementToSave;
custom_objFun = @(x) myObjectives(x, surrogates_custom_bf_doc);

custom_options = optimoptions('gamultiobj', 'Display', 'iter', 'PlotFcn', @gaplotpareto);
[indep_sweep_wing_pareto, custom_fval] = gamultiobj(custom_objFun, custom_nvars, [], [], [], [], custom_lb, custom_ub, custom_options);
custom_pareto_size = size(indep_sweep_wing_pareto, 1);

true_model_custom_output_pareto = nan(custom_pareto_size, N_outputs);     
if flag_parfor
    parfor ii=1:custom_pareto_size
        try
            true_model_custom_output_pareto(ii, :) = uq_evalModel(myModel_custom_swept_wing, indep_sweep_wing_pareto(ii, :));     % evaluate the physical model on the training inputs
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
else   
    for ii=1:custom_pareto_size
        try
            true_model_custom_output_pareto(ii, :) = uq_evalModel(myModel_custom_swept_wing, indep_sweep_wing_pareto(ii, :));
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
end   
indep_sweep_wing_pareto = indep_sweep_wing_pareto(~any(isnan(true_model_custom_output_pareto), 2), :);                           
true_model_custom_output_pareto = true_model_custom_output_pareto(~any(isnan(true_model_custom_output_pareto), 2), :); 

surrogate_output_custom_pareto = uq_evalModel(surrogates_custom_bf_doc, indep_sweep_wing_pareto);

for ii = 1:size(indep_sweep_wing_pareto, 1)
    relative_surrogate_error_indep_sweep_bf(ii) = abs(surrogate_output_custom_pareto(ii, 1)/true_model_custom_output_pareto(ii, 1)-1);
    relative_surrogate_error_indep_sweep_doc(ii) = abs(surrogate_output_custom_pareto(ii, 2)/true_model_custom_output_pareto(ii, 2)-1);
end

save(fullfile(plotsfolderName, 'opt_for_bf_and_doc_with_indep_sweep.mat'), 'indep_sweep_wing_pareto', 'true_model_custom_output_pareto', 'relative_surrogate_error_indep_sweep_bf', 'relative_surrogate_error_indep_sweep_doc')

true_model_custom_sorted_points = sortrows(true_model_custom_output_pareto, 1);
surrogate_model_custom_sorted_points = sortrows(surrogate_output_custom_pareto, 1);

fig = figure();
plot(true_model_custom_sorted_points(:,1), true_model_custom_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Physical Model');
hold on 
plot(surrogate_model_custom_sorted_points(:,1), surrogate_model_custom_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Surrogate Model');
xlabel('Fuel Burn (FB)');
ylabel('Direct Operating Cost (DOC)');
title('Pareto Front (Genetic Algorithm with Kriging surrogates)');
grid on;
legend();
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_indep_sweep.png'))
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_indep_sweep.fig'))

%% 5. Swept wing case (design variables: Sweep angle, Mach no., AR)

% Description of the uncertain variables for UQLab
InputOpts_all_custom_swept_wing.Marginals(1).Type = 'Uniform';
InputOpts_all_custom_swept_wing.Marginals(1).Parameters = [0, 45]; % (Sweep angle) lower and upper design optimisation bound
InputOpts_all_custom_swept_wing.Marginals(2).Type = 'Uniform';
InputOpts_all_custom_swept_wing.Marginals(2).Parameters = [0.45, 0.9]; % (Mach no.) lower and upper design optimisation bound
InputOpts_all_custom_swept_wing.Marginals(3).Type = 'Uniform';
InputOpts_all_custom_swept_wing.Marginals(3).Parameters = [11, 23]; % (AR) lower and upper design optimisation bound
% The uncertain variables are inputs for physical maps that output QIs (i.e., Block Fuel, DOC, ...)
myInput_all_custom_swept_wing = uq_createInput(InputOpts_all_custom_swept_wing);

% This section generates many plots, which are saved rather than displayed on the screen
set(0, 'DefaultFigureVisible', 'off');

plotsfolderName = 'indep_sweep_and_ar_wing_uq'; 
mkdir(plotsfolderName)

% Description of the physical model for UQLab
ModelOpts_all_custom_swept_wing.mFile = 'physical_model_indep_sweep_and_ar';
ModelOpts_all_custom_swept_wing.isVectorized = false;
myModel_all_custom_swept_wing = uq_createModel(ModelOpts_all_custom_swept_wing);

N_train = 5;    % initial training set size (the set will be updated until the training budget is exhausted or until the surrogate validation error is low enough)
MetaOpts_all_custom_swept_wing.Type = 'Metamodel';                            % 'metamodel': another word for 'surrogate'    
MetaOpts_all_custom_swept_wing.MetaType = 'Kriging';                          % Kriging surrogate model
MetaOpts_all_custom_swept_wing.Input = myInput_all_custom_swept_wing;         % design variables
MetaOpts_all_custom_swept_wing.FullModel = myModel_all_custom_swept_wing;     % the physical model as a UQLab object
MetaOpts_all_custom_swept_wing.ExpDesign.NSamples = N_train;                  % 'experimental design' (ExpDesign): another word for 'training set'
if strcmp(MetaOpts_all_custom_swept_wing.MetaType, 'Kriging')
    MetaOpts_all_custom_swept_wing.ExpDesign.Sampling = 'User';
end

flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
N_train_increment = 8;          % we will increment the training set size until we reach convergence
N_train_max = 1500;             % training budget (i.e., maximum number of training points allowed)
flag_test_for_mean_and_sigma = false;

% Plots generator for parameter sweeps for the design variables
inputs_name = ["Sweep angle", "Mach number", "Aspect ratio"];  % list of the names of the design variables
outputs_name = ["Block fuel", "Direct operating cost", "Wingspan", "CD0", "CD cruise", "MTOM"];   % list of the names of the QIs
N_outputs = length(outputs_name);                    % number of quantities of interest (QIs)
descriptive_title_for_plots = sprintf('%s surrogate', MetaOpts_all_custom_swept_wing.MetaType);
N_eval = 100;                                        % number of discretisation points for each design variable (for plots)
plotsfolderName = 'indep_sweep_and_ar_wing_uq'; 
mkdir(plotsfolderName, 'plots_uq');
surrogates_all_custom_swept_wing =  surrogates_uq(MetaOpts_all_custom_swept_wing, N_outputs, N_train_increment, N_train_max, flag_parfor, seed, plotsfolderName, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
elementToSave = surrogates_all_custom_swept_wing;
save(fullfile(plotsfolderName, 'surrogates_indep_sweep_and_ar_wing.mat'), 'elementToSave'); % save the surrogate
% visualise the outputs as a function of the design variables (i.e., design exploration)
uncertain_variables_exploration(elementToSave, inputs_name, outputs_name, descriptive_title_for_plots, N_eval, seed, plotsfolderName); % plots generator using the surrogates 

% add readme file
fileID = fopen(fullfile(plotsfolderName, 'readme.txt'), 'w');
fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables.\n\n');
fprintf(fileID, 'Legend:\n');
N_outputs = length(outputs_name);             % number of quantities of interest (QIs)
N_variables = length(inputs_name);            % number of uncertain variables
for kk = 1:N_outputs
    fprintf(fileID, 'QI %d: %s\n', kk, outputs_name(kk));
end   
for kk = 1:N_variables
    fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name(kk));
end    
fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots); 
fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
fclose(fileID);
disp('Readme file for the surrogates has been created successfully.');

set(0, 'DefaultFigureVisible', 'on');

% multi-objective optimisation using the surrogates
all_custom_nvars = 3;                  % Number of design variables
all_custom_lb = [0, 0.45, 11];         % Lower bounds
all_custom_ub = [45, 0.9, 23];         % Upper bounds

plotsfolderName = 'indep_sweep_and_ar_wing_uq'; 
addpath(plotsfolderName);
surrogates_all_custom_bf_doc = load('surrogates_indep_sweep_and_ar_wing.mat');
surrogates_all_custom_bf_doc = surrogates_all_custom_bf_doc.elementToSave;
all_custom_objFun = @(x) myObjectives(x, surrogates_all_custom_bf_doc);

all_custom_options = optimoptions('gamultiobj', 'Display', 'iter', 'PlotFcn', @gaplotpareto);
[indep_sweep_and_ar_wing_pareto, all_custom_fval] = gamultiobj(all_custom_objFun, all_custom_nvars, [], [], [], [], all_custom_lb, all_custom_ub, all_custom_options);
all_custom_pareto_size = size(indep_sweep_and_ar_wing_pareto, 1);

true_model_all_custom_output_pareto = nan(all_custom_pareto_size, N_outputs);     
if flag_parfor
    parfor ii=1:all_custom_pareto_size
        try
            true_model_all_custom_output_pareto(ii, :) = uq_evalModel(myModel_all_custom_swept_wing, indep_sweep_and_ar_wing_pareto(ii, :));     % evaluate the physical model on the training inputs
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
else   
    for ii=1:all_custom_pareto_size
        try
            true_model_all_custom_output_pareto(ii, :) = uq_evalModel(myModel_all_custom_swept_wing, indep_sweep_and_ar_wing_pareto(ii, :));
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
end   
indep_sweep_and_ar_wing_pareto = indep_sweep_and_ar_wing_pareto(~any(isnan(true_model_all_custom_output_pareto), 2), :);                           
true_model_all_custom_output_pareto = true_model_all_custom_output_pareto(~any(isnan(true_model_all_custom_output_pareto), 2), :); 

surrogate_output_all_custom_pareto = uq_evalModel(surrogates_all_custom_bf_doc, indep_sweep_and_ar_wing_pareto);

for ii = 1:size(indep_sweep_and_ar_wing_pareto, 1)
    relative_surrogate_error_indep_sweep_and_ar_bf(ii) = abs(surrogate_output_all_custom_pareto(ii, 1)/true_model_all_custom_output_pareto(ii, 1)-1);
    relative_surrogate_error_indep_sweep_and_ar_doc(ii) = abs(surrogate_output_all_custom_pareto(ii, 2)/true_model_all_custom_output_pareto(ii, 2)-1);
end

save(fullfile(plotsfolderName, 'opt_for_bf_and_doc_with_indep_sweep_and_ar.mat'), 'indep_sweep_and_ar_wing_pareto', 'true_model_all_custom_output_pareto','relative_surrogate_error_indep_sweep_and_ar_bf', 'relative_surrogate_error_indep_sweep_and_ar_doc')

true_model_all_custom_sorted_points = sortrows(true_model_all_custom_output_pareto, 1);
surrogate_model_all_custom_sorted_points = sortrows(surrogate_output_all_custom_pareto, 1);

fig = figure();
plot(true_model_all_custom_sorted_points(:,1), true_model_all_custom_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Physical Model');
hold on 
plot(surrogate_model_all_custom_sorted_points(:,1), surrogate_model_all_custom_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Surrogate Model');
xlabel('Fuel Burn (FB)');
ylabel('Direct Operating Cost (DOC)');
title('Pareto Front (Genetic Algorithm with Kriging surrogates)');
grid on;
legend();
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_indep_sweep_and_ar.png'))
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_indep_sweep_and_ar.fig'))

%% 6. Straight wing case (NASTRAN; design variables: AR, Mach no.)

% This section generates many plots, which are saved rather than displayed on the screen
set(0, 'DefaultFigureVisible', 'off'); 

% Description of the uncertain variables for UQLab
InputOpts_straight_wing_nastran.Marginals(1).Type = 'Uniform';
InputOpts_straight_wing_nastran.Marginals(1).Parameters = [11, 23]; % (Aspect Ratio) lower and upper design optimisation bound
InputOpts_straight_wing_nastran.Marginals(2).Type = 'Uniform';
InputOpts_straight_wing_nastran.Marginals(2).Parameters = [0.45, 0.69]; % (Mach no.) lower and upper design optimisation bound - straight wing
% The uncertain variables are inputs for physical maps that output QIs (i.e., Block Fuel, DOC, ...)
myInput_straight_wing_nastran = uq_createInput(InputOpts_straight_wing_nastran);

plotsfolderName = 'straight_wing_nastran_uq'; 
mkdir(plotsfolderName)

% % Description of the physical model for UQLab
ModelOpts_straight_wing_nastran.mFile = 'physical_model_straight_wing_nastran';
ModelOpts_straight_wing_nastran.isVectorized = false;
myModel_straight_wing_nastran = uq_createModel(ModelOpts_straight_wing_nastran);

N_train = 5;    % initial training set size (the set will be updated until the training budget is exhausted or until the surrogate validation error is low enough)
MetaOpts_straight_wing_nastran.Type = 'Metamodel';                         % 'metamodel': another word for 'surrogate'    
MetaOpts_straight_wing_nastran.MetaType = 'PCE';                           % Polynomial Chaos Expansion surrogate model
MetaOpts_straight_wing_nastran.Input = myInput_straight_wing_nastran;      % design variables
MetaOpts_straight_wing_nastran.FullModel = myModel_straight_wing_nastran;  % the physical model as a UQLab object
MetaOpts_straight_wing_nastran.ExpDesign.NSamples = N_train;               % 'experimental design' (ExpDesign): another word for 'training set'
if strcmp(MetaOpts_straight_wing_nastran.MetaType, 'Kriging')
    MetaOpts_straight_wing_nastran.ExpDesign.Sampling = 'User';
end

flag_parfor = false;            % can we run the physical model in parallel to build the training set? (True/False)
seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
N_train_increment = 8;          % we will increment the training set size until we reach convergence
N_train_max = 20;               % training budget (i.e., maximum number of training points allowed)
flag_test_for_mean_and_sigma = false;

% Plots generator for parameter sweeps for the design variables
inputs_name = ["Aspect Ratio (AR)", "Mach number"];  % list of the names of the design variables
outputs_name = ["Block fuel", "Direct operating cost", "Wingspan", "CD0", "CD cruise", "MTOM"];   % list of the names of the QIs
N_outputs = length(outputs_name);             % number of quantities of interest (QIs)
% descriptive_title_for_plots = sprintf('%s surrogate', MetaOpts_straight_wing_nastran.MetaType);
N_eval = 100;                                        % number of discretisation points for each design variable (for plots)
plotsfolderName = 'straight_wing_nastran_uq'; 
mkdir(plotsfolderName, 'plots_uq');
surrogates_straight_wing_nastran =  surrogates_uq(MetaOpts_straight_wing_nastran, N_outputs, N_train_increment, N_train_max, flag_parfor, seed, plotsfolderName, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
elementToSave = surrogates_straight_wing_nastran;
save(fullfile(plotsfolderName, 'surrogates_straight_wing_nastran.mat'), 'elementToSave'); % save the surrogate
% visualise the outputs as a function of the design variables (i.e., design exploration)
uncertain_variables_exploration(elementToSave, inputs_name, outputs_name, descriptive_title_for_plots, N_eval, seed, plotsfolderName); % plots generator using the surrogates 

% add readme file
fileID = fopen(fullfile(plotsfolderName, 'readme.txt'), 'w');
fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables.\n\n');
fprintf(fileID, 'Legend:\n');
N_outputs = length(outputs_name);             % number of quantities of interest (QIs)
N_variables = length(inputs_name);            % number of uncertain variables
for kk = 1:N_outputs
    fprintf(fileID, 'QI %d: %s\n', kk, outputs_name(kk));
end   
for kk = 1:N_variables
    fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name(kk));
end    
fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots); 
fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
fclose(fileID);
disp('Readme file for the surrogates has been created successfully.');

set(0, 'DefaultFigureVisible', 'on');

% multi-objective optimisation using the surrogates
straight_nastran_nvars = 2;              % Number of design variables
straight_nastran_lb = [11, 0.45];        % Lower bounds
straight_nastran_ub = [23, 0.69];        % Upper bounds

plotsfolderName = 'straight_wing_nastran_uq'; 
addpath(plotsfolderName);
surrogates_straight_nastran_bf_doc = load('surrogates_straight_wing_nastran.mat');
surrogates_straight_nastran_bf_doc = surrogates_straight_nastran_bf_doc.elementToSave;
straight_nastran_objFun = @(x) myObjectives(x, surrogates_straight_nastran_bf_doc);

straight_nastran_options = optimoptions('gamultiobj', 'Display', 'iter', 'PlotFcn', @gaplotpareto);
[straight_nastran_wing_pareto, straight_nastran_fval] = gamultiobj(straight_nastran_objFun, straight_nastran_nvars, [], [], [], [], straight_nastran_lb, straight_nastran_ub, straight_nastran_options);
straight_nastran_pareto_size = size(straight_nastran_wing_pareto, 1);

true_model_straight_nastran_output_pareto = nan(straight_nastran_pareto_size, N_outputs);     
if flag_parfor
    parfor ii=1:straight_nastran_pareto_size
        try
            true_model_straight_nastran_output_pareto(ii, :) = uq_evalModel(myModel_straight_wing_nastran, straight_nastran_wing_pareto(ii, :));     
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
else   
    for ii=1:straight_nastran_pareto_size
        try
            true_model_straight_nastran_output_pareto(ii, :) = uq_evalModel(myModel_straight_wing_nastran, straight_nastran_wing_pareto(ii, :));
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
end   
straight_nastran_wing_pareto = straight_nastran_wing_pareto(~any(isnan(true_model_straight_nastran_output_pareto), 2), :);                           
true_model_straight_nastran_output_pareto = true_model_straight_nastran_output_pareto(~any(isnan(true_model_straight_nastran_output_pareto), 2), :); 
surrogate_output_straight_nastran_pareto = uq_evalModel(surrogates_straight_nastran_bf_doc, straight_nastran_wing_pareto);

try              % the physical model might crash at all the Pareto points
    for ii = 1:size(straight_nastran_wing_pareto, 1)
        relative_surrogate_error_straight_nastran_bf(ii) = abs(surrogate_output_straight_nastran_pareto(ii, 1)/true_model_straight_nastran_output_pareto(ii, 1)-1);
        relative_surrogate_error_straight_nastran_doc(ii) = abs(surrogate_output_straight_nastran_pareto(ii, 2)/true_model_straight_nastran_output_pareto(ii, 2)-1);
    end
    
    save(fullfile(plotsfolderName, 'opt_for_bf_and_doc_with_straight_wing_nastran.mat'), 'straight_nastran_wing_pareto', 'true_model_straight_nastran_output_pareto', 'relative_surrogate_error_straight_nastran_bf', 'relative_surrogate_error_straight_nastran_doc')
    
    true_model_straight_nastran_sorted_points = sortrows(true_model_straight_nastran_output_pareto, 1);
    surrogate_model_straight_nastran_sorted_points = sortrows(surrogate_output_straight_nastran_pareto, 1);
    
    fig = figure();
    plot(true_model_straight_nastran_sorted_points(:,1), true_model_straight_nastran_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Physical Model');
    hold on 
    plot(surrogate_model_straight_nastran_sorted_points(:,1), surrogate_model_straight_nastran_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Surrogate Model');
    xlabel('Fuel Burn (FB)');
    ylabel('Direct Operating Cost (DOC)');
    title('Pareto Front (Genetic Algorithm with Kriging surrogates)');
    grid on;
    legend('Location', 'best');
    saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_straight_wing_nastran.png'))
    saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_straight_wing_nastran.fig'))
catch ME
    fprintf('Error: %s\n', ME.message);
end    

%% 7. Swept wing case (design variables: Sweep angle, Mach no., AR, HingeEta, Flare angle)

% Description of the uncertain variables for UQLab
InputOpts_all_custom_swept_wing_fwt.Marginals(1).Type = 'Uniform';
InputOpts_all_custom_swept_wing_fwt.Marginals(1).Parameters = [0, 45];     % (Sweep angle) lower and upper design optimisation bound
InputOpts_all_custom_swept_wing_fwt.Marginals(2).Type = 'Uniform';
InputOpts_all_custom_swept_wing_fwt.Marginals(2).Parameters = [0.45, 0.9]; % (Mach no.) lower and upper design optimisation bound
InputOpts_all_custom_swept_wing_fwt.Marginals(3).Type = 'Uniform';
InputOpts_all_custom_swept_wing_fwt.Marginals(3).Parameters = [11, 23];    % (AR) lower and upper design optimisation bound
InputOpts_all_custom_swept_wing_fwt.Marginals(4).Type = 'Uniform';
InputOpts_all_custom_swept_wing_fwt.Marginals(4).Parameters = [0.45, 1];   % (HingeEta) lower and upper design optimisation bound
InputOpts_all_custom_swept_wing_fwt.Marginals(5).Type = 'Uniform';
InputOpts_all_custom_swept_wing_fwt.Marginals(5).Parameters = [5, 35];     % (Flare angle) lower and upper design optimisation bound
% The uncertain variables are inputs for physical maps that output QIs (i.e., Block Fuel, DOC, ...)
myInput_all_custom_swept_wing_fwt = uq_createInput(InputOpts_all_custom_swept_wing_fwt);

% This section generates many plots, which are saved rather than displayed on the screen
set(0, 'DefaultFigureVisible', 'off');

plotsfolderName = 'indep_sweep_ar_he_and_fa_wing_uq'; 
mkdir(plotsfolderName)

% Description of the physical model for UQLab
ModelOpts_all_custom_swept_wing_fwt.mFile = 'physical_model_indep_sweep_ar_he_and_fa';
ModelOpts_all_custom_swept_wing_fwt.isVectorized = false;
myModel_all_custom_swept_wing_fwt = uq_createModel(ModelOpts_all_custom_swept_wing_fwt);

N_train = 5;    % initial training set size (the set will be updated until the training budget is exhausted or until the surrogate validation error is low enough)
MetaOpts_all_custom_swept_wing_fwt.Type = 'Metamodel';                                % 'metamodel': another word for 'surrogate'    
MetaOpts_all_custom_swept_wing_fwt.MetaType = 'Kriging';                              % Kriging surrogate model
MetaOpts_all_custom_swept_wing_fwt.Input = myInput_all_custom_swept_wing_fwt;         % design variables
MetaOpts_all_custom_swept_wing_fwt.FullModel = myModel_all_custom_swept_wing_fwt;     % the physical model as a UQLab object
MetaOpts_all_custom_swept_wing_fwt.ExpDesign.NSamples = N_train;                      % 'experimental design' (ExpDesign): another word for 'training set'
if strcmp(MetaOpts_all_custom_swept_wing_fwt.MetaType, 'Kriging')
    MetaOpts_all_custom_swept_wing_fwt.ExpDesign.Sampling = 'User';
end

flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
N_train_increment = 8;          % we will increment the training set size until we reach convergence
N_train_max = 1500;             % training budget (i.e., maximum number of training points allowed)
flag_test_for_mean_and_sigma = false;

% Plots generator for parameter sweeps for the design variables
inputs_name = ["Sweep angle", "Mach number", "Aspect ratio", "Hinge eta", "Flare angle"];  % list of the names of the design variables
outputs_name = ["Block fuel", "Direct operating cost", "Flightspan", "Groundspan", "CD0", "CD cruise", "MTOM"];   % list of the names of the QIs
N_outputs = length(outputs_name);                    % number of quantities of interest (QIs)
descriptive_title_for_plots = sprintf('%s surrogate', MetaOpts_all_custom_swept_wing_fwt.MetaType);
N_eval = 100;                                        % number of discretisation points for each design variable (for plots)
plotsfolderName = 'indep_sweep_ar_he_and_fa_wing_uq'; 
mkdir(plotsfolderName, 'plots_uq');
tic;
surrogates_all_custom_swept_wing_fwt =  surrogates_uq(MetaOpts_all_custom_swept_wing_fwt, N_outputs, N_train_increment, N_train_max, flag_parfor, seed, plotsfolderName, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
totalTime = toc;
fprintf('Total surrogate building time: %.4f seconds\n', totalTime);
elementToSave = surrogates_all_custom_swept_wing_fwt;
save(fullfile(plotsfolderName, 'surrogates_indep_sweep_ar_he_and_fa_wing.mat'), 'elementToSave'); % save the surrogate
% visualise the outputs as a function of the design variables (i.e., design exploration)
tic;
uncertain_variables_exploration(elementToSave, inputs_name, outputs_name, descriptive_title_for_plots, N_eval, seed, plotsfolderName); % plots generator using the surrogates 
totalTime = toc;
fprintf('Total design space exploration time: %.4f seconds\n', totalTime);
% add readme file
fileID = fopen(fullfile(plotsfolderName, 'readme.txt'), 'w');
fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables.\n\n');
fprintf(fileID, 'Legend:\n');
N_outputs = length(outputs_name);             % number of quantities of interest (QIs)
N_variables = length(inputs_name);            % number of uncertain variables
for kk = 1:N_outputs
    fprintf(fileID, 'QI %d: %s\n', kk, outputs_name(kk));
end   
for kk = 1:N_variables
    fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name(kk));
end    
fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots); 
fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
fclose(fileID);
disp('Readme file for the surrogates has been created successfully.');

set(0, 'DefaultFigureVisible', 'on');

% multi-objective optimisation using the surrogates
all_custom_he_fa_nvars = 5;                  % Number of design variables
all_custom_he_fa_lb = [0, 0.45, 11, 0.45, 5];      % Lower bounds
all_custom_he_fa_ub = [45, 0.9, 23, 1, 35];        % Upper bounds

plotsfolderName = 'indep_sweep_ar_he_and_fa_wing_uq';
addpath(plotsfolderName);
surrogates_all_custom_he_fa_bf_doc = load('surrogates_indep_sweep_ar_he_and_fa_wing.mat');
surrogates_all_custom_he_fa_bf_doc = surrogates_all_custom_he_fa_bf_doc.elementToSave;
all_custom_he_fa_objFun = @(x) myObjectives(x, surrogates_all_custom_he_fa_bf_doc);

all_custom_he_fa_options = optimoptions('gamultiobj', 'Display', 'iter', 'PlotFcn', @gaplotpareto);
[indep_sweep_and_ar_he_fa_wing_pareto, all_custom_he_fa_fval] = gamultiobj(all_custom_he_fa_objFun, all_custom_he_fa_nvars, [], [], [], [], all_custom_he_fa_lb, all_custom_he_fa_ub, all_custom_he_fa_options);
all_custom_he_fa_pareto_size = size(indep_sweep_and_ar_he_fa_wing_pareto, 1);

true_model_all_custom_he_fa_output_pareto = nan(all_custom_he_fa_pareto_size, N_outputs);     
if flag_parfor
    parfor ii=1:all_custom_he_fa_pareto_size
        try
            true_model_all_custom_he_fa_output_pareto(ii, :) = uq_evalModel(myModel_all_custom_swept_wing_fwt, indep_sweep_and_ar_he_fa_wing_pareto(ii, :));     % evaluate the physical model on the training inputs
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
else   
    for ii=1:all_custom_he_fa_pareto_size
        try
            true_model_all_custom_he_fa_output_pareto(ii, :) = uq_evalModel(myModel_all_custom_swept_wing_fwt, indep_sweep_and_ar_he_fa_wing_pareto(ii, :));
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
end   
indep_sweep_and_ar_he_fa_wing_pareto = indep_sweep_and_ar_he_fa_wing_pareto(~any(isnan(true_model_all_custom_he_fa_output_pareto), 2), :);                           
true_model_all_custom_he_fa_output_pareto = true_model_all_custom_he_fa_output_pareto(~any(isnan(true_model_all_custom_he_fa_output_pareto), 2), :); 

surrogate_output_all_custom_he_fa_pareto = uq_evalModel(surrogates_all_custom_he_fa_bf_doc, indep_sweep_and_ar_he_fa_wing_pareto);

for ii = 1:size(indep_sweep_and_ar_he_fa_wing_pareto, 1)
    relative_surrogate_error_indep_sweep_and_ar_he_fa_bf(ii) = abs(surrogate_output_all_custom_he_fa_pareto(ii, 1)/true_model_all_custom_he_fa_output_pareto(ii, 1)-1);
    relative_surrogate_error_indep_sweep_and_ar_he_fa_doc(ii) = abs(surrogate_output_all_custom_he_fa_pareto(ii, 2)/true_model_all_custom_he_fa_output_pareto(ii, 2)-1);
    if relative_surrogate_error_indep_sweep_and_ar_he_fa_doc(ii) >= 0.01 | relative_surrogate_error_indep_sweep_and_ar_he_fa_bf(ii) >= 0.01
        indep_sweep_and_ar_he_fa_wing_pareto(ii, :) = [];
        true_model_all_custom_he_fa_output_pareto(ii, :) = [];
        surrogate_output_all_custom_he_fa_pareto(ii, :) = [];
        relative_surrogate_error_indep_sweep_and_ar_he_fa_doc(ii) = [];
        relative_surrogate_error_indep_sweep_and_ar_he_fa_bf(ii) = [];
    end
end

save(fullfile(plotsfolderName, 'opt_for_bf_and_doc_with_indep_sweep_and_ar.mat'), 'indep_sweep_and_ar_he_fa_wing_pareto', 'true_model_all_custom_he_fa_output_pareto','relative_surrogate_error_indep_sweep_and_ar_he_fa_bf', 'relative_surrogate_error_indep_sweep_and_ar_he_fa_doc')

true_model_all_custom_he_fa_sorted_points = sortrows(true_model_all_custom_he_fa_output_pareto, 1);
surrogate_model_all_custom_he_fa_sorted_points = sortrows(surrogate_output_all_custom_he_fa_pareto, 1);

fig = figure();
plot(true_model_all_custom_he_fa_sorted_points(:,1), true_model_all_custom_he_fa_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Physical Model');
hold on 
plot(surrogate_model_all_custom_he_fa_sorted_points(:,1), surrogate_model_all_custom_he_fa_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Surrogate Model');
xlabel('Fuel Burn (FB)');
ylabel('Direct Operating Cost (DOC)');
title('Pareto Front (Genetic Algorithm with Kriging surrogates)');
grid on;
legend();
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_indep_sweep_and_ar_he_fa.png'))
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_indep_sweep_and_ar_he_fa.fig'))

%% 8. Robust optimisation (straight wing, uncertain fuel price)

% Robust Optimisation - Description of the uncertain variables for UQLab
InputOpts_straight_wing_uncertain_price.Marginals(1).Type = 'Uniform';
InputOpts_straight_wing_uncertain_price.Marginals(1).Parameters = [0.9*0.64995, 1.1*0.64995]; % (Fuel price) lower and upper uncertainty bound
InputOpts_straight_wing_uncertain_price.Marginals(2).Type = 'Uniform';
InputOpts_straight_wing_uncertain_price.Marginals(2).Parameters = [0.9*30.0, 1.1*30.0]; % (Oil price) lower and upper uncertainty bound
% The uncertain variables are inputs for physical maps that output QIs
myInput_straight_wing_uncertain_price = uq_createInput(InputOpts_straight_wing_uncertain_price); 

set(0, 'DefaultFigureVisible', 'off');

ar_straight_wing_uncertain_price = linspace(11, 23, 10);  
mach_straight_wing_uncertain_price = linspace(0.45, 0.69, 10);
surrogates_straight_wing_uncertain_price = cell(length(ar_straight_wing_uncertain_price), length(mach_straight_wing_uncertain_price));

for ii = 1:length(ar_straight_wing_uncertain_price)
    for jj = 1:length(mach_straight_wing_uncertain_price)
        % Description of the physical model for UQLab
        ModelOpts_straight_wing_uncertain_price.mFile = 'physical_model_straight_wing_uncertain_fuel_price';
        ModelOpts_straight_wing_uncertain_price.isVectorized = false;
        ModelOpts_straight_wing_uncertain_price.Parameters = [ar_straight_wing_uncertain_price(ii) mach_straight_wing_uncertain_price(jj)];
        myModel_straight_wing_uncertain_price = uq_createModel(ModelOpts_straight_wing_uncertain_price);

        N_train = 5;                                     % initial training set size (the set will be updated until the surrogate validation error is low enough)
        MetaOpts_straight_wing_uncertain_price.Type = 'Metamodel';             % 'metamodel': another word for 'surrogate'
        % MetaOpts_straight_wing_uncertain_price.MetaType = 'Kriging';      
        MetaOpts_straight_wing_uncertain_price.MetaType = 'PCE';
        MetaOpts_straight_wing_uncertain_price.Input = myInput_straight_wing_uncertain_price;        % probability distribution for the uncertain variables
        MetaOpts_straight_wing_uncertain_price.FullModel = myModel_straight_wing_uncertain_price;    % the physical model as a UQLab object
        MetaOpts_straight_wing_uncertain_price.ExpDesign.NSamples = N_train;   % 'experimental design' (ExpDesign): another word for 'training set'
        if strcmp(MetaOpts_straight_wing_uncertain_price.MetaType, 'Kriging')
            MetaOpts_straight_wing_uncertain_price.ExpDesign.Sampling = 'User';
        end

        flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
        seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
        N_train_increment = 5;          % we will increment the training set size until we reach convergence
        N_train_max = 5;                % training budget (i.e., maximum number of training points allowed)
        % run a test to check if surrogates are actually faster than classical MC for mean and sigma estimation  
        % recommended only for cheap models (to find the true mean and sigma, we need a large MC with the physical model) 
        flag_test_for_mean_and_sigma = false;

        % Plots generator for parameter sweeps for the uncertain variables
        inputs_name_straight_wing_uncertain_price = ["Fuel price", "Oil price"];  % list of the names of the uncertain variables
        outputs_name_straight_wing_uncertain_price = ["Total operating cost"];    % list of the names of the QIs
        N_outputs_straight_wing_uncertain_price = length(outputs_name_straight_wing_uncertain_price);           % number of quantities of interest (QIs)
        descriptive_title_for_plots_straight_wing_uncertain_price = sprintf('%s surrogate (AR:%.2e, Mach:%.2e)', MetaOpts_straight_wing_uncertain_price.MetaType, ar_straight_wing_uncertain_price(ii), mach_straight_wing_uncertain_price(jj));
        N_eval = 100;                                                        % number of discretisation points for each uncertain variable (for plots)
        plotsfolderName = 'straight_wing_uncertain_price_optimisation_uq'; 
        subfolder_plotsfolderName = sprintf('ar_%u_mach_%u', ii, jj); % each 'case' refers to one fixed combination of design variables
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        mkdir(fullPath);
        mkdir(fullPath, 'plots_uq');
        try
            surrogates_straight_wing_uncertain_price{ii, jj} =  surrogates_uq(MetaOpts_straight_wing_uncertain_price, N_outputs_straight_wing_uncertain_price, N_train_increment, N_train_max, flag_parfor, seed, fullPath, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
            elementToSave = surrogates_straight_wing_uncertain_price{ii, jj}; 
            save(fullfile(fullPath, sprintf('surrogate_total_operating_cost_ar_case_%u_mach_case_%u.mat', ii, jj)), 'elementToSave'); % save the surrogate
            uncertain_variables_exploration(elementToSave, inputs_name_straight_wing_uncertain_price, outputs_name_straight_wing_uncertain_price, descriptive_title_for_plots_straight_wing_uncertain_price, N_eval, seed, fullPath); % plots generator using the surrogates 
            % add readme to explain each 'case' (i.e., each fixed combination (ii, jj) of design variables)
            fileID = fopen(fullfile(fullPath, 'readme.txt'), 'w');
            fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables (the deterministic variables are fixed).\n\n');
            fprintf(fileID, 'Legend:\n');
            N_outputs_straight_wing_uncertain_price = length(outputs_name_straight_wing_uncertain_price);             % number of quantities of interest (QIs)
            N_variables_straight_wing_uncertain_price = length(inputs_name_straight_wing_uncertain_price);            % number of uncertain variables
            for kk = 1:N_outputs_straight_wing_uncertain_price
                fprintf(fileID, 'QI %d: %s\n', kk, outputs_name_straight_wing_uncertain_price(kk));
            end   
            for kk = 1:N_variables_straight_wing_uncertain_price
                fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name_straight_wing_uncertain_price(kk));
            end    
            fprintf(fileID, 'Deterministic variable 1: Aspect ratio; Case: %d out of %d; Value: %.5f\n', ii, length(ar_straight_wing_uncertain_price), ar_straight_wing_uncertain_price(ii));
            fprintf(fileID, 'Deterministic variable 2: Mach number; Case: %d out of %d; Value: %.5f\n', jj, length(mach_straight_wing_uncertain_price), mach_straight_wing_uncertain_price(jj));
            fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots_straight_wing_uncertain_price);
            fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
            fclose(fileID);
            disp('Readme file for the surrogates has been created successfully.');
        catch ME
            fprintf('Error in sample (%d, %d): %s\n', ii, jj, ME.message);
        end
    end
end    
set(0, 'DefaultFigureVisible', 'on');

% Calculate mean and sigma, do plots in terms of the design parameters (i.e., AR and Mach number)
for ii = 1:length(ar_straight_wing_uncertain_price)
    for jj = 1:length(mach_straight_wing_uncertain_price)
        plotsfolderName = 'straight_wing_uncertain_price_optimisation_uq'; 
        subfolder_plotsfolderName = sprintf('ar_%u_mach_%u', ii, jj); % each 'case' refers to one fixed combination of design variables
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        addpath(fullPath);
        surrogate_straight_wing_uncertain_price = load(sprintf('surrogate_total_operating_cost_ar_case_%u_mach_case_%u.mat', ii, jj));
        surrogate_straight_wing_uncertain_price = surrogate_straight_wing_uncertain_price.elementToSave;

        N_MC_test = 10^6;
        inputs_for_mean_sigma_test_straight_wing_uncertain_price = uq_getSample(myInput_straight_wing_uncertain_price, N_MC_test, 'MC');      % generate N_MC Monte Carlo points in the uncertain variables' space
        outputs_for_mean_sigma_test_straight_wing_uncertain_price = uq_evalModel(surrogate_straight_wing_uncertain_price, inputs_for_mean_sigma_test_straight_wing_uncertain_price);   % evaluate the surrogates to get QIs data
        mean_surrogate_straight_wing_uncertain_price(ii, jj) = mean(outputs_for_mean_sigma_test_straight_wing_uncertain_price, 1);
        std_surrogate_straight_wing_uncertain_price(ii, jj) = std(outputs_for_mean_sigma_test_straight_wing_uncertain_price, 1);
    end
end 

% plot
[x_straight_wing_uncertain_price, y_straight_wing_uncertain_price] = meshgrid(linspace(0.45, 0.69, 10), linspace(11, 23, 10)); % x: Mach number, y: AR
% Finer grid for interpolation
[xq_straight_wing_uncertain_price, yq_straight_wing_uncertain_price] = meshgrid(linspace(0.45, 0.69, 100), linspace(11, 23, 100));
% Interpolate for sigma using bicubic interpolation
Std_straight_wing_uncertain_price = interp2(x_straight_wing_uncertain_price, y_straight_wing_uncertain_price, std_surrogate_straight_wing_uncertain_price, xq_straight_wing_uncertain_price, yq_straight_wing_uncertain_price, 'cubic');

fig = figure();
imagesc([0.45 0.69], [11 23], Std_straight_wing_uncertain_price);
set(gca, 'YDir', 'normal');  % Ensures y-axis is not flipped
axis tight;                  % Fits the image to data
colorbar;
title(sprintf('Sigma estimation (%s): Total operating cost', surrogate_straight_wing_uncertain_price.Options.MetaType)); 
xlabel('Mach number'); 
ylabel('Aspect ratio'); 
hold on;
% Overlay contour lines and labels
[contourMatrix, contourHandle] = contour(xq_straight_wing_uncertain_price, yq_straight_wing_uncertain_price, Std_straight_wing_uncertain_price, 30, 'LineColor', 'k');
clabel(contourMatrix, contourHandle, 'FontSize', 8, 'Color', 'k');
saveas(fig, fullfile(plotsfolderName, 'Sigma_cost_for_ar_and_mach_with_straight_wing_uncertain_price.png'))
saveas(fig, fullfile(plotsfolderName, 'Sigma_cost_for_ar_and_mach_with_straight_wing_uncertain_price.fig'))


% Interpolate for mean using bicubic interpolation
Mean_straight_wing_uncertain_price = interp2(x_straight_wing_uncertain_price, y_straight_wing_uncertain_price, mean_surrogate_straight_wing_uncertain_price, xq_straight_wing_uncertain_price, yq_straight_wing_uncertain_price, 'cubic');

fig = figure();
imagesc([0.45 0.69], [11 23], Mean_straight_wing_uncertain_price);
set(gca, 'YDir', 'normal');  % Ensures y-axis is not flipped
axis tight;                  % Fits the image to data
colorbar;
title(sprintf('Mean estimation (%s): Total operating cost', surrogate_straight_wing_uncertain_price.Options.MetaType));
xlabel('Mach number');
ylabel('Aspect ratio');
hold on;
% Overlay contour lines and labels
[contourMatrix, contourHandle] = contour(xq_straight_wing_uncertain_price, yq_straight_wing_uncertain_price, Mean_straight_wing_uncertain_price, 30, 'LineColor', 'k');
clabel(contourMatrix, contourHandle, 'FontSize', 8, 'Color', 'k');
saveas(fig, fullfile(plotsfolderName, 'Mean_cost_for_ar_and_mach_with_straight_wing_uncertain_price.png'))
saveas(fig, fullfile(plotsfolderName, 'Mean_cost_for_ar_and_mach_with_straight_wing_uncertain_price.fig'))

F_mean = griddedInterpolant(x_straight_wing_uncertain_price', y_straight_wing_uncertain_price', mean_surrogate_straight_wing_uncertain_price', 'cubic');  
F_sigma = griddedInterpolant(x_straight_wing_uncertain_price', y_straight_wing_uncertain_price', std_surrogate_straight_wing_uncertain_price', 'cubic');  

% robust optimisation (minimise mean and sigma) using the interpolant surrogates
straight_nvars_uncertain_price = 2;              % Number of design variables
straight_lb_uncertain_price = [11, 0.45];        % Lower bounds
straight_ub_uncertain_price = [23, 0.69];        % Upper bounds
straight_objFun_uncertain_price = @(x) myObjectives_robust(x, F_mean, F_sigma);

straight_options_uncertain_price = optimoptions('gamultiobj', 'Display', 'iter', 'PlotFcn', @gaplotpareto);     % Genetic Algorithm for multi-objective optimisation
[straight_wing_pareto_uncertain_price, straight_fval_uncertain_price] = gamultiobj(straight_objFun_uncertain_price, straight_nvars_uncertain_price, [], [], [], [], straight_lb_uncertain_price, straight_ub_uncertain_price, straight_options_uncertain_price);
straight_pareto_uncertain_price_size = size(straight_wing_pareto_uncertain_price, 1);

for ii=1:straight_pareto_uncertain_price_size
    try
        % Description of the physical model for UQLab
        ModelOpts_straight_wing_uncertain_price.mFile = 'physical_model_straight_wing_uncertain_fuel_price';
        ModelOpts_straight_wing_uncertain_price.isVectorized = false;
        ModelOpts_straight_wing_uncertain_price.Parameters = [straight_wing_pareto_uncertain_price(ii, 1) straight_wing_pareto_uncertain_price(ii, 2)];
        myModel_straight_wing_uncertain_price = uq_createModel(ModelOpts_straight_wing_uncertain_price);
    
        N_train = 5;                                     % initial training set size (the set will be updated until the surrogate validation error is low enough)
        MetaOpts_straight_wing_uncertain_price.Type = 'Metamodel';             % 'metamodel': another word for 'surrogate'
        % MetaOpts_straight_wing_uncertain_price.MetaType = 'Kriging';      
        MetaOpts_straight_wing_uncertain_price.MetaType = 'PCE';
        MetaOpts_straight_wing_uncertain_price.Input = myInput_straight_wing_uncertain_price;        % probability distribution for the uncertain variables
        MetaOpts_straight_wing_uncertain_price.FullModel = myModel_straight_wing_uncertain_price;    % the physical model as a UQLab object
        MetaOpts_straight_wing_uncertain_price.ExpDesign.NSamples = N_train;   % 'experimental design' (ExpDesign): another word for 'training set'
        if strcmp(MetaOpts_straight_wing_uncertain_price.MetaType, 'Kriging')
            MetaOpts_straight_wing_uncertain_price.ExpDesign.Sampling = 'User';
        end
    
        flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
        seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
        N_train_increment = 5;          % we will increment the training set size until we reach convergence
        N_train_max = 5;                % training budget (i.e., maximum number of training points allowed)
        % run a test to check if surrogates are actually faster than classical MC for mean and sigma estimation  
        % recommended only for cheap models (to find the true mean and sigma, we need a large MC with the physical model) 
        flag_test_for_mean_and_sigma = false;
    
        % Plots generator for parameter sweeps for the uncertain variables
        inputs_name_straight_wing_uncertain_price = ["Fuel price", "Oil price"];  % list of the names of the uncertain variables
        outputs_name_straight_wing_uncertain_price = ["Total operating cost"];    % list of the names of the QIs
        N_outputs_straight_wing_uncertain_price = length(outputs_name_straight_wing_uncertain_price);           % number of quantities of interest (QIs)
        descriptive_title_for_plots_straight_wing_uncertain_price = sprintf('%s surrogate (AR:%.2e, Mach:%.2e)', MetaOpts_straight_wing_uncertain_price.MetaType, straight_wing_pareto_uncertain_price(ii, 1), straight_wing_pareto_uncertain_price(ii, 2));
        N_eval = 100;                                                        % number of discretisation points for each uncertain variable (for plots)
        plotsfolderName = 'straight_wing_uncertain_price_optimisation_uq'; 
        subfolder_plotsfolderName = sprintf('Pareto_point_number_%u', ii); 
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        mkdir(fullPath);
        mkdir(fullPath, 'plots_uq');
        true_model_pareto_straight_wing_uncertain_price{ii, 1} =  surrogates_uq(MetaOpts_straight_wing_uncertain_price, N_outputs_straight_wing_uncertain_price, N_train_increment, N_train_max, flag_parfor, seed, fullPath, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
        elementToSave = true_model_pareto_straight_wing_uncertain_price{ii, 1}; 
        save(fullfile(fullPath, sprintf('true_model_total_operating_cost_pareto_point_number_%u.mat', ii)), 'elementToSave'); % save the surrogate
        uncertain_variables_exploration(elementToSave, inputs_name_straight_wing_uncertain_price, outputs_name_straight_wing_uncertain_price, descriptive_title_for_plots_straight_wing_uncertain_price, N_eval, seed, fullPath); % plots generator using the surrogates 

        fileID = fopen(fullfile(fullPath, 'readme.txt'), 'w');
        fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables (the deterministic variables are fixed).\n\n');
        fprintf(fileID, 'Legend:\n');
        N_outputs_straight_wing_uncertain_price = length(outputs_name_straight_wing_uncertain_price);             % number of quantities of interest (QIs)
        N_variables_straight_wing_uncertain_price = length(inputs_name_straight_wing_uncertain_price);            % number of uncertain variables
        for kk = 1:N_outputs_straight_wing_uncertain_price
            fprintf(fileID, 'QI %d: %s\n', kk, outputs_name_straight_wing_uncertain_price(kk));
        end   
        for kk = 1:N_variables_straight_wing_uncertain_price
            fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name_straight_wing_uncertain_price(kk));
        end    
        fprintf(fileID, 'Deterministic variable 1: Aspect ratio; Pareto point number: %d; Value: %.5f\n', ii, straight_wing_pareto_uncertain_price(ii, 1));
        fprintf(fileID, 'Deterministic variable 2: Mach number; Pareto point number: %d; Value: %.5f\n', ii, straight_wing_pareto_uncertain_price(ii, 2));
        fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots_straight_wing_uncertain_price);
        fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
        fclose(fileID);
        disp('Readme file for the surrogates has been created successfully.');
    catch ME
        fprintf('Error in sample %d: %s\n', ii, ME.message);
    end
end    

true_model_straight_output_pareto_uncertain_price = nan(straight_pareto_uncertain_price_size, 2);
% Calculate mean and sigma at the Pareto points using the surrogates trained on the physical model (rather than the fast cubic interpolation method above)
for ii = 1:straight_pareto_uncertain_price_size
    try
        plotsfolderName = 'straight_wing_uncertain_price_optimisation_uq'; 
        subfolder_plotsfolderName = sprintf('Pareto_point_number_%u', ii); 
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        addpath(fullPath);
        surrogate_straight_wing_uncertain_price = load(sprintf('true_model_total_operating_cost_pareto_point_number_%u.mat', ii));
        surrogate_straight_wing_uncertain_price = surrogate_straight_wing_uncertain_price.elementToSave;

        N_MC_test = 10^6;
        inputs_for_mean_sigma_test_straight_wing_uncertain_price = uq_getSample(myInput_straight_wing_uncertain_price, N_MC_test, 'MC');      % generate N_MC Monte Carlo points in the uncertain variables' space
        outputs_for_mean_sigma_test_straight_wing_uncertain_price = uq_evalModel(surrogate_straight_wing_uncertain_price, inputs_for_mean_sigma_test_straight_wing_uncertain_price);   % evaluate the surrogates to get QIs data
        true_model_straight_output_pareto_uncertain_price(ii, 1) = mean(outputs_for_mean_sigma_test_straight_wing_uncertain_price, 1);
        true_model_straight_output_pareto_uncertain_price(ii, 2) = std(outputs_for_mean_sigma_test_straight_wing_uncertain_price, 1);
    catch ME
        fprintf('Error in sample %d: %s\n', ii, ME.message);
    end
end 

straight_wing_pareto_uncertain_price = straight_wing_pareto_uncertain_price(~any(isnan(true_model_straight_output_pareto_uncertain_price), 2), :);                           
true_model_straight_output_pareto_uncertain_price = true_model_straight_output_pareto_uncertain_price(~any(isnan(true_model_straight_output_pareto_uncertain_price), 2), :); 

for ii = 1:size(straight_wing_pareto_uncertain_price, 1)
    F_mean_tmp = F_mean(straight_wing_pareto_uncertain_price(ii, 2), straight_wing_pareto_uncertain_price(ii, 1));
    F_sigma_tmp = F_sigma(straight_wing_pareto_uncertain_price(ii, 2), straight_wing_pareto_uncertain_price(ii, 1));
    surrogate_output_straight_pareto_uncertain_price_interp(ii, :) = [F_mean_tmp, F_sigma_tmp];
    relative_interp_surrogate_error_straight_uncertain_price_mean(ii) = abs(surrogate_output_straight_pareto_uncertain_price_interp(ii, 1)/true_model_straight_output_pareto_uncertain_price(ii, 1)-1);
    relative_interp_surrogate_error_straight_uncertain_price_sigma(ii) = abs(surrogate_output_straight_pareto_uncertain_price_interp(ii, 2)/true_model_straight_output_pareto_uncertain_price(ii, 2)-1);
end
% 
save(fullfile(plotsfolderName, 'opt_for_mean_and_sigma_with_straight_wing_uncertain_price.mat'), 'straight_wing_pareto_uncertain_price', 'true_model_straight_output_pareto_uncertain_price', 'relative_interp_surrogate_error_straight_uncertain_price_mean', 'relative_interp_surrogate_error_straight_uncertain_price_sigma')
% 
true_model_straight_sorted_points = sortrows(true_model_straight_output_pareto_uncertain_price, 1);
surrogate_model_straight_pareto_uncertain_price_sorted_points = sortrows(surrogate_output_straight_pareto_uncertain_price_interp, 1);

fig = figure();
plot(true_model_straight_sorted_points(:,1), true_model_straight_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Physical Model');
hold on 
plot(surrogate_model_straight_pareto_uncertain_price_sorted_points(:,1), surrogate_model_straight_pareto_uncertain_price_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Surrogate Model');
xlabel('Total operating cost (mean)');
ylabel('Total operating cost (sigma)');
title('Pareto (Genetic Algorithm; uncertain fuel price)');
grid on;
legend('Location', 'best');
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_mean_and_sigma_with_straight_wing_uncertain_price.png'))
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_mean_and_sigma_with_straight_wing_uncertain_price.fig'))

%% 9. Robust optimisation (swept wing, uncertain fuel price)

% Robust Optimisation - Description of the uncertain variables for UQLab
InputOpts_custom_swept_wing_uncertain_price.Marginals(1).Type = 'Uniform';
InputOpts_custom_swept_wing_uncertain_price.Marginals(1).Parameters = [0.9*0.64995, 1.1*0.64995]; % (Fuel price) lower and upper uncertainty bound
InputOpts_custom_swept_wing_uncertain_price.Marginals(2).Type = 'Uniform';
InputOpts_custom_swept_wing_uncertain_price.Marginals(2).Parameters = [0.9*30.0, 1.1*30.0]; % (Oil price) lower and upper uncertainty bound
% The uncertain variables are inputs for physical maps that output QIs
myInput_custom_swept_wing_uncertain_price = uq_createInput(InputOpts_custom_swept_wing_uncertain_price); 

set(0, 'DefaultFigureVisible', 'off');

sa_custom_swept_wing_uncertain_price = linspace(0, 45, 10);  
mach_custom_swept_wing_uncertain_price = linspace(0.45, 0.9, 10);
surrogates_custom_swept_wing_uncertain_price = cell(length(sa_custom_swept_wing_uncertain_price), length(mach_custom_swept_wing_uncertain_price));

for ii = 1:length(sa_custom_swept_wing_uncertain_price)
    for jj = 1:length(mach_custom_swept_wing_uncertain_price)
        % Description of the physical model for UQLab
        ModelOpts_custom_swept_wing_uncertain_price.mFile = 'physical_model_indep_sweep_uncertain_fuel_price';
        ModelOpts_custom_swept_wing_uncertain_price.isVectorized = false;
        ModelOpts_custom_swept_wing_uncertain_price.Parameters = [sa_custom_swept_wing_uncertain_price(ii) mach_custom_swept_wing_uncertain_price(jj)];
        myModel_custom_swept_wing_uncertain_price = uq_createModel(ModelOpts_custom_swept_wing_uncertain_price);

        N_train = 5;                                     % initial training set size (the set will be updated until the surrogate validation error is low enough)
        MetaOpts_custom_swept_wing_uncertain_price.Type = 'Metamodel';             % 'metamodel': another word for 'surrogate'
        % MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'Kriging';      
        MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'PCE';
        MetaOpts_custom_swept_wing_uncertain_price.Input = myInput_custom_swept_wing_uncertain_price;        % probability distribution for the uncertain variables
        MetaOpts_custom_swept_wing_uncertain_price.FullModel = myModel_custom_swept_wing_uncertain_price;    % the physical model as a UQLab object
        MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.NSamples = N_train;   % 'experimental design' (ExpDesign): another word for 'training set'
        if strcmp(MetaOpts_custom_swept_wing_uncertain_price.MetaType, 'Kriging')
            MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.Sampling = 'User';
        end

        flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
        seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
        N_train_increment = 5;          % we will increment the training set size until we reach convergence
        N_train_max = 5;                % training budget (i.e., maximum number of training points allowed)
        % run a test to check if surrogates are actually faster than classical MC for mean and sigma estimation  
        % recommended only for cheap models (to find the true mean and sigma, we need a large MC with the physical model) 
        flag_test_for_mean_and_sigma = false;

        % Plots generator for parameter sweeps for the uncertain variables
        inputs_name_custom_swept_wing_uncertain_price = ["Fuel price", "Oil price"];  % list of the names of the uncertain variables
        outputs_name_custom_swept_wing_uncertain_price = ["Total operating cost"];    % list of the names of the QIs
        N_outputs_custom_swept_wing_uncertain_price = length(outputs_name_custom_swept_wing_uncertain_price);           % number of quantities of interest (QIs)
        descriptive_title_for_plots_custom_swept_wing_uncertain_price = sprintf('%s surrogate (Sweep angle:%.2e, Mach:%.2e)', MetaOpts_custom_swept_wing_uncertain_price.MetaType, sa_custom_swept_wing_uncertain_price(ii), mach_custom_swept_wing_uncertain_price(jj));
        N_eval = 100;                                                        % number of discretisation points for each uncertain variable (for plots)
        plotsfolderName = 'custom_swept_wing_uncertain_price_optimisation_uq'; 
        subfolder_plotsfolderName = sprintf('sa_%u_mach_%u', ii, jj); % each 'case' refers to one fixed combination of design variables
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        mkdir(fullPath);
        mkdir(fullPath, 'plots_uq');
        try
            surrogates_custom_swept_wing_uncertain_price{ii, jj} =  surrogates_uq(MetaOpts_custom_swept_wing_uncertain_price, N_outputs_custom_swept_wing_uncertain_price, N_train_increment, N_train_max, flag_parfor, seed, fullPath, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
            elementToSave = surrogates_custom_swept_wing_uncertain_price{ii, jj}; 
            save(fullfile(fullPath, sprintf('surrogate_total_operating_cost_sa_case_%u_mach_case_%u.mat', ii, jj)), 'elementToSave'); % save the surrogate
            uncertain_variables_exploration(elementToSave, inputs_name_custom_swept_wing_uncertain_price, outputs_name_custom_swept_wing_uncertain_price, descriptive_title_for_plots_custom_swept_wing_uncertain_price, N_eval, seed, fullPath); % plots generator using the surrogates 
            % add readme to explain each 'case' (i.e., each fixed combination (ii, jj) of design variables)
            fileID = fopen(fullfile(fullPath, 'readme.txt'), 'w');
            fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables (the deterministic variables are fixed).\n\n');
            fprintf(fileID, 'Legend:\n');
            N_outputs_custom_swept_wing_uncertain_price = length(outputs_name_custom_swept_wing_uncertain_price);             % number of quantities of interest (QIs)
            N_variables_custom_swept_wing_uncertain_price = length(inputs_name_custom_swept_wing_uncertain_price);            % number of uncertain variables
            for kk = 1:N_outputs_custom_swept_wing_uncertain_price
                fprintf(fileID, 'QI %d: %s\n', kk, outputs_name_custom_swept_wing_uncertain_price(kk));
            end   
            for kk = 1:N_variables_custom_swept_wing_uncertain_price
                fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name_custom_swept_wing_uncertain_price(kk));
            end    
            fprintf(fileID, 'Deterministic variable 1: Sweep angle; Case: %d out of %d; Value: %.5f\n', ii, length(sa_custom_swept_wing_uncertain_price), sa_custom_swept_wing_uncertain_price(ii));
            fprintf(fileID, 'Deterministic variable 2: Mach number; Case: %d out of %d; Value: %.5f\n', jj, length(mach_custom_swept_wing_uncertain_price), mach_custom_swept_wing_uncertain_price(jj));
            fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots_custom_swept_wing_uncertain_price);
            fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
            fclose(fileID);
            disp('Readme file for the surrogates has been created successfully.');
        catch ME
            fprintf('Error in sample (%d, %d): %s\n', ii, jj, ME.message);
        end
    end
end    
set(0, 'DefaultFigureVisible', 'on');

% Calculate mean and sigma, do plots in terms of the design parameters (i.e., Sweep angle and Mach number); some values removed due to physical model code failures
mean_surrogate_custom_swept_wing_uncertain_price = nan(length(sa_custom_swept_wing_uncertain_price)-1, length(mach_custom_swept_wing_uncertain_price)-1);
std_surrogate_custom_swept_wing_uncertain_price = nan(length(sa_custom_swept_wing_uncertain_price)-1, length(mach_custom_swept_wing_uncertain_price)-1);
for ii = 1:length(sa_custom_swept_wing_uncertain_price)-1
    for jj = 2:length(mach_custom_swept_wing_uncertain_price)
        try
            plotsfolderName = 'custom_swept_wing_uncertain_price_optimisation_uq'; 
            subfolder_plotsfolderName = sprintf('sa_%u_mach_%u', ii, jj); % each 'case' refers to one fixed combination of design variables
            fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
            addpath(fullPath);
            surrogate_custom_swept_wing_uncertain_price = load(sprintf('surrogate_total_operating_cost_sa_case_%u_mach_case_%u.mat', ii, jj));
            surrogate_custom_swept_wing_uncertain_price = surrogate_custom_swept_wing_uncertain_price.elementToSave;

            N_MC_test = 10^6;
            inputs_for_mean_sigma_test_custom_swept_wing_uncertain_price = uq_getSample(myInput_custom_swept_wing_uncertain_price, N_MC_test, 'MC');      % generate N_MC Monte Carlo points in the uncertain variables' space
            outputs_for_mean_sigma_test_custom_swept_wing_uncertain_price = uq_evalModel(surrogate_custom_swept_wing_uncertain_price, inputs_for_mean_sigma_test_custom_swept_wing_uncertain_price);   % evaluate the surrogates to get QIs data
            mean_surrogate_custom_swept_wing_uncertain_price(ii, jj-1) = mean(outputs_for_mean_sigma_test_custom_swept_wing_uncertain_price, 1);
            std_surrogate_custom_swept_wing_uncertain_price(ii, jj-1) = std(outputs_for_mean_sigma_test_custom_swept_wing_uncertain_price, 1);
        catch ME
            fprintf('Error in sample (%d, %d): %s\n', ii, jj, ME.message);
        end
    end
end 

% plot
[x_custom_swept_wing_uncertain_price, y_custom_swept_wing_uncertain_price] = meshgrid(linspace(0.5, 0.9, 9), linspace(0, 40, 9)); % x: Mach number, y: Sweep angle
% Finer grid for interpolation
[xq_custom_swept_wing_uncertain_price, yq_custom_swept_wing_uncertain_price] = meshgrid(linspace(0.5, 0.9, 100), linspace(0, 40, 100));
% Interpolate for sigma using bicubic interpolation
Std_custom_swept_wing_uncertain_price = interp2(x_custom_swept_wing_uncertain_price, y_custom_swept_wing_uncertain_price, std_surrogate_custom_swept_wing_uncertain_price, xq_custom_swept_wing_uncertain_price, yq_custom_swept_wing_uncertain_price, 'cubic');

fig = figure();
imagesc([0.5 0.9], [0 40], Std_custom_swept_wing_uncertain_price);
set(gca, 'YDir', 'normal');  % Ensures y-axis is not flipped
axis tight;                  % Fits the image to data
colorbar;
title(sprintf('Sigma estimation (%s): Total operating cost', surrogate_custom_swept_wing_uncertain_price.Options.MetaType)); 
xlabel('Mach number'); 
ylabel('Sweep angle'); 
hold on;
% Overlay contour lines and labels
[contourMatrix, contourHandle] = contour(xq_custom_swept_wing_uncertain_price, yq_custom_swept_wing_uncertain_price, Std_custom_swept_wing_uncertain_price, 18, 'LineColor', 'k');
clabel(contourMatrix, contourHandle, 'FontSize', 8, 'Color', 'k');
saveas(fig, fullfile(plotsfolderName, 'Sigma_cost_for_sa_and_mach_with_custom_swept_wing_uncertain_price.png'))
saveas(fig, fullfile(plotsfolderName, 'Sigma_cost_for_sa_and_mach_with_custom_swept_wing_uncertain_price.fig'))


% Interpolate for mean using bicubic interpolation
Mean_custom_swept_wing_uncertain_price = interp2(x_custom_swept_wing_uncertain_price, y_custom_swept_wing_uncertain_price, mean_surrogate_custom_swept_wing_uncertain_price, xq_custom_swept_wing_uncertain_price, yq_custom_swept_wing_uncertain_price, 'cubic');

fig = figure();
imagesc([0.5 0.9], [0 40], Mean_custom_swept_wing_uncertain_price);
set(gca, 'YDir', 'normal');  % Ensures y-axis is not flipped
axis tight;                  % Fits the image to data
colorbar;
title(sprintf('Mean estimation (%s): Total operating cost', surrogate_custom_swept_wing_uncertain_price.Options.MetaType));
xlabel('Mach number');
ylabel('Sweep angle');
hold on;
% Overlay contour lines and labels
[contourMatrix, contourHandle] = contour(xq_custom_swept_wing_uncertain_price, yq_custom_swept_wing_uncertain_price, Mean_custom_swept_wing_uncertain_price, 18, 'LineColor', 'k');
clabel(contourMatrix, contourHandle, 'FontSize', 8, 'Color', 'k');
saveas(fig, fullfile(plotsfolderName, 'Mean_cost_for_sa_and_mach_with_custom_swept_wing_uncertain_price.png'))
saveas(fig, fullfile(plotsfolderName, 'Mean_cost_for_sa_and_mach_with_custom_swept_wing_uncertain_price.fig'))

F_mean = griddedInterpolant(x_custom_swept_wing_uncertain_price', y_custom_swept_wing_uncertain_price', mean_surrogate_custom_swept_wing_uncertain_price', 'cubic');  
F_sigma = griddedInterpolant(x_custom_swept_wing_uncertain_price', y_custom_swept_wing_uncertain_price', std_surrogate_custom_swept_wing_uncertain_price', 'cubic');  

% robust optimisation (minimise mean and sigma) using the interpolant surrogates
custom_swept_nvars_uncertain_price = 2;            % Number of design variables
custom_swept_lb_uncertain_price = [0, 0.5];        % Lower bounds
custom_swept_ub_uncertain_price = [40, 0.9];       % Upper bounds
custom_swept_objFun_uncertain_price = @(x) myObjectives_robust(x, F_mean, F_sigma);

custom_swept_options_uncertain_price = optimoptions('gamultiobj', 'Display', 'iter', 'PlotFcn', @gaplotpareto);     % Genetic Algorithm for multi-objective optimisation
[custom_swept_wing_pareto_uncertain_price, custom_swept_fval_uncertain_price] = gamultiobj(custom_swept_objFun_uncertain_price, custom_swept_nvars_uncertain_price, [], [], [], [], custom_swept_lb_uncertain_price, custom_swept_ub_uncertain_price, custom_swept_options_uncertain_price);
custom_swept_pareto_uncertain_price_size = size(custom_swept_wing_pareto_uncertain_price, 1);

for ii=1:custom_swept_pareto_uncertain_price_size
    try
        % Description of the physical model for UQLab
        ModelOpts_custom_swept_wing_uncertain_price.mFile = 'physical_model_indep_sweep_uncertain_fuel_price';
        ModelOpts_custom_swept_wing_uncertain_price.isVectorized = false;
        ModelOpts_custom_swept_wing_uncertain_price.Parameters = [custom_swept_wing_pareto_uncertain_price(ii, 1) custom_swept_wing_pareto_uncertain_price(ii, 2)];
        myModel_custom_swept_wing_uncertain_price = uq_createModel(ModelOpts_custom_swept_wing_uncertain_price);

        N_train = 5;                                     % initial training set size (the set will be updated until the surrogate validation error is low enough)
        MetaOpts_custom_swept_wing_uncertain_price.Type = 'Metamodel';             % 'metamodel': another word for 'surrogate'
        % MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'Kriging';      
        MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'PCE';
        MetaOpts_custom_swept_wing_uncertain_price.Input = myInput_custom_swept_wing_uncertain_price;        % probability distribution for the uncertain variables
        MetaOpts_custom_swept_wing_uncertain_price.FullModel = myModel_custom_swept_wing_uncertain_price;    % the physical model as a UQLab object
        MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.NSamples = N_train;   % 'experimental design' (ExpDesign): another word for 'training set'
        if strcmp(MetaOpts_custom_swept_wing_uncertain_price.MetaType, 'Kriging')
            MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.Sampling = 'User';
        end

        flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
        seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
        N_train_increment = 5;          % we will increment the training set size until we reach convergence
        N_train_max = 5;                % training budget (i.e., maximum number of training points allowed)
        % run a test to check if surrogates are actually faster than classical MC for mean and sigma estimation  
        % recommended only for cheap models (to find the true mean and sigma, we need a large MC with the physical model) 
        flag_test_for_mean_and_sigma = false;

        % Plots generator for parameter sweeps for the uncertain variables
        inputs_name_custom_swept_wing_uncertain_price = ["Fuel price", "Oil price"];  % list of the names of the uncertain variables
        outputs_name_custom_swept_wing_uncertain_price = ["Total operating cost"];    % list of the names of the QIs
        N_outputs_custom_swept_wing_uncertain_price = length(outputs_name_custom_swept_wing_uncertain_price);           % number of quantities of interest (QIs)
        descriptive_title_for_plots_custom_swept_wing_uncertain_price = sprintf('%s surrogate (Sweep angle:%.2e, Mach:%.2e)', MetaOpts_custom_swept_wing_uncertain_price.MetaType, custom_swept_wing_pareto_uncertain_price(ii, 1), custom_swept_wing_pareto_uncertain_price(ii, 2));
        N_eval = 100;                                                        % number of discretisation points for each uncertain variable (for plots)
        plotsfolderName = 'custom_swept_wing_uncertain_price_optimisation_uq'; 
        subfolder_plotsfolderName = sprintf('Pareto_point_number_%u', ii); 
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        mkdir(fullPath);
        mkdir(fullPath, 'plots_uq');
        true_model_pareto_custom_swept_wing_uncertain_price{ii, 1} =  surrogates_uq(MetaOpts_custom_swept_wing_uncertain_price, N_outputs_custom_swept_wing_uncertain_price, N_train_increment, N_train_max, flag_parfor, seed, fullPath, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
        elementToSave = true_model_pareto_custom_swept_wing_uncertain_price{ii, 1}; 
        save(fullfile(fullPath, sprintf('true_model_total_operating_cost_pareto_point_number_%u.mat', ii)), 'elementToSave'); % save the surrogate
        uncertain_variables_exploration(elementToSave, inputs_name_custom_swept_wing_uncertain_price, outputs_name_custom_swept_wing_uncertain_price, descriptive_title_for_plots_custom_swept_wing_uncertain_price, N_eval, seed, fullPath); % plots generator using the surrogates 

        fileID = fopen(fullfile(fullPath, 'readme.txt'), 'w');
        fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables (the deterministic variables are fixed).\n\n');
        fprintf(fileID, 'Legend:\n');
        N_outputs_custom_swept_wing_uncertain_price = length(outputs_name_custom_swept_wing_uncertain_price);             % number of quantities of interest (QIs)
        N_variables_custom_swept_wing_uncertain_price = length(inputs_name_custom_swept_wing_uncertain_price);            % number of uncertain variables
        for kk = 1:N_outputs_custom_swept_wing_uncertain_price
            fprintf(fileID, 'QI %d: %s\n', kk, outputs_name_custom_swept_wing_uncertain_price(kk));
        end   
        for kk = 1:N_variables_custom_swept_wing_uncertain_price
            fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name_custom_swept_wing_uncertain_price(kk));
        end    
        fprintf(fileID, 'Deterministic variable 1: Sweep angle; Pareto point number: %d; Value: %.5f\n', ii, custom_swept_wing_pareto_uncertain_price(ii, 1));
        fprintf(fileID, 'Deterministic variable 2: Mach number; Pareto point number: %d; Value: %.5f\n', ii, custom_swept_wing_pareto_uncertain_price(ii, 2));
        fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots_custom_swept_wing_uncertain_price);
        fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
        fclose(fileID);
        disp('Readme file for the surrogates has been created successfully.');
    catch ME
        fprintf('Error in sample %d: %s\n', ii, ME.message);
    end
end    

true_model_custom_swept_output_pareto_uncertain_price = nan(custom_swept_pareto_uncertain_price_size, 2);
% Calculate mean and sigma at the Pareto points using the surrogates trained on the physical model (rather than the fast cubic interpolation method above)
for ii = 1:custom_swept_pareto_uncertain_price_size
    try
        plotsfolderName = 'custom_swept_wing_uncertain_price_optimisation_uq'; 
        subfolder_plotsfolderName = sprintf('Pareto_point_number_%u', ii); 
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        addpath(fullPath);
        surrogate_custom_swept_wing_uncertain_price = load(sprintf('true_model_total_operating_cost_pareto_point_number_%u.mat', ii));
        surrogate_custom_swept_wing_uncertain_price = surrogate_custom_swept_wing_uncertain_price.elementToSave;

        N_MC_test = 10^6;
        inputs_for_mean_sigma_test_custom_swept_wing_uncertain_price = uq_getSample(myInput_custom_swept_wing_uncertain_price, N_MC_test, 'MC');      % generate N_MC Monte Carlo points in the uncertain variables' space
        outputs_for_mean_sigma_test_custom_swept_wing_uncertain_price = uq_evalModel(surrogate_custom_swept_wing_uncertain_price, inputs_for_mean_sigma_test_custom_swept_wing_uncertain_price);   % evaluate the surrogates to get QIs data
        true_model_custom_swept_output_pareto_uncertain_price(ii, 1) = mean(outputs_for_mean_sigma_test_custom_swept_wing_uncertain_price, 1);
        true_model_custom_swept_output_pareto_uncertain_price(ii, 2) = std(outputs_for_mean_sigma_test_custom_swept_wing_uncertain_price, 1);
    catch ME
        fprintf('Error in sample %d: %s\n', ii, ME.message);
    end
end 

custom_swept_wing_pareto_uncertain_price = custom_swept_wing_pareto_uncertain_price(~any(isnan(true_model_custom_swept_output_pareto_uncertain_price), 2), :);                           
true_model_custom_swept_output_pareto_uncertain_price = true_model_custom_swept_output_pareto_uncertain_price(~any(isnan(true_model_custom_swept_output_pareto_uncertain_price), 2), :); 

for ii = 1:size(custom_swept_wing_pareto_uncertain_price, 1)
    F_mean_tmp = F_mean(custom_swept_wing_pareto_uncertain_price(ii, 2), custom_swept_wing_pareto_uncertain_price(ii, 1));
    F_sigma_tmp = F_sigma(custom_swept_wing_pareto_uncertain_price(ii, 2), custom_swept_wing_pareto_uncertain_price(ii, 1));
    surrogate_output_custom_swept_pareto_uncertain_price_interp(ii, :) = [F_mean_tmp, F_sigma_tmp];
    relative_interp_error_custom_swept_uncertain_price_mean(ii) = abs(surrogate_output_custom_swept_pareto_uncertain_price_interp(ii, 1)/true_model_custom_swept_output_pareto_uncertain_price(ii, 1)-1);
    relative_interp_error_custom_swept_uncertain_price_sigma(ii) = abs(surrogate_output_custom_swept_pareto_uncertain_price_interp(ii, 2)/true_model_custom_swept_output_pareto_uncertain_price(ii, 2)-1);
end
% 
save(fullfile(plotsfolderName, 'opt_for_mean_and_sigma_with_custom_swept_wing_uncertain_price.mat'), 'custom_swept_wing_pareto_uncertain_price', 'true_model_custom_swept_output_pareto_uncertain_price', 'relative_interp_error_custom_swept_uncertain_price_mean', 'relative_interp_error_custom_swept_uncertain_price_sigma')
% 
true_model_custom_swept_sorted_points = sortrows(true_model_custom_swept_output_pareto_uncertain_price, 1);
surrogate_custom_swept_pareto_uncertain_price_sorted_points = sortrows(surrogate_output_custom_swept_pareto_uncertain_price_interp, 1);

fig = figure();
plot(true_model_custom_swept_sorted_points(:,1), true_model_custom_swept_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Physical Model');
hold on 
plot(surrogate_custom_swept_pareto_uncertain_price_sorted_points(:,1), surrogate_custom_swept_pareto_uncertain_price_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Surrogate Model');
xlabel('Total operating cost (mean)');
ylabel('Total operating cost (sigma)');
title('Pareto (Genetic Algorithm; uncertain fuel price)');
grid on;
legend('Location', 'best');
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_mean_and_sigma_with_custom_swept_wing_uncertain_price.png'))
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_mean_and_sigma_with_custom_swept_wing_uncertain_price.fig'))

%% 10. Robust optimisation (swept wing, uncertain fuel price) - increased grid resolution size

% Robust Optimisation - Description of the uncertain variables for UQLab
InputOpts_custom_swept_wing_uncertain_price.Marginals(1).Type = 'Uniform';
InputOpts_custom_swept_wing_uncertain_price.Marginals(1).Parameters = [0.9*0.64995, 1.1*0.64995]; % (Fuel price) lower and upper uncertainty bound
InputOpts_custom_swept_wing_uncertain_price.Marginals(2).Type = 'Uniform';
InputOpts_custom_swept_wing_uncertain_price.Marginals(2).Parameters = [0.9*30.0, 1.1*30.0]; % (Oil price) lower and upper uncertainty bound
% The uncertain variables are inputs for physical maps that output QIs
myInput_custom_swept_wing_uncertain_price = uq_createInput(InputOpts_custom_swept_wing_uncertain_price); 

set(0, 'DefaultFigureVisible', 'off');

sa_custom_swept_wing_uncertain_price = linspace(0, 40, 25);  
mach_custom_swept_wing_uncertain_price = linspace(0.5, 0.9, 25);
surrogates_custom_swept_wing_uncertain_price = cell(length(sa_custom_swept_wing_uncertain_price), length(mach_custom_swept_wing_uncertain_price));

for ii = 1:length(sa_custom_swept_wing_uncertain_price)
    for jj = 1:length(mach_custom_swept_wing_uncertain_price)
        % Description of the physical model for UQLab
        ModelOpts_custom_swept_wing_uncertain_price.mFile = 'physical_model_indep_sweep_uncertain_fuel_price';
        ModelOpts_custom_swept_wing_uncertain_price.isVectorized = false;
        ModelOpts_custom_swept_wing_uncertain_price.Parameters = [sa_custom_swept_wing_uncertain_price(ii) mach_custom_swept_wing_uncertain_price(jj)];
        myModel_custom_swept_wing_uncertain_price = uq_createModel(ModelOpts_custom_swept_wing_uncertain_price);

        N_train = 5;                                     % initial training set size (the set will be updated until the surrogate validation error is low enough)
        MetaOpts_custom_swept_wing_uncertain_price.Type = 'Metamodel';             % 'metamodel': another word for 'surrogate'
        % MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'Kriging';      
        MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'PCE';
        MetaOpts_custom_swept_wing_uncertain_price.Input = myInput_custom_swept_wing_uncertain_price;        % probability distribution for the uncertain variables
        MetaOpts_custom_swept_wing_uncertain_price.FullModel = myModel_custom_swept_wing_uncertain_price;    % the physical model as a UQLab object
        MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.NSamples = N_train;   % 'experimental design' (ExpDesign): another word for 'training set'
        if strcmp(MetaOpts_custom_swept_wing_uncertain_price.MetaType, 'Kriging')
            MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.Sampling = 'User';
        end

        flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
        seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
        N_train_increment = 5;          % we will increment the training set size until we reach convergence
        N_train_max = 5;                % training budget (i.e., maximum number of training points allowed)
        % run a test to check if surrogates are actually faster than classical MC for mean and sigma estimation  
        % recommended only for cheap models (to find the true mean and sigma, we need a large MC with the physical model) 
        flag_test_for_mean_and_sigma = false;

        % Plots generator for parameter sweeps for the uncertain variables
        inputs_name_custom_swept_wing_uncertain_price = ["Fuel price", "Oil price"];  % list of the names of the uncertain variables
        outputs_name_custom_swept_wing_uncertain_price = ["Total operating cost"];    % list of the names of the QIs
        N_outputs_custom_swept_wing_uncertain_price = length(outputs_name_custom_swept_wing_uncertain_price);           % number of quantities of interest (QIs)
        descriptive_title_for_plots_custom_swept_wing_uncertain_price = sprintf('%s surrogate (Sweep angle:%.2e, Mach:%.2e)', MetaOpts_custom_swept_wing_uncertain_price.MetaType, sa_custom_swept_wing_uncertain_price(ii), mach_custom_swept_wing_uncertain_price(jj));
        N_eval = 100;                                                        % number of discretisation points for each uncertain variable (for plots)
        plotsfolderName = 'custom_swept_wing_uncertain_price_optimisation_increased_grid_uq'; 
        subfolder_plotsfolderName = sprintf('sa_%u_mach_%u', ii, jj); % each 'case' refers to one fixed combination of design variables
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        mkdir(fullPath);
        mkdir(fullPath, 'plots_uq');
        try
            surrogates_custom_swept_wing_uncertain_price{ii, jj} =  surrogates_uq(MetaOpts_custom_swept_wing_uncertain_price, N_outputs_custom_swept_wing_uncertain_price, N_train_increment, N_train_max, flag_parfor, seed, fullPath, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
            elementToSave = surrogates_custom_swept_wing_uncertain_price{ii, jj}; 
            save(fullfile(fullPath, sprintf('surrogate_total_operating_cost_sa_case_%u_mach_case_%u.mat', ii, jj)), 'elementToSave'); % save the surrogate
            uncertain_variables_exploration(elementToSave, inputs_name_custom_swept_wing_uncertain_price, outputs_name_custom_swept_wing_uncertain_price, descriptive_title_for_plots_custom_swept_wing_uncertain_price, N_eval, seed, fullPath); % plots generator using the surrogates 
            % add readme to explain each 'case' (i.e., each fixed combination (ii, jj) of design variables)
            fileID = fopen(fullfile(fullPath, 'readme.txt'), 'w');
            fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables (the deterministic variables are fixed).\n\n');
            fprintf(fileID, 'Legend:\n');
            N_outputs_custom_swept_wing_uncertain_price = length(outputs_name_custom_swept_wing_uncertain_price);             % number of quantities of interest (QIs)
            N_variables_custom_swept_wing_uncertain_price = length(inputs_name_custom_swept_wing_uncertain_price);            % number of uncertain variables
            for kk = 1:N_outputs_custom_swept_wing_uncertain_price
                fprintf(fileID, 'QI %d: %s\n', kk, outputs_name_custom_swept_wing_uncertain_price(kk));
            end   
            for kk = 1:N_variables_custom_swept_wing_uncertain_price
                fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name_custom_swept_wing_uncertain_price(kk));
            end    
            fprintf(fileID, 'Deterministic variable 1: Sweep angle; Case: %d out of %d; Value: %.5f\n', ii, length(sa_custom_swept_wing_uncertain_price), sa_custom_swept_wing_uncertain_price(ii));
            fprintf(fileID, 'Deterministic variable 2: Mach number; Case: %d out of %d; Value: %.5f\n', jj, length(mach_custom_swept_wing_uncertain_price), mach_custom_swept_wing_uncertain_price(jj));
            fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots_custom_swept_wing_uncertain_price);
            fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
            fclose(fileID);
            disp('Readme file for the surrogates has been created successfully.');
        catch ME
            fprintf('Error in sample (%d, %d): %s\n', ii, jj, ME.message);
        end
    end
end    
set(0, 'DefaultFigureVisible', 'on');

% Calculate mean and sigma, do plots in terms of the design parameters (i.e., Sweep angle and Mach number); some values removed due to physical model code failures
mean_surrogate_custom_swept_wing_uncertain_price = nan(length(sa_custom_swept_wing_uncertain_price), length(mach_custom_swept_wing_uncertain_price));
std_surrogate_custom_swept_wing_uncertain_price = nan(length(sa_custom_swept_wing_uncertain_price), length(mach_custom_swept_wing_uncertain_price));
for ii = 1:length(sa_custom_swept_wing_uncertain_price)
    for jj = 1:length(mach_custom_swept_wing_uncertain_price)
        try
            plotsfolderName = 'custom_swept_wing_uncertain_price_optimisation_increased_grid_uq'; 
            subfolder_plotsfolderName = sprintf('sa_%u_mach_%u', ii, jj); % each 'case' refers to one fixed combination of design variables
            fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
            addpath(fullPath);
            surrogate_custom_swept_wing_uncertain_price = load(sprintf('surrogate_total_operating_cost_sa_case_%u_mach_case_%u.mat', ii, jj));
            surrogate_custom_swept_wing_uncertain_price = surrogate_custom_swept_wing_uncertain_price.elementToSave;

            N_MC_test = 10^6;
            inputs_for_mean_sigma_test_custom_swept_wing_uncertain_price = uq_getSample(myInput_custom_swept_wing_uncertain_price, N_MC_test, 'MC');      % generate N_MC Monte Carlo points in the uncertain variables' space
            outputs_for_mean_sigma_test_custom_swept_wing_uncertain_price = uq_evalModel(surrogate_custom_swept_wing_uncertain_price, inputs_for_mean_sigma_test_custom_swept_wing_uncertain_price);   % evaluate the surrogates to get QIs data
            mean_surrogate_custom_swept_wing_uncertain_price(ii, jj) = mean(outputs_for_mean_sigma_test_custom_swept_wing_uncertain_price, 1);
            std_surrogate_custom_swept_wing_uncertain_price(ii, jj) = std(outputs_for_mean_sigma_test_custom_swept_wing_uncertain_price, 1);
        catch ME
            fprintf('Error in sample (%d, %d): %s\n', ii, jj, ME.message);
        end
    end
end 

% plot
[x_custom_swept_wing_uncertain_price, y_custom_swept_wing_uncertain_price] = meshgrid(linspace(0.5, 0.9, 25), linspace(0, 40, 25)); % x: Mach number, y: Sweep angle
% Finer grid for interpolation
[xq_custom_swept_wing_uncertain_price, yq_custom_swept_wing_uncertain_price] = meshgrid(linspace(0.5, 0.9, 100), linspace(0, 40, 100));
% Interpolate for sigma using bicubic interpolation
Std_custom_swept_wing_uncertain_price = interp2(x_custom_swept_wing_uncertain_price, y_custom_swept_wing_uncertain_price, std_surrogate_custom_swept_wing_uncertain_price, xq_custom_swept_wing_uncertain_price, yq_custom_swept_wing_uncertain_price, 'cubic');

fig = figure();
imagesc([0.5 0.9], [0 40], Std_custom_swept_wing_uncertain_price);
set(gca, 'YDir', 'normal');  % Ensures y-axis is not flipped
axis tight;                  % Fits the image to data
colorbar;
title(sprintf('Sigma estimation (%s): Total operating cost', surrogate_custom_swept_wing_uncertain_price.Options.MetaType)); 
xlabel('Mach number'); 
ylabel('Sweep angle'); 
hold on;
% Overlay contour lines and labels
[contourMatrix, contourHandle] = contour(xq_custom_swept_wing_uncertain_price, yq_custom_swept_wing_uncertain_price, Std_custom_swept_wing_uncertain_price, 18, 'LineColor', 'k');
clabel(contourMatrix, contourHandle, 'FontSize', 8, 'Color', 'k');
saveas(fig, fullfile(plotsfolderName, 'Sigma_cost_for_sa_and_mach_with_custom_swept_wing_uncertain_price.png'))
saveas(fig, fullfile(plotsfolderName, 'Sigma_cost_for_sa_and_mach_with_custom_swept_wing_uncertain_price.fig'))


% Interpolate for mean using bicubic interpolation
Mean_custom_swept_wing_uncertain_price = interp2(x_custom_swept_wing_uncertain_price, y_custom_swept_wing_uncertain_price, mean_surrogate_custom_swept_wing_uncertain_price, xq_custom_swept_wing_uncertain_price, yq_custom_swept_wing_uncertain_price, 'cubic');

fig = figure();
imagesc([0.5 0.9], [0 40], Mean_custom_swept_wing_uncertain_price);
set(gca, 'YDir', 'normal');  % Ensures y-axis is not flipped
axis tight;                  % Fits the image to data
colorbar;
title(sprintf('Mean estimation (%s): Total operating cost', surrogate_custom_swept_wing_uncertain_price.Options.MetaType));
xlabel('Mach number');
ylabel('Sweep angle');
hold on;
% Overlay contour lines and labels
[contourMatrix, contourHandle] = contour(xq_custom_swept_wing_uncertain_price, yq_custom_swept_wing_uncertain_price, Mean_custom_swept_wing_uncertain_price, 18, 'LineColor', 'k');
clabel(contourMatrix, contourHandle, 'FontSize', 8, 'Color', 'k');
saveas(fig, fullfile(plotsfolderName, 'Mean_cost_for_sa_and_mach_with_custom_swept_wing_uncertain_price.png'))
saveas(fig, fullfile(plotsfolderName, 'Mean_cost_for_sa_and_mach_with_custom_swept_wing_uncertain_price.fig'))

F_mean = griddedInterpolant(x_custom_swept_wing_uncertain_price', y_custom_swept_wing_uncertain_price', mean_surrogate_custom_swept_wing_uncertain_price', 'cubic');  
F_sigma = griddedInterpolant(x_custom_swept_wing_uncertain_price', y_custom_swept_wing_uncertain_price', std_surrogate_custom_swept_wing_uncertain_price', 'cubic');  

% robust optimisation (minimise mean and sigma) using the interpolant surrogates
custom_swept_nvars_uncertain_price = 2;            % Number of design variables
custom_swept_lb_uncertain_price = [0, 0.5];        % Lower bounds
custom_swept_ub_uncertain_price = [40, 0.9];       % Upper bounds
custom_swept_objFun_uncertain_price = @(x) myObjectives_robust(x, F_mean, F_sigma);

custom_swept_options_uncertain_price = optimoptions('gamultiobj', 'Display', 'iter', 'PlotFcn', @gaplotpareto);     % Genetic Algorithm for multi-objective optimisation
[custom_swept_wing_pareto_uncertain_price, custom_swept_fval_uncertain_price] = gamultiobj(custom_swept_objFun_uncertain_price, custom_swept_nvars_uncertain_price, [], [], [], [], custom_swept_lb_uncertain_price, custom_swept_ub_uncertain_price, custom_swept_options_uncertain_price);
custom_swept_pareto_uncertain_price_size = size(custom_swept_wing_pareto_uncertain_price, 1);

for ii=1:custom_swept_pareto_uncertain_price_size
    try
        % Description of the physical model for UQLab
        ModelOpts_custom_swept_wing_uncertain_price.mFile = 'physical_model_indep_sweep_uncertain_fuel_price';
        ModelOpts_custom_swept_wing_uncertain_price.isVectorized = false;
        ModelOpts_custom_swept_wing_uncertain_price.Parameters = [custom_swept_wing_pareto_uncertain_price(ii, 1) custom_swept_wing_pareto_uncertain_price(ii, 2)];
        myModel_custom_swept_wing_uncertain_price = uq_createModel(ModelOpts_custom_swept_wing_uncertain_price);

        N_train = 5;                                     % initial training set size (the set will be updated until the surrogate validation error is low enough)
        MetaOpts_custom_swept_wing_uncertain_price.Type = 'Metamodel';             % 'metamodel': another word for 'surrogate'
        % MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'Kriging';      
        MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'PCE';
        MetaOpts_custom_swept_wing_uncertain_price.Input = myInput_custom_swept_wing_uncertain_price;        % probability distribution for the uncertain variables
        MetaOpts_custom_swept_wing_uncertain_price.FullModel = myModel_custom_swept_wing_uncertain_price;    % the physical model as a UQLab object
        MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.NSamples = N_train;   % 'experimental design' (ExpDesign): another word for 'training set'
        if strcmp(MetaOpts_custom_swept_wing_uncertain_price.MetaType, 'Kriging')
            MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.Sampling = 'User';
        end

        flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
        seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
        N_train_increment = 5;          % we will increment the training set size until we reach convergence
        N_train_max = 5;                % training budget (i.e., maximum number of training points allowed)
        % run a test to check if surrogates are actually faster than classical MC for mean and sigma estimation  
        % recommended only for cheap models (to find the true mean and sigma, we need a large MC with the physical model) 
        flag_test_for_mean_and_sigma = false;

        % Plots generator for parameter sweeps for the uncertain variables
        inputs_name_custom_swept_wing_uncertain_price = ["Fuel price", "Oil price"];  % list of the names of the uncertain variables
        outputs_name_custom_swept_wing_uncertain_price = ["Total operating cost"];    % list of the names of the QIs
        N_outputs_custom_swept_wing_uncertain_price = length(outputs_name_custom_swept_wing_uncertain_price);           % number of quantities of interest (QIs)
        descriptive_title_for_plots_custom_swept_wing_uncertain_price = sprintf('%s surrogate (Sweep angle:%.2e, Mach:%.2e)', MetaOpts_custom_swept_wing_uncertain_price.MetaType, custom_swept_wing_pareto_uncertain_price(ii, 1), custom_swept_wing_pareto_uncertain_price(ii, 2));
        N_eval = 100;                                                        % number of discretisation points for each uncertain variable (for plots)
        plotsfolderName = 'custom_swept_wing_uncertain_price_optimisation_increased_grid_uq'; 
        subfolder_plotsfolderName = sprintf('Pareto_point_number_%u', ii); 
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        mkdir(fullPath);
        mkdir(fullPath, 'plots_uq');
        true_model_pareto_custom_swept_wing_uncertain_price{ii, 1} =  surrogates_uq(MetaOpts_custom_swept_wing_uncertain_price, N_outputs_custom_swept_wing_uncertain_price, N_train_increment, N_train_max, flag_parfor, seed, fullPath, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
        elementToSave = true_model_pareto_custom_swept_wing_uncertain_price{ii, 1}; 
        save(fullfile(fullPath, sprintf('true_model_total_operating_cost_pareto_point_number_%u.mat', ii)), 'elementToSave'); % save the surrogate
        uncertain_variables_exploration(elementToSave, inputs_name_custom_swept_wing_uncertain_price, outputs_name_custom_swept_wing_uncertain_price, descriptive_title_for_plots_custom_swept_wing_uncertain_price, N_eval, seed, fullPath); % plots generator using the surrogates 

        fileID = fopen(fullfile(fullPath, 'readme.txt'), 'w');
        fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables (the deterministic variables are fixed).\n\n');
        fprintf(fileID, 'Legend:\n');
        N_outputs_custom_swept_wing_uncertain_price = length(outputs_name_custom_swept_wing_uncertain_price);             % number of quantities of interest (QIs)
        N_variables_custom_swept_wing_uncertain_price = length(inputs_name_custom_swept_wing_uncertain_price);            % number of uncertain variables
        for kk = 1:N_outputs_custom_swept_wing_uncertain_price
            fprintf(fileID, 'QI %d: %s\n', kk, outputs_name_custom_swept_wing_uncertain_price(kk));
        end   
        for kk = 1:N_variables_custom_swept_wing_uncertain_price
            fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name_custom_swept_wing_uncertain_price(kk));
        end    
        fprintf(fileID, 'Deterministic variable 1: Sweep angle; Pareto point number: %d; Value: %.5f\n', ii, custom_swept_wing_pareto_uncertain_price(ii, 1));
        fprintf(fileID, 'Deterministic variable 2: Mach number; Pareto point number: %d; Value: %.5f\n', ii, custom_swept_wing_pareto_uncertain_price(ii, 2));
        fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots_custom_swept_wing_uncertain_price);
        fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
        fclose(fileID);
        disp('Readme file for the surrogates has been created successfully.');
    catch ME
        fprintf('Error in sample %d: %s\n', ii, ME.message);
    end
end    

true_model_custom_swept_output_pareto_uncertain_price = nan(custom_swept_pareto_uncertain_price_size, 2);
% Calculate mean and sigma at the Pareto points using the surrogates trained on the physical model (rather than the fast cubic interpolation method above)
for ii = 1:custom_swept_pareto_uncertain_price_size
    try
        plotsfolderName = 'custom_swept_wing_uncertain_price_optimisation_increased_grid_uq'; 
        subfolder_plotsfolderName = sprintf('Pareto_point_number_%u', ii); 
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        addpath(fullPath);
        surrogate_custom_swept_wing_uncertain_price = load(sprintf('true_model_total_operating_cost_pareto_point_number_%u.mat', ii));
        surrogate_custom_swept_wing_uncertain_price = surrogate_custom_swept_wing_uncertain_price.elementToSave;

        N_MC_test = 10^6;
        inputs_for_mean_sigma_test_custom_swept_wing_uncertain_price = uq_getSample(myInput_custom_swept_wing_uncertain_price, N_MC_test, 'MC');      % generate N_MC Monte Carlo points in the uncertain variables' space
        outputs_for_mean_sigma_test_custom_swept_wing_uncertain_price = uq_evalModel(surrogate_custom_swept_wing_uncertain_price, inputs_for_mean_sigma_test_custom_swept_wing_uncertain_price);   % evaluate the surrogates to get QIs data
        true_model_custom_swept_output_pareto_uncertain_price(ii, 1) = mean(outputs_for_mean_sigma_test_custom_swept_wing_uncertain_price, 1);
        true_model_custom_swept_output_pareto_uncertain_price(ii, 2) = std(outputs_for_mean_sigma_test_custom_swept_wing_uncertain_price, 1);
    catch ME
        fprintf('Error in sample %d: %s\n', ii, ME.message);
    end
end 

custom_swept_wing_pareto_uncertain_price = custom_swept_wing_pareto_uncertain_price(~any(isnan(true_model_custom_swept_output_pareto_uncertain_price), 2), :);                           
true_model_custom_swept_output_pareto_uncertain_price = true_model_custom_swept_output_pareto_uncertain_price(~any(isnan(true_model_custom_swept_output_pareto_uncertain_price), 2), :); 

for ii = 1:size(custom_swept_wing_pareto_uncertain_price, 1)
    F_mean_tmp = F_mean(custom_swept_wing_pareto_uncertain_price(ii, 2), custom_swept_wing_pareto_uncertain_price(ii, 1));
    F_sigma_tmp = F_sigma(custom_swept_wing_pareto_uncertain_price(ii, 2), custom_swept_wing_pareto_uncertain_price(ii, 1));
    surrogate_output_custom_swept_pareto_uncertain_price_interp(ii, :) = [F_mean_tmp, F_sigma_tmp];
    relative_interp_error_custom_swept_uncertain_price_mean(ii) = abs(surrogate_output_custom_swept_pareto_uncertain_price_interp(ii, 1)/true_model_custom_swept_output_pareto_uncertain_price(ii, 1)-1);
    relative_interp_error_custom_swept_uncertain_price_sigma(ii) = abs(surrogate_output_custom_swept_pareto_uncertain_price_interp(ii, 2)/true_model_custom_swept_output_pareto_uncertain_price(ii, 2)-1);
end
% 
save(fullfile(plotsfolderName, 'opt_for_mean_and_sigma_with_custom_swept_wing_uncertain_price.mat'), 'custom_swept_wing_pareto_uncertain_price', 'true_model_custom_swept_output_pareto_uncertain_price', 'relative_interp_error_custom_swept_uncertain_price_mean', 'relative_interp_error_custom_swept_uncertain_price_sigma')
% 
true_model_custom_swept_sorted_points = sortrows(true_model_custom_swept_output_pareto_uncertain_price, 1);
surrogate_custom_swept_pareto_uncertain_price_sorted_points = sortrows(surrogate_output_custom_swept_pareto_uncertain_price_interp, 1);

fig = figure();
plot(true_model_custom_swept_sorted_points(:,1), true_model_custom_swept_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Physical Model');
hold on 
plot(surrogate_custom_swept_pareto_uncertain_price_sorted_points(:,1), surrogate_custom_swept_pareto_uncertain_price_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Surrogate Model');
xlabel('Total operating cost (mean)');
ylabel('Total operating cost (sigma)');
title('Pareto (Genetic Algorithm; uncertain fuel price)');
grid on;
legend('Location', 'best');
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_mean_and_sigma_with_custom_swept_wing_uncertain_price.png'))
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_mean_and_sigma_with_custom_swept_wing_uncertain_price.fig'))

%% 11. Swept wing case (design variables: Sweep angle, Mach no., AR, HingeEta)

% Description of the uncertain variables for UQLab
InputOpts_all_custom_swept_wing_fwt.Marginals(1).Type = 'Uniform';
InputOpts_all_custom_swept_wing_fwt.Marginals(1).Parameters = [0, 45];     % (Sweep angle) lower and upper design optimisation bound
InputOpts_all_custom_swept_wing_fwt.Marginals(2).Type = 'Uniform';
InputOpts_all_custom_swept_wing_fwt.Marginals(2).Parameters = [0.45, 0.9]; % (Mach no.) lower and upper design optimisation bound
InputOpts_all_custom_swept_wing_fwt.Marginals(3).Type = 'Uniform';
InputOpts_all_custom_swept_wing_fwt.Marginals(3).Parameters = [11, 23];    % (AR) lower and upper design optimisation bound
InputOpts_all_custom_swept_wing_fwt.Marginals(4).Type = 'Uniform';
InputOpts_all_custom_swept_wing_fwt.Marginals(4).Parameters = [0.45, 1];   % (HingeEta) lower and upper design optimisation bound
% The uncertain variables are inputs for physical maps that output QIs (i.e., Block Fuel, DOC, ...)
myInput_all_custom_swept_wing_fwt = uq_createInput(InputOpts_all_custom_swept_wing_fwt);

% This section generates many plots, which are saved rather than displayed on the screen
set(0, 'DefaultFigureVisible', 'off');

plotsfolderName = 'indep_sweep_ar_he_wing_uq'; 
mkdir(plotsfolderName)

% Description of the physical model for UQLab
ModelOpts_all_custom_swept_wing_fwt.mFile = 'physical_model_indep_sweep_ar_he';
ModelOpts_all_custom_swept_wing_fwt.isVectorized = false;
myModel_all_custom_swept_wing_fwt = uq_createModel(ModelOpts_all_custom_swept_wing_fwt);

N_train = 5;    % initial training set size (the set will be updated until the training budget is exhausted or until the surrogate validation error is low enough)
MetaOpts_all_custom_swept_wing_fwt.Type = 'Metamodel';                                % 'metamodel': another word for 'surrogate'    
MetaOpts_all_custom_swept_wing_fwt.MetaType = 'Kriging';                              % Kriging surrogate model
MetaOpts_all_custom_swept_wing_fwt.Input = myInput_all_custom_swept_wing_fwt;         % design variables
MetaOpts_all_custom_swept_wing_fwt.FullModel = myModel_all_custom_swept_wing_fwt;     % the physical model as a UQLab object
MetaOpts_all_custom_swept_wing_fwt.ExpDesign.NSamples = N_train;                      % 'experimental design' (ExpDesign): another word for 'training set'
if strcmp(MetaOpts_all_custom_swept_wing_fwt.MetaType, 'Kriging')
    MetaOpts_all_custom_swept_wing_fwt.ExpDesign.Sampling = 'User';
end

flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
N_train_increment = 8;          % we will increment the training set size until we reach convergence
N_train_max = 2000;             % training budget (i.e., maximum number of training points allowed)
flag_test_for_mean_and_sigma = false;

% Plots generator for parameter sweeps for the design variables
inputs_name = ["Sweep angle", "Mach number", "Aspect ratio", "Hinge eta"];  % list of the names of the design variables
outputs_name = ["Block fuel", "Direct operating cost", "Flightspan", "Groundspan", "CD0", "CD cruise", "MTOM"];   % list of the names of the QIs
N_outputs = length(outputs_name);                    % number of quantities of interest (QIs)
descriptive_title_for_plots = sprintf('%s surrogate', MetaOpts_all_custom_swept_wing_fwt.MetaType);
N_eval = 100;                                        % number of discretisation points for each design variable (for plots)
plotsfolderName = 'indep_sweep_ar_he_wing_uq'; 
mkdir(plotsfolderName, 'plots_uq');
tic;
surrogates_all_custom_swept_wing_fwt =  surrogates_uq(MetaOpts_all_custom_swept_wing_fwt, N_outputs, N_train_increment, N_train_max, flag_parfor, seed, plotsfolderName, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
totalTime = toc;
fprintf('Total surrogate building time: %.4f seconds\n', totalTime);
elementToSave = surrogates_all_custom_swept_wing_fwt;
save(fullfile(plotsfolderName, 'surrogates_indep_sweep_ar_he_wing.mat'), 'elementToSave'); % save the surrogate
% visualise the outputs as a function of the design variables (i.e., design exploration)
tic;
uncertain_variables_exploration(elementToSave, inputs_name, outputs_name, descriptive_title_for_plots, N_eval, seed, plotsfolderName); % plots generator using the surrogates 
totalTime = toc;
fprintf('Total design space exploration time: %.4f seconds\n', totalTime);
% add readme file
fileID = fopen(fullfile(plotsfolderName, 'readme.txt'), 'w');
fprintf(fileID, 'Surrogates for each quantity of interest (QI) as a function of the uncertain variables.\n\n');
fprintf(fileID, 'Legend:\n');
N_outputs = length(outputs_name);             % number of quantities of interest (QIs)
N_variables = length(inputs_name);            % number of uncertain variables
for kk = 1:N_outputs
    fprintf(fileID, 'QI %d: %s\n', kk, outputs_name(kk));
end   
for kk = 1:N_variables
    fprintf(fileID, 'Uncertain variable %d: %s\n', kk, inputs_name(kk));
end    
fprintf(fileID, 'Methodology: %s\n\n', descriptive_title_for_plots); 
fprintf(fileID, 'The trained surrogates and most of the design exploration figures are stored externally due to size limits.\n'); 
fclose(fileID);
disp('Readme file for the surrogates has been created successfully.');

set(0, 'DefaultFigureVisible', 'on');

% multi-objective optimisation using the surrogates
all_custom_he_fa_nvars = 4;                  % Number of design variables
all_custom_he_fa_lb = [0, 0.45, 11, 0.45];      % Lower bounds
all_custom_he_fa_ub = [45, 0.9, 23, 1];        % Upper bounds

plotsfolderName = 'indep_sweep_ar_he_wing_uq';
addpath(plotsfolderName);
surrogates_all_custom_he_fa_bf_doc = load('surrogates_indep_sweep_ar_he_wing.mat');
surrogates_all_custom_he_fa_bf_doc = surrogates_all_custom_he_fa_bf_doc.elementToSave;
all_custom_he_fa_objFun = @(x) myObjectives(x, surrogates_all_custom_he_fa_bf_doc);

all_custom_he_fa_options = optimoptions('gamultiobj', 'Display', 'iter', 'PlotFcn', @gaplotpareto);
[indep_sweep_and_ar_he_fa_wing_pareto, all_custom_he_fa_fval] = gamultiobj(all_custom_he_fa_objFun, all_custom_he_fa_nvars, [], [], [], [], all_custom_he_fa_lb, all_custom_he_fa_ub, all_custom_he_fa_options);
all_custom_he_fa_pareto_size = size(indep_sweep_and_ar_he_fa_wing_pareto, 1);

true_model_all_custom_he_fa_output_pareto = nan(all_custom_he_fa_pareto_size, N_outputs);     
if flag_parfor
    parfor ii=1:all_custom_he_fa_pareto_size
        try
            true_model_all_custom_he_fa_output_pareto(ii, :) = uq_evalModel(myModel_all_custom_swept_wing_fwt, indep_sweep_and_ar_he_fa_wing_pareto(ii, :));     % evaluate the physical model on the training inputs
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
else   
    for ii=1:all_custom_he_fa_pareto_size
        try
            true_model_all_custom_he_fa_output_pareto(ii, :) = uq_evalModel(myModel_all_custom_swept_wing_fwt, indep_sweep_and_ar_he_fa_wing_pareto(ii, :));
        catch ME
            fprintf('Error in sample %d: %s\n', ii, ME.message);
        end
    end
end   
indep_sweep_and_ar_he_fa_wing_pareto = indep_sweep_and_ar_he_fa_wing_pareto(~any(isnan(true_model_all_custom_he_fa_output_pareto), 2), :);                           
true_model_all_custom_he_fa_output_pareto = true_model_all_custom_he_fa_output_pareto(~any(isnan(true_model_all_custom_he_fa_output_pareto), 2), :); 

surrogate_output_all_custom_he_fa_pareto = uq_evalModel(surrogates_all_custom_he_fa_bf_doc, indep_sweep_and_ar_he_fa_wing_pareto);

for ii = 1:size(indep_sweep_and_ar_he_fa_wing_pareto, 1)
    relative_surrogate_error_indep_sweep_and_ar_he_fa_bf(ii) = abs(surrogate_output_all_custom_he_fa_pareto(ii, 1)/true_model_all_custom_he_fa_output_pareto(ii, 1)-1);
    relative_surrogate_error_indep_sweep_and_ar_he_fa_doc(ii) = abs(surrogate_output_all_custom_he_fa_pareto(ii, 2)/true_model_all_custom_he_fa_output_pareto(ii, 2)-1);
    if relative_surrogate_error_indep_sweep_and_ar_he_fa_doc(ii) >= 0.005 | relative_surrogate_error_indep_sweep_and_ar_he_fa_bf(ii) >= 0.005
        indep_sweep_and_ar_he_fa_wing_pareto(ii, :) = [];
        true_model_all_custom_he_fa_output_pareto(ii, :) = [];
        surrogate_output_all_custom_he_fa_pareto(ii, :) = [];
        relative_surrogate_error_indep_sweep_and_ar_he_fa_doc(ii) = [];
        relative_surrogate_error_indep_sweep_and_ar_he_fa_bf(ii) = [];
    end
end

save(fullfile(plotsfolderName, 'opt_for_bf_and_doc_with_indep_sweep_he.mat'), 'indep_sweep_and_ar_he_fa_wing_pareto', 'true_model_all_custom_he_fa_output_pareto','relative_surrogate_error_indep_sweep_and_ar_he_fa_bf', 'relative_surrogate_error_indep_sweep_and_ar_he_fa_doc')

true_model_all_custom_he_fa_sorted_points = sortrows(true_model_all_custom_he_fa_output_pareto, 1);
surrogate_model_all_custom_he_fa_sorted_points = sortrows(surrogate_output_all_custom_he_fa_pareto, 1);

fig = figure();
plot(true_model_all_custom_he_fa_sorted_points(:,1), true_model_all_custom_he_fa_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Physical Model');
hold on 
plot(surrogate_model_all_custom_he_fa_sorted_points(:,1), surrogate_model_all_custom_he_fa_sorted_points(:,2), 'o-', 'LineWidth', 2, 'DisplayName', 'Surrogate Model');
xlabel('Fuel Burn (FB)');
ylabel('Direct Operating Cost (DOC)');
title('Pareto Front (Genetic Algorithm with Kriging surrogates)');
grid on;
legend();
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_indep_sweep_and_ar_he.png'))
saveas(fig, fullfile(plotsfolderName, 'Pareto_opt_for_bf_and_doc_with_indep_sweep_and_ar_he.fig'))

%% 12. Bayesian optimisation - Deterministic multi-objective optimisation (minimise block fuel and TOC)
% first, minimise BF and TOC separately
x1 = optimizableVariable('x1', [0, 45]);      % (Sweep angle) lower and upper design optimisation bound
x2 = optimizableVariable('x2', [0.45, 0.9]);  % (Mach no.) lower and upper design optimisation bound
x3 = optimizableVariable('x3', [11, 23]);     % (AR) lower and upper design optimisation bound
x4 = optimizableVariable('x4', [0.45, 1]);    % (HingeEta) lower and upper design optimisation bound

% Objective function
fun_bf = @(x) BayesOptObjective_bf(x);
% Solve
results_bf = bayesopt(fun_bf,[x1,x2,x3,x4],'IsObjectiveDeterministic',true);
x_opt_bf = results_bf.XAtMinObjective;
fval_bf = results_bf.MinObjective;
% Objective function
fun_toc = @(x) BayesOptObjective_toc(x);
% Solve
results_toc = bayesopt(fun_toc,[x1,x2,x3,x4],'IsObjectiveDeterministic',true);
x_opt_toc = results_toc.XAtMinObjective;
fval_toc = results_toc.MinObjective;

fval_toc_max = BayesOptObjective_toc(x_opt_bf);

% prepare multi-objective
N_pareto_points = 10;
multi_obj_toc_threshold = linspace(1.005*fval_toc, 1.005*fval_toc_max, N_pareto_points);
for ii = 1:N_pareto_points
    % Objective function
    fun = @(x) BayesOptMultiObjectiveConstraints(x, multi_obj_toc_threshold(ii));
    % Solve
    results = bayesopt(fun,[x1,x2,x3,x4],'IsObjectiveDeterministic',true,'NumCoupledConstraints',1,'AcquisitionFunctionName','probability-of-improvement','MaxObjectiveEvaluations', 100);
    x_opt_multi_obj(ii, :) = results.XAtMinObjective{1,:};
    bf_multi_obj(ii) = results.MinObjective;
    toc_multi_obj(ii) = results.ConstraintsTrace(results.IndexOfMinimumTrace(end))+multi_obj_toc_threshold(ii);
end    

fig = figure();
plot(bf_multi_obj, toc_multi_obj, 'o-', 'LineWidth', 2);
xlabel('Fuel Burn (FB)');
ylabel('Direct Operating Cost (DOC)');
title('Pareto Front (Bayesian optimisation)');
grid on;
saveas(fig, 'Pareto_opt_for_bf_and_toc.png')
saveas(fig, 'Pareto_opt_for_bf_and_toc.fig')

save('bayes_opt_multi_obj_det_opt_for_bf_and_toc.mat', 'bf_multi_obj', 'toc_multi_obj', 'x_opt_multi_obj')

%% 13. Bayesian optimisation - Deterministic multi-objective optimisation with NASTRAN (minimise block fuel and TOC)
% first, minimise BF and TOC separately
x1 = optimizableVariable('x1', [0, 45]);      % (Sweep angle) lower and upper design optimisation bound
x2 = optimizableVariable('x2', [0.45, 0.9]);  % (Mach no.) lower and upper design optimisation bound
x3 = optimizableVariable('x3', [11, 23]);     % (AR) lower and upper design optimisation bound

% Objective function
fun_bf = @(x) BayesOptObjective_bf_nastran(x);
% Solve
results_bf = bayesopt(fun_bf,[x1,x2,x3],'IsObjectiveDeterministic',true);
x_opt_bf = results_bf.XAtMinObjective;
fval_bf = results_bf.MinObjective;
% Objective function
fun_toc = @(x) BayesOptObjective_toc_nastran(x);
% Solve
results_toc = bayesopt(fun_toc,[x1,x2,x3],'IsObjectiveDeterministic',true);
x_opt_toc = results_toc.XAtMinObjective;
fval_toc = results_toc.MinObjective;

fval_toc_max = BayesOptObjective_toc_nastran(x_opt_bf);

% prepare multi-objective
N_pareto_points = 10;
multi_obj_toc_threshold = linspace(1.005*fval_toc, 1.005*fval_toc_max, N_pareto_points);
for ii = 1:N_pareto_points
    % Objective function
    fun = @(x) BayesOptMultiObjectiveConstraints_nastran(x, multi_obj_toc_threshold(ii));
    % Solve
    results = bayesopt(fun,[x1,x2,x3],'IsObjectiveDeterministic',true,'NumCoupledConstraints',1,'AcquisitionFunctionName','probability-of-improvement');
    x_opt_multi_obj(ii, :) = results.XAtMinObjective{1,:};
    bf_multi_obj(ii) = results.MinObjective;
    toc_multi_obj(ii) = results.ConstraintsTrace(results.IndexOfMinimumTrace(end))+multi_obj_toc_threshold(ii);
end  

fval_bf_max = BayesOptObjective_bf_nastran(x_opt_toc);
x_opt_multi_obj(1, :) = x_opt_toc{1, :};
bf_multi_obj(1) = fval_bf_max;
toc_multi_obj(1) = fval_toc;

fig = figure();
plot(toc_multi_obj, bf_multi_obj, 'o-', 'LineWidth', 2);
xlabel('Direct operating cost');
ylabel('Block fuel');
title('Pareto Front (Bayesian optimisation)');
grid on;
saveas(fig, 'Pareto_opt_for_bf_and_toc_nastran.png')
saveas(fig, 'Pareto_opt_for_bf_and_toc_nastran.fig')

save('bayes_opt_multi_obj_det_opt_for_bf_and_toc_nastran.mat', 'bf_multi_obj', 'toc_multi_obj', 'x_opt_multi_obj')

%% 14. Genetic algorithm - Deterministic multi-objective optimisation (minimise block fuel and TOC)
% first, minimise BF and TOC separately

% Objective function
objFun_bf = @(x) DetOptObjective_bf(x);
% Bounds
lb = [0, 0.45, 11, 0.45];  % Lower bounds
ub = [45, 0.9, 23, 1];     % Upper bounds
% Number of variables
nvars = 4;
% GA options
options = optimoptions('ga', ...
    'Display', 'iter', ...        % Show iteration details
    'PopulationSize', 30, ...     % Increase population for better exploration
    'MaxGenerations', 20, ...    % More generations for convergence
    'PlotFcn', {@gaplotbestf});   % Plot best fitness over generations
% Run GA
[x_opt_bf_ga, fval_bf_ga] = ga(objFun_bf, nvars, [], [], [], [], lb, ub, [], options);
% Objective function
objFun_toc = @(x) DetOptObjective_toc(x);
% Solve
[x_opt_toc_ga, fval_toc_ga] = ga(objFun_toc, nvars, [], [], [], [], lb, ub, [], options);

% prepare multi-objective
fval_toc_max_ga = DetOptObjective_toc(x_opt_bf_ga);
fval_bf_max_ga = DetOptObjective_bf(x_opt_toc_ga);
N_pareto_points = 10;
x_opt_multi_obj_ga = zeros(N_pareto_points, nvars);
fval_bf_multi_obj_ga = zeros(N_pareto_points, 1);
fval_bf_multi_obj_ga(1) = fval_bf_max_ga;
fval_bf_multi_obj_ga(end) = fval_bf_ga;
fval_toc_multi_obj_ga = zeros(N_pareto_points, 1);
fval_toc_multi_obj_ga(1) = fval_toc_ga;
fval_toc_multi_obj_ga(end) = fval_toc_max_ga;
multi_obj_toc_ga_threshold = linspace(fval_toc_ga, fval_toc_max_ga, N_pareto_points);
for ii = 2:N_pareto_points-1
    % Constraint function
    nonlcon_pareto_ga = @(x) nonlinearConstraints_bf_toc(x, multi_obj_toc_ga_threshold(ii));
    % Solve
    [x_opt_ga_pareto, fval_ga_pareto] = ga(objFun_bf, nvars, [], [], [], [], lb, ub, nonlcon_pareto_ga, options);
    x_opt_multi_obj_ga(ii, :) = x_opt_ga_pareto;
    fval_bf_multi_obj_ga(ii) = fval_ga_pareto;
    fval_toc_multi_obj_ga(ii) = DetOptObjective_toc(x_opt_ga_pareto);
end    

x_opt_multi_obj_ga(1, :) = x_opt_toc_ga;
x_opt_multi_obj_ga(end, :) = x_opt_bf_ga;
fig = figure();
plot(fval_toc_multi_obj_ga, fval_bf_multi_obj_ga, 'o-', 'LineWidth', 2);
xlabel('Direct operating cost');
ylabel('Block fuel');
title('Pareto Front (Genetic Algorithm)');
grid on;
saveas(fig, 'Pareto_opt_for_bf_and_toc_ga.png')
saveas(fig, 'Pareto_opt_for_bf_and_toc_ga.fig')

save('ga_multi_obj_det_opt_for_bf_and_toc.mat', 'fval_bf_multi_obj_ga', 'fval_toc_multi_obj_ga', 'x_opt_multi_obj_ga')

%% 15. Multi-objective genetic algorithm - Deterministic multi-objective optimisation (minimise block fuel and TOC)

% Objective function
objFun_bf_toc = @(x) DetOptObjective_bf_toc(x);
% Bounds
lb = [0, 0.45, 11, 0.45];  % Lower bounds
ub = [45, 0.9, 23, 1];     % Upper bounds
% Number of variables
nvars = 4;

% Options
options = optimoptions('gamultiobj', ...
    'PopulationSize', 100, ...
    'MaxGenerations', 200, ...
    'PlotFcn', {@gaplotpareto});

% Run multi-objective GA
[x_opt_multi_obj_ga_pareto, fval] = gamultiobj(objFun_bf_toc, nvars, [], [], [], [], lb, ub, options);

fig = figure();
scatter(fval(:, 1), fval(:, 2), 'filled');
xlabel('Fuel Burn (FB)');
ylabel('Direct Operating Cost (DOC)');
title('Pareto Front (Genetic Algorithm)');
grid on;
saveas(fig, 'Pareto_opt_for_bf_and_toc_ga_converged.png')
saveas(fig, 'Pareto_opt_for_bf_and_toc_ga_converged.fig')

save('ga_multi_obj_det_opt_for_bf_and_toc_converged.mat', 'fval', 'x_opt_multi_obj_ga_pareto')

%% 16. Method comparison for deterministic optimisation

% method comparison (ga vs ga+gp vs bo)
fig = figure();
scatter(fval(:, 1), fval(:, 2), 'filled', 'MarkerFaceColor', 'r');
hold on
scatter(true_model_all_custom_he_fa_output_pareto(:, 1), true_model_all_custom_he_fa_output_pareto(:, 2), 'filled', 'MarkerFaceColor', 'b');
scatter(bf_multi_obj_enforced, toc_multi_obj_enforced, 'filled', 'MarkerFaceColor', 'g');
% Add legend
legend({'GA', 'GA+GP', 'BO'}, 'Location', 'best');
xlabel('Fuel Burn (FB)');
ylabel('Direct Operating Cost (DOC)');
title('Pareto Fronts');
grid on;
hold off;
saveas(fig, 'Pareto_opt_for_bf_and_toc_method_comparison.png')
saveas(fig, 'Pareto_opt_for_bf_and_toc_method_comparison.fig')

% method comparison (enforced lift dist'n vs nastran)
fig = figure();
scatter(bf_multi_obj_enforced, toc_multi_obj_enforced, 'filled', 'MarkerFaceColor', 'b');
hold on
scatter(bf_multi_obj_nastran, toc_multi_obj_nastran, 'filled', 'MarkerFaceColor', 'r');
% Add legend
legend({'Low fidelity', 'NASTRAN'}, 'Location', 'best');
xlabel('Fuel Burn (FB)');
ylabel('Direct Operating Cost (DOC)');
title('Pareto Fronts (Bayesian Optimisation)');
grid on;
hold off;
saveas(fig, 'Pareto_opt_for_bf_and_toc_method_comparison_nastran.png')
saveas(fig, 'Pareto_opt_for_bf_and_toc_method_comparison_nastran.fig')

%% 17. Bayesian optimisation - Robust optimisation (design variables: sweep, Mach, Hinge, AR; uncertain fuel price)
% Number of variables
nvars = 4;
x1 = optimizableVariable('x1', [0, 45]);      % (Sweep angle) lower and upper design optimisation bound
x2 = optimizableVariable('x2', [0.45, 0.9]);  % (Mach no.) lower and upper design optimisation bound
x3 = optimizableVariable('x3', [11, 23]);     % (AR) lower and upper design optimisation bound
x4 = optimizableVariable('x4', [0.45, 1]);    % (HingeEta) lower and upper design optimisation bound
% Objective function
fun_sigma_toc = @(x) BayesOptObjective_sigma_toc(x);
% Solve
results_sigma_toc = bayesopt(fun_sigma_toc,[x1,x2,x3,x4],'IsObjectiveDeterministic',true, 'MaxObjectiveEvaluations', 100);
x_opt_sigma_toc = results_sigma_toc.XAtMinObjective;
fval_sigma_toc = results_sigma_toc.MinObjective;
% Objective function
fun_mean_toc = @(x) BayesOptObjective_mean_toc(x);
% Solve
results_mean_toc = bayesopt(fun_mean_toc,[x1,x2,x3,x4],'IsObjectiveDeterministic',true, 'MaxObjectiveEvaluations', 100);
x_opt_mean_toc = results_mean_toc.XAtMinObjective;
fval_mean_toc = results_mean_toc.MinObjective;

% prepare multi-objective
fval_sigma_toc_max = BayesOptObjective_sigma_toc(x_opt_mean_toc);
fval_mean_toc_max = BayesOptObjective_mean_toc(x_opt_sigma_toc);
N_pareto_points = 10;
x_opt_robust_multi_obj = zeros(N_pareto_points, nvars);
fval_sigma_toc_multi_obj = zeros(N_pareto_points, 1);
fval_sigma_toc_multi_obj(1) = fval_sigma_toc_max;
fval_sigma_toc_multi_obj(end) = fval_sigma_toc;
fval_mean_toc_multi_obj = zeros(N_pareto_points, 1);
fval_mean_toc_multi_obj(1) = fval_mean_toc;
fval_mean_toc_multi_obj(end) = fval_mean_toc_max;
multi_obj_mean_toc_threshold = linspace(fval_mean_toc, fval_mean_toc_max, N_pareto_points);

for ii = 2:N_pareto_points-1
    % Objective function
    fun = @(x) BayesOptMultiObjectiveConstraints_mean_sigma_toc(x, multi_obj_mean_toc_threshold(ii));
    % Solve
    results = bayesopt(fun,[x1,x2,x3,x4],'IsObjectiveDeterministic',true,'NumCoupledConstraints',1,'AcquisitionFunctionName','probability-of-improvement', 'MaxObjectiveEvaluations', 100);
    x_opt_robust_multi_obj(ii, :) = results.XAtMinObjective{1,:};
    fval_sigma_toc_multi_obj(ii) = results.MinObjective;
    fval_mean_toc_multi_obj(ii) = results.ConstraintsTrace(results.IndexOfMinimumTrace(end))+multi_obj_mean_toc_threshold(ii);
end    

x_opt_robust_multi_obj(1, :) = x_opt_mean_toc{1, :};
x_opt_robust_multi_obj(end, :) = x_opt_sigma_toc{1, :};
% remove the runs where BO returns a dominated point (visual inspection)
rowsToRemove = [7 8 9];
fval_sigma_toc_multi_obj(rowsToRemove, :) = [];
fval_mean_toc_multi_obj(rowsToRemove, :) = [];
x_opt_robust_multi_obj(rowsToRemove, :) = [];
fig = figure();
plot(fval_mean_toc_multi_obj, fval_sigma_toc_multi_obj, 'o-', 'LineWidth', 2);
xlabel('Total operating cost (mean)');
ylabel('Total operating cost (sigma)');
title('Pareto (Bayes Optimisation; uncertain fuel price)');
grid on;
saveas(fig, 'Pareto_opt_for_toc_mean_and_sigma_uncertain_price_bayes_opt.png')
saveas(fig, 'Pareto_opt_for_toc_mean_and_sigma_uncertain_price_bayes_opt.fig')

save('bayes_opt_robust_multi_obj_for_mean_and_sigma_toc.mat', 'fval_mean_toc_multi_obj', 'fval_sigma_toc_multi_obj', 'x_opt_robust_multi_obj')

%% 18. Method comparison for robust optimisation

true_model_custom_swept_sorted_points = sortrows(true_model_custom_swept_output_pareto_uncertain_price, 1);
% method comparison (ga+gp vs bo)
fig = figure();
scatter(true_model_custom_swept_sorted_points(:,1), true_model_custom_swept_sorted_points(:,2), 'filled', 'MarkerFaceColor', 'r');
hold on
scatter(fval_mean_toc_multi_obj, fval_sigma_toc_multi_obj, 'filled', 'MarkerFaceColor', 'g');
% Add legend
legend({'GA+GP', 'BO'}, 'Location', 'best');
xlabel('Total operating cost (mean)');
ylabel('Total operating cost (sigma)');
title('Pareto Fronts');
grid on;
hold off;
saveas(fig, 'Pareto_opt_for_toc_method_comparison_uncertain_fuel_price.png')
saveas(fig, 'Pareto_opt_for_toc_method_comparison_uncertain_fuel_price.fig')

%%
function f = myObjectives(x, surrogates_bf_doc)
    f_val = uq_evalModel(surrogates_bf_doc, x);  
    f1_val = f_val(1);  
    f2_val = f_val(2);  
    f = [f1_val, f2_val];
end

function f = myObjectives_robust(x, F_mean, F_sigma)
    f_mean = F_mean(x(2), x(1));  
    f_sigma = F_sigma(x(2), x(1));   
    f = [f_mean, f_sigma];
end

function objective = BayesOptObjective_bf(x)
    % Objective function
    fun = @(x) physical_model_indep_sweep_ar_he_block_fuel(x{1, :});
    try
        objective = fun(x);
    catch ME
        fprintf('Error: %s\n', ME.message);
        objective = NaN;
    end
end

function objective = BayesOptObjective_toc(x)
    % Objective function
    fun = @(x) physical_model_indep_sweep_ar_he_toc(x{1, :});
    try
        objective = fun(x);
    catch ME
        fprintf('Error: %s\n', ME.message);
        objective = NaN;
    end
end

function [objective, constraint1] = BayesOptMultiObjectiveConstraints(x, multi_obj_toc_threshold)
    % Objective function
    fun = @(x) physical_model_indep_sweep_ar_he(x{1, :});
    try
        tmp_output = fun(x);
        objective = tmp_output(1);
        constraint1 = tmp_output(2)-multi_obj_toc_threshold;
    catch ME
        fprintf('Error: %s\n', ME.message);
        objective = NaN;
        constraint1 = NaN;
    end
end

function objective = BayesOptObjective_bf_nastran(x)
    % Objective function
    fun = @(x) physical_model_indep_sweep_ar_he_block_fuel_nastran(x{1, :});
    try
        objective = fun(x);
    catch ME
        fprintf('Error: %s\n', ME.message);
        objective = NaN;
    end
end

function objective = BayesOptObjective_toc_nastran(x)
    % Objective function
    fun = @(x) physical_model_indep_sweep_ar_he_toc_nastran(x{1, :});
    try
        objective = fun(x);
    catch ME
        fprintf('Error: %s\n', ME.message);
        objective = NaN;
    end
end

function [objective, constraint1] = BayesOptMultiObjectiveConstraints_nastran(x, multi_obj_toc_threshold)
    % Objective function
    fun = @(x) physical_model_indep_sweep_ar_he_nastran(x{1, :});
    try
        tmp_output = fun(x);
        objective = tmp_output(1);
        constraint1 = tmp_output(2)-multi_obj_toc_threshold;
    catch ME
        fprintf('Error: %s\n', ME.message);
        objective = NaN;
        constraint1 = NaN;
    end
end

function objective = DetOptObjective_bf(x)
    % Objective function
    fun = @(x) physical_model_indep_sweep_ar_he_block_fuel(x);
    try
        objective = fun(x);
    catch ME
        fprintf('Error: %s\n', ME.message);
        objective = 1e6;
    end
end

function objective = DetOptObjective_toc(x)
    % Objective function
    fun = @(x) physical_model_indep_sweep_ar_he_toc(x);
    try
        objective = fun(x);
    catch ME
        fprintf('Error: %s\n', ME.message);
        objective = 1e6;
    end
end

function [c, ceq] = nonlinearConstraints_bf_toc(x, toc_threshold)
    fun = @(x) physical_model_indep_sweep_ar_he_toc(x);
    try
        c = fun(x)-toc_threshold;
    catch ME
        fprintf('Error: %s\n', ME.message);
        c = 1e6;
    end
    ceq = [];  % No equality constraints
end

function objective = DetOptObjective_bf_toc(x)
    % Objective function
    fun = @(x) physical_model_indep_sweep_ar_he_block_fuel_toc(x);
    try
        objective = fun(x);
    catch ME
        fprintf('Error: %s\n', ME.message);
        objective = [1e6, 1e6];
    end
end

function objective = BayesOptObjective_sigma_toc(x)
    try
        % Robust Optimisation - Description of the uncertain variables for UQLab
        InputOpts_custom_swept_wing_uncertain_price.Marginals(1).Type = 'Uniform';
        InputOpts_custom_swept_wing_uncertain_price.Marginals(1).Parameters = [0.9*0.64995, 1.1*0.64995]; % (Fuel price) lower and upper uncertainty bound
        InputOpts_custom_swept_wing_uncertain_price.Marginals(2).Type = 'Uniform';
        InputOpts_custom_swept_wing_uncertain_price.Marginals(2).Parameters = [0.9*30.0, 1.1*30.0]; % (Oil price) lower and upper uncertainty bound
        % The uncertain variables are inputs for physical maps that output QIs
        myInput_custom_swept_wing_uncertain_price = uq_createInput(InputOpts_custom_swept_wing_uncertain_price); 
        % Description of the physical model for UQLab
        ModelOpts_custom_swept_wing_uncertain_price.mFile = 'physical_model_indep_sweep_ar_he_uncertain_fuel_price';
        ModelOpts_custom_swept_wing_uncertain_price.isVectorized = false;
        ModelOpts_custom_swept_wing_uncertain_price.Parameters = [x{1, 1} x{1, 2} x{1, 3} x{1, 4}];
        myModel_custom_swept_wing_uncertain_price = uq_createModel(ModelOpts_custom_swept_wing_uncertain_price);

        N_train = 5;                                     % initial training set size (the set will be updated until the surrogate validation error is low enough)
        MetaOpts_custom_swept_wing_uncertain_price.Type = 'Metamodel';             % 'metamodel': another word for 'surrogate'
        % MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'Kriging';      
        MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'PCE';
        MetaOpts_custom_swept_wing_uncertain_price.Input = myInput_custom_swept_wing_uncertain_price;        % probability distribution for the uncertain variables
        MetaOpts_custom_swept_wing_uncertain_price.FullModel = myModel_custom_swept_wing_uncertain_price;    % the physical model as a UQLab object
        MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.NSamples = N_train;   % 'experimental design' (ExpDesign): another word for 'training set'
        if strcmp(MetaOpts_custom_swept_wing_uncertain_price.MetaType, 'Kriging')
            MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.Sampling = 'User';
        end

        flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
        seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
        N_train_increment = 5;          % we will increment the training set size until we reach convergence
        N_train_max = 5;                % training budget (i.e., maximum number of training points allowed)
        % run a test to check if surrogates are actually faster than classical MC for mean and sigma estimation  
        % recommended only for cheap models (to find the true mean and sigma, we need a large MC with the physical model) 
        flag_test_for_mean_and_sigma = false;

        % Plots generator for parameter sweeps for the uncertain variables
        inputs_name_custom_swept_wing_uncertain_price = ["Fuel price", "Oil price"];  % list of the names of the uncertain variables
        outputs_name_custom_swept_wing_uncertain_price = ["Total operating cost"];    % list of the names of the QIs
        N_outputs_custom_swept_wing_uncertain_price = length(outputs_name_custom_swept_wing_uncertain_price);           % number of quantities of interest (QIs)
        descriptive_title_for_plots_custom_swept_wing_uncertain_price = sprintf('%s surrogate', MetaOpts_custom_swept_wing_uncertain_price.MetaType);
        N_eval = 100;                                                        % number of discretisation points for each uncertain variable (for plots)
        plotsfolderName = 'custom_sweep_ar_he_wing_uncertain_price_optimisation_uq'; 
        subfolder_plotsfolderName = 'Bayes_opt_candidate'; 
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        mkdir(fullPath);
        mkdir(fullPath, 'plots_uq');
        custom_swept_wing_uncertain_price =  surrogates_uq(MetaOpts_custom_swept_wing_uncertain_price, N_outputs_custom_swept_wing_uncertain_price, N_train_increment, N_train_max, flag_parfor, seed, fullPath, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
        elementToSave = custom_swept_wing_uncertain_price; 
        save(fullfile(fullPath, 'true_model_total_operating_cost_bayes_opt_candidate.mat'), 'elementToSave'); % save the surrogate
      
        N_MC_test = 10^6;
        inputs_for_sigma = uq_getSample(myInput_custom_swept_wing_uncertain_price, N_MC_test, 'MC');      % generate N_MC Monte Carlo points in the uncertain variables' space
        outputs_for_sigma = uq_evalModel(elementToSave, inputs_for_sigma);   % evaluate the surrogates to get QIs data
        objective = std(outputs_for_sigma, 1);
    catch ME
        fprintf('Error: %s\n', ME.message);
        objective = NaN;
    end
end

function objective = BayesOptObjective_mean_toc(x)
    try
        % Robust Optimisation - Description of the uncertain variables for UQLab
        InputOpts_custom_swept_wing_uncertain_price.Marginals(1).Type = 'Uniform';
        InputOpts_custom_swept_wing_uncertain_price.Marginals(1).Parameters = [0.9*0.64995, 1.1*0.64995]; % (Fuel price) lower and upper uncertainty bound
        InputOpts_custom_swept_wing_uncertain_price.Marginals(2).Type = 'Uniform';
        InputOpts_custom_swept_wing_uncertain_price.Marginals(2).Parameters = [0.9*30.0, 1.1*30.0]; % (Oil price) lower and upper uncertainty bound
        % The uncertain variables are inputs for physical maps that output QIs
        myInput_custom_swept_wing_uncertain_price = uq_createInput(InputOpts_custom_swept_wing_uncertain_price); 
        % Description of the physical model for UQLab
        ModelOpts_custom_swept_wing_uncertain_price.mFile = 'physical_model_indep_sweep_ar_he_uncertain_fuel_price';
        ModelOpts_custom_swept_wing_uncertain_price.isVectorized = false;
        ModelOpts_custom_swept_wing_uncertain_price.Parameters = [x{1, 1} x{1, 2} x{1, 3} x{1, 4}];
        myModel_custom_swept_wing_uncertain_price = uq_createModel(ModelOpts_custom_swept_wing_uncertain_price);

        N_train = 5;                                     % initial training set size (the set will be updated until the surrogate validation error is low enough)
        MetaOpts_custom_swept_wing_uncertain_price.Type = 'Metamodel';             % 'metamodel': another word for 'surrogate'
        % MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'Kriging';      
        MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'PCE';
        MetaOpts_custom_swept_wing_uncertain_price.Input = myInput_custom_swept_wing_uncertain_price;        % probability distribution for the uncertain variables
        MetaOpts_custom_swept_wing_uncertain_price.FullModel = myModel_custom_swept_wing_uncertain_price;    % the physical model as a UQLab object
        MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.NSamples = N_train;   % 'experimental design' (ExpDesign): another word for 'training set'
        if strcmp(MetaOpts_custom_swept_wing_uncertain_price.MetaType, 'Kriging')
            MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.Sampling = 'User';
        end

        flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
        seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
        N_train_increment = 5;          % we will increment the training set size until we reach convergence
        N_train_max = 5;                % training budget (i.e., maximum number of training points allowed)
        % run a test to check if surrogates are actually faster than classical MC for mean and sigma estimation  
        % recommended only for cheap models (to find the true mean and sigma, we need a large MC with the physical model) 
        flag_test_for_mean_and_sigma = false;

        % Plots generator for parameter sweeps for the uncertain variables
        inputs_name_custom_swept_wing_uncertain_price = ["Fuel price", "Oil price"];  % list of the names of the uncertain variables
        outputs_name_custom_swept_wing_uncertain_price = ["Total operating cost"];    % list of the names of the QIs
        N_outputs_custom_swept_wing_uncertain_price = length(outputs_name_custom_swept_wing_uncertain_price);           % number of quantities of interest (QIs)
        descriptive_title_for_plots_custom_swept_wing_uncertain_price = sprintf('%s surrogate', MetaOpts_custom_swept_wing_uncertain_price.MetaType);
        N_eval = 100;                                                        % number of discretisation points for each uncertain variable (for plots)
        plotsfolderName = 'custom_sweep_ar_he_wing_uncertain_price_optimisation_uq'; 
        subfolder_plotsfolderName = 'Bayes_opt_candidate'; 
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        mkdir(fullPath);
        mkdir(fullPath, 'plots_uq');
        custom_swept_wing_uncertain_price =  surrogates_uq(MetaOpts_custom_swept_wing_uncertain_price, N_outputs_custom_swept_wing_uncertain_price, N_train_increment, N_train_max, flag_parfor, seed, fullPath, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
        elementToSave = custom_swept_wing_uncertain_price; 
        save(fullfile(fullPath, 'true_model_total_operating_cost_bayes_opt_candidate.mat'), 'elementToSave'); % save the surrogate
      
        N_MC_test = 10^6;
        inputs_for_mean = uq_getSample(myInput_custom_swept_wing_uncertain_price, N_MC_test, 'MC');      % generate N_MC Monte Carlo points in the uncertain variables' space
        outputs_for_mean = uq_evalModel(elementToSave, inputs_for_mean);   % evaluate the surrogates to get QIs data
        objective = mean(outputs_for_mean, 1);
    catch ME
        fprintf('Error: %s\n', ME.message);
        objective = NaN;
    end
end

function [objective, constraint1] = BayesOptMultiObjectiveConstraints_mean_sigma_toc(x, mean_threshold)
    try
        % Robust Optimisation - Description of the uncertain variables for UQLab
        InputOpts_custom_swept_wing_uncertain_price.Marginals(1).Type = 'Uniform';
        InputOpts_custom_swept_wing_uncertain_price.Marginals(1).Parameters = [0.9*0.64995, 1.1*0.64995]; % (Fuel price) lower and upper uncertainty bound
        InputOpts_custom_swept_wing_uncertain_price.Marginals(2).Type = 'Uniform';
        InputOpts_custom_swept_wing_uncertain_price.Marginals(2).Parameters = [0.9*30.0, 1.1*30.0]; % (Oil price) lower and upper uncertainty bound
        % The uncertain variables are inputs for physical maps that output QIs
        myInput_custom_swept_wing_uncertain_price = uq_createInput(InputOpts_custom_swept_wing_uncertain_price); 
        % Description of the physical model for UQLab
        ModelOpts_custom_swept_wing_uncertain_price.mFile = 'physical_model_indep_sweep_ar_he_uncertain_fuel_price';
        ModelOpts_custom_swept_wing_uncertain_price.isVectorized = false;
        ModelOpts_custom_swept_wing_uncertain_price.Parameters = [x{1, 1} x{1, 2} x{1, 3} x{1, 4}];
        myModel_custom_swept_wing_uncertain_price = uq_createModel(ModelOpts_custom_swept_wing_uncertain_price);

        N_train = 5;                                     % initial training set size (the set will be updated until the surrogate validation error is low enough)
        MetaOpts_custom_swept_wing_uncertain_price.Type = 'Metamodel';             % 'metamodel': another word for 'surrogate'
        % MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'Kriging';      
        MetaOpts_custom_swept_wing_uncertain_price.MetaType = 'PCE';
        MetaOpts_custom_swept_wing_uncertain_price.Input = myInput_custom_swept_wing_uncertain_price;        % probability distribution for the uncertain variables
        MetaOpts_custom_swept_wing_uncertain_price.FullModel = myModel_custom_swept_wing_uncertain_price;    % the physical model as a UQLab object
        MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.NSamples = N_train;   % 'experimental design' (ExpDesign): another word for 'training set'
        if strcmp(MetaOpts_custom_swept_wing_uncertain_price.MetaType, 'Kriging')
            MetaOpts_custom_swept_wing_uncertain_price.ExpDesign.Sampling = 'User';
        end

        flag_parfor = true;             % can we run the physical model in parallel to build the training set? (True/False)
        seed = 100;                     % seed for reproducibility due to randomness in sampling the training set
        N_train_increment = 5;          % we will increment the training set size until we reach convergence
        N_train_max = 5;                % training budget (i.e., maximum number of training points allowed)
        % run a test to check if surrogates are actually faster than classical MC for mean and sigma estimation  
        % recommended only for cheap models (to find the true mean and sigma, we need a large MC with the physical model) 
        flag_test_for_mean_and_sigma = false;

        % Plots generator for parameter sweeps for the uncertain variables
        inputs_name_custom_swept_wing_uncertain_price = ["Fuel price", "Oil price"];  % list of the names of the uncertain variables
        outputs_name_custom_swept_wing_uncertain_price = ["Total operating cost"];    % list of the names of the QIs
        N_outputs_custom_swept_wing_uncertain_price = length(outputs_name_custom_swept_wing_uncertain_price);           % number of quantities of interest (QIs)
        descriptive_title_for_plots_custom_swept_wing_uncertain_price = sprintf('%s surrogate', MetaOpts_custom_swept_wing_uncertain_price.MetaType);
        N_eval = 100;                                                        % number of discretisation points for each uncertain variable (for plots)
        plotsfolderName = 'custom_sweep_ar_he_wing_uncertain_price_optimisation_uq'; 
        subfolder_plotsfolderName = 'Bayes_opt_candidate'; 
        fullPath = fullfile(plotsfolderName, subfolder_plotsfolderName);
        mkdir(fullPath);
        mkdir(fullPath, 'plots_uq');
        custom_swept_wing_uncertain_price =  surrogates_uq(MetaOpts_custom_swept_wing_uncertain_price, N_outputs_custom_swept_wing_uncertain_price, N_train_increment, N_train_max, flag_parfor, seed, fullPath, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
        elementToSave = custom_swept_wing_uncertain_price; 
        save(fullfile(fullPath, 'true_model_total_operating_cost_bayes_opt_candidate.mat'), 'elementToSave'); % save the surrogate
      
        N_MC_test = 10^6;
        inputs_for_sigma = uq_getSample(myInput_custom_swept_wing_uncertain_price, N_MC_test, 'MC');      % generate N_MC Monte Carlo points in the uncertain variables' space
        outputs_for_sigma = uq_evalModel(elementToSave, inputs_for_sigma);   % evaluate the surrogates to get QIs data
        objective = std(outputs_for_sigma, 1);
        constraint1 = mean(outputs_for_sigma, 1)-mean_threshold;
    catch ME
        fprintf('Error: %s\n', ME.message);
        objective = NaN;
        constraint1 = NaN;
    end
end