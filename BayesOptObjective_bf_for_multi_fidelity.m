function objective = BayesOptObjective_bf_for_multi_fidelity(x)
    % Objective function
    fun = @(x) physical_model_indep_sweep_and_ar_block_fuel(x);
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