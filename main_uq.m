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

%%
function f = myObjectives(x, surrogates_bf_doc)
    f_val = uq_evalModel(surrogates_bf_doc, x);  
    f1_val = f_val(1);  
    f2_val = f_val(2);  
    f = [f1_val, f2_val];
end
