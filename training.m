%% ------------------------------------------------------------------------
%  Surrogate Model Pipeline for WRBM (Full Span) under Gust Loads (A220)
%  ------------------------------------------------------------------------

load('example_data\A220_simple.mat');

%% 1. DESIGN OF EXPERIMENTS -----------------------------------------------
nSamples   = 50;
paramNames = {'AR','HingeEta','FlareAngle','Mach','SweepAngle'};

ranges = [  12   22;     % AR
            0.5 1;       % HingeEta
            5   35;      % FlareAngle
            0.5 0.85;    % Mach
            0 40];       % SweepAngle

nParams = size(ranges, 1);
% Generate LHS samples in normalized [0,1] space
lhs = lhsdesign(nSamples, nParams, 'criterion', 'maximin', 'iterations', 100);

% Scale to parameter ranges
X = zeros(nSamples, nParams);
for i = 1:nParams
    X(:,i) = lhs(:,i) * (ranges(i,2) - ranges(i,1)) + ranges(i,1);
end

%% 2. PRE-ALLOCATE --------------------------------------------------------
Y_WRBM = cell(nSamples,1);    % each cell contains a bending moment curve (vector)
stationGridNorm = linspace(0, 1, 50);  % normalized stations for prediction
caseOK = false(nSamples,1);

%% 3. RUN SIMULATIONS -----------------------------------------------------
for i = 1:nSamples
    fprintf('▶ Running Case %3d / %d\n', i, nSamples);

    try
        % Assign Parameters
        ADP.AR           = X(i,1);
        ADP.HingeEta     = X(i,2);
        ADP.FlareAngle   = X(i,3);
        ADP.ADR.M_c      = X(i,4);
        ADP.SweepAngle   = X(i,5);

        % Aircraft sizing
        ads.util.printing.title('Example Surrogates','Length',60,'Symbol','$')
        SubHarmonic = [0.8,3000./cast.SI.Nmile];
        sizeOpts = util.SizingOpts(IncludeGusts=false, IncludeTurb=false, ...
                                    BinFolder='bin_size', SubHarmonic=SubHarmonic);
        [ADP,res_mtom,Lds,time,isError,Cases] = ADP.Aircraft_Sizing(sizeOpts, "SizeMethod", "SAH");

        % Cruise loads
        fh.printing.title('Get Cruise Loads','Length',60)
        [~,Lds_c] = ADP.StructuralSizing(LoadCaseFactory.GetCases(ADP,sizeOpts,"Cruise"), sizeOpts);
        Lds = Lds | Lds_c;
        res = util.ADP2SizeMeta(ADP,'GFWT','Mano',1.5,Lds,time,isError,Cases);
        % Save rerun geometry
        if ~isfolder('example_data')
            mkdir('example_data'); 
        end
        
        save('example_data/A220_simple_rerun.mat','ADP','Lds');

        % Reload + build baff
        rerunData = load('example_data/A220_simple_rerun.mat');
        ADP = rerunData.ADP;
        ADP.BuildBaff();

        % Gust simulation
        PayloadFec = 1;
        ld = loads.NastranModel(ADP);
        lc = cast.LoadCase.Gust(ADP.ADR.M_c, ADP.ADR.Alt_cruise * cast.SI.ft);
        ld.SetConfiguration(IsLocked=true, PayloadFraction=PayloadFec);
        ld.BinFolder = sprintf('Bin_test', i);
        [~, BinFolder] = ld.GustLoads(lc, 1);

        gusts_1 = ld.ExtractDynamicLoads(fullfile(BinFolder, 'bin', 'sol146.h5'), ld.Tags(2));
        gusts_2 = ld.ExtractDynamicLoads(fullfile(BinFolder, 'bin', 'sol146.h5'), ld.Tags(3));
        vec_1 = max(abs(gusts_1(1).My), [], 1);  % Inner span bending moment
        vec_2 = max(abs(gusts_2(1).My), [], 1);  % Outer span bending moment
  
        % Get station locations and normalize to [0,1]
        hh_1 = ADP.WingBoxParams(2).Span*ADP.WingBoxParams(2).Eta;
        hh_2 = ADP.WingBoxParams(2).Span + ADP.WingBoxParams(3).Span*ADP.WingBoxParams(3).Eta;
        
        % If overlapping junction point exists, remove from second segment
        if abs(hh_1(end) - hh_2(1)) < 1e-6
            hh_2 = hh_2(2:end);
            vec_2 = vec_2(2:end);
        end
        
        hh = [hh_1, hh_2];
        spanNorm = hh./max(hh);
        
        vec_full = [vec_1, vec_2];               % Concatenate along the span-wise direction
        
        % Ensure spanNorm is strictly increasing and unique
        [spanNorm, idx] = unique(spanNorm, 'stable');
        vec_full = vec_full(idx);

        % Interpolate moment to common station grid
        myInterp = interp1(spanNorm, vec_full, stationGridNorm, 'pchip', 'extrap');

        Y_WRBM{i} = myInterp;
        caseOK(i) = true;

        % Optional: delete bin files
        try
            system(sprintf('del "\\\\.\\%s\\%s\\Source\\nul"', pwd, BinFolder));
        catch
        end

    catch ME
        warning('Case %d failed: %s', i, ME.message);
    end
end

% Filter valid cases
X = X(caseOK, :);
Y_mat = cell2mat(Y_WRBM(caseOK));  % nValidSamples x 50

%% 4. FIT GPR MODELS FOR EACH STATION -------------------------------------
gprMdl_1 = cell(1, 50);
for j = 1:50
    gprMdl_1{j} = fitrgp(X, Y_mat(:,j), ...
        'BasisFunction',   'none', ...
        'KernelFunction',  'ardsquaredexponential', ...
        'Standardize',     true, ...
        'OptimizeHyperparameters', 'auto', ...
        'HyperparameterOptimizationOptions', struct( ...
            'MaxObjectiveEvaluations', 30, ...
            'ShowPlots', false));
end

% Save all models
save('GPR_WRBM_1.mat', 'gprMdl_1', 'paramNames', 'ranges');