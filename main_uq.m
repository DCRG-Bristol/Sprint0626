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
InputOpts.Marginals(1).Type = 'Uniform';
InputOpts.Marginals(1).Parameters = [11, 23]; % (Aspect Ratio) lower and upper design optimisation bound
InputOpts.Marginals(2).Type = 'Uniform';
InputOpts.Marginals(2).Parameters = [0.45, 0.69]; % (Mach no.) lower and upper design optimisation bound - straight wing
% The uncertain variables are inputs for physical maps that output QIs (i.e., Block Fuel, DOC, ...)
myInput = uq_createInput(InputOpts);

plotsfolderName = 'straight_wing_uq'; 
mkdir(plotsfolderName)

% Description of the physical model for UQLab
ModelOpts_straight_wing.mFile = 'physical_model_straight_wing';
ModelOpts_straight_wing.isVectorized = false;
myModel_straight_wing = uq_createModel(ModelOpts_straight_wing);

N_train = 5;    % initial training set size (the set will be updated until the training budget is exhausted or until the surrogate validation error is low enough)
MetaOpts_straight_wing.Type = 'Metamodel';                 % 'metamodel': another word for 'surrogate'    
MetaOpts_straight_wing.MetaType = 'PCE';                   % Polynomial Chaos Expansion surrogate model
MetaOpts_straight_wing.Input = myInput;                    % design variables
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
descriptive_title_for_plots = sprintf('%s surrogate', MetaOpts_straight_wing.MetaType);
N_eval = 100;                                        % number of discretisation points for each design variable (for plots)
plotsfolderName = 'straight_wing_uq'; 
mkdir(plotsfolderName, 'plots_uq');
surrogates_straight_wing =  surrogates_uq(MetaOpts_straight_wing, N_train_increment, N_train_max, flag_parfor, seed, plotsfolderName, flag_test_for_mean_and_sigma); % Generates training points and builds the surrogates 
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

% TODO: add the optimisation part

set(0, 'DefaultFigureVisible', 'on');


