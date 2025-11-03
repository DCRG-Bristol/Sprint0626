function objective = BayesOptObjective_toc_nastran_for_multi_fidelity(x)
    % Objective function
    fun = @(x) physical_model_indep_sweep_ar_he_toc_nastran(x);
    objective = nan(size(x, 1), 1);
    for ii = 1:size(x, 1)
        try
            objective(ii) = fun(x(ii, :));
        catch ME
            fprintf('Error: %s\n', ME.message);
            objective(ii) = NaN;
        end
    end
end