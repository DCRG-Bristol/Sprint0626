%% ------------------------------------------------------------------------
%  Surrogate Model Pipeline for WRBM under Gust Loads (A220)
%  ------------------------------------------------------------------------

clear; clc;
load('example_data\A220_simple.mat');

%% 1. DESIGN OF EXPERIMENTS -----------------------------------------------
nSamples   = 5;
paramNames = {'AR','HingeEta','FlareAngle','Mach','SweepAngle'};

ranges = [  8   16;     % AR
            0.5 0.8;    % HingeEta
            5   25;     % FlareAngle
            0.7 0.9;    % Mach
            5 40];      % SweepAngle

lhs = lhsdesign(nSamples, numel(paramNames), 'criterion','maximin');
X = ranges(:,1)' + lhs .* (ranges(:,2) - ranges(:,1))';

%% 2. PRE-ALLOCATE --------------------------------------------------------
Y_WRBM = nan(nSamples,1);
caseOK = false(nSamples,1);

%% 3. RUN SIMULATIONS -----------------------------------------------------
for i = 1:nSamples
    fprintf('▶ Running Case %3d / %d\n', i, nSamples);

    % Assign Parameters
    ADP.AR           = X(i,1);
    ADP.HingeEta     = X(i,2);
    ADP.FlareAngle   = X(i,3);
    ADP.ADR.M_c      = X(i,4);
    ADP.SweepAngle   = X(i,5);
    
    % conduct sizing
    ads.util.printing.title('Example Surrogates','Length',60,'Symbol','$')
    SubHarmonic = [0.8,3000./cast.SI.Nmile];
    sizeOpts = util.SizingOpts(IncludeGusts=false,...
        IncludeTurb=false,BinFolder='bin_size',SubHarmonic=SubHarmonic);
    [ADP,res_mtom,Lds,time,isError,Cases] = ADP.Aircraft_Sizing(sizeOpts,"SizeMethod","SAH");
    % get data during cruise
    fh.printing.title('Get Cruise Loads','Length',60)
    [~,Lds_c]=ADP.StructuralSizing(...
        LoadCaseFactory.GetCases(ADP,sizeOpts,"Cruise"),sizeOpts);
    Lds = Lds | Lds_c;
    %save data
    res = util.ADP2SizeMeta(ADP,'GFWT','Mano',1.5,Lds,time,isError,Cases);

    if ~isfolder('example_data')
        mkdir('example_data');
    end
    save('example_data/A220_simple_rerun.mat','ADP','Lds');
    
    % Reload and build geometry
    rerunData = load('example_data/A220_simple_rerun.mat');
    ADP = rerunData.ADP;
    
    ADP.BuildBaff();

    try
        PayloadFec = 1;
        ld = loads.NastranModel(ADP);
        lc = cast.LoadCase.Gust(ADP.ADR.M_c, ADP.ADR.Alt_cruise .* cast.SI.ft);
        ld.SetConfiguration(IsLocked=true, PayloadFraction=PayloadFec);
        ld.BinFolder = sprintf('Bin_test',i);
        [Lds, BinFolder] = ld.GustLoads(lc, 1);

        % Extract gust response
        gusts = ld.ExtractDynamicLoads(fullfile(BinFolder,'bin','sol146.h5'), ld.Tags(2));
        disp(size(gusts(1).My));
        disp(gusts(1));
        wrbm_vec = abs(gusts(1).My);  % Full-span bending moment
        
        % Initialize full Y if first case
        if isempty(Y_WRBM_full)
            nStations = length(wrbm_vec);
            Y_WRBM_full = nan(nSamples, nStations);
        end

        Y_WRBM_full(i, :) = wrbm_vec;
        caseOK(i) = true;
        disp(Y_WRBM_full)

        % Clean temporary files (optional)
        try
            system(sprintf('del "\\\\.\\%s\\%s\\Source\\nul"', pwd, BinFolder));
        catch
        end

    catch ME
        warning('Case %d failed: %s', i, ME.message);
    end
end

% Keep valid data
X = X(caseOK,:);
Y = Y_WRBM_full(caseOK, :);

%% 4. FIT GPR MODEL -------------------------------------------------------
fprintf('\nTraining GPR Models for %d Spanwise Stations...\n', nStations);
GPR_models = cell(1, nStations);

for k = 1:nStations
    fprintf('Training Station %d/%d...\n', k, nStations);
    gprMdl = fitrgp(X, Y, ...
        'BasisFunction',   'none', ...
        'KernelFunction',  'ardsquaredexponential', ...
        'Standardize',     true, ...
        'OptimizeHyperparameters', 'auto', ...
        'HyperparameterOptimizationOptions', struct( ...
            'MaxObjectiveEvaluations', 60, ...
            'ShowPlots', false));
end

% Save the model
saveLearnerForCoder(gprMdl, 'GPR_WRBM.mat');

%% 5. CROSS-VALIDATION ----------------------------------------------------
cvMdl = crossval(gprMdl, 'KFold', 5);
mse = kfoldLoss(cvMdl);  % default MSE
rmse = sqrt(mse);        % convert to RMSE
fprintf('Cross-validated RMSE = %.1f Nm\n', rmse);
