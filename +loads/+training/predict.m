%% 6. PREDICTION + CONFIDENCE INTERVAL ------------------------------------
% Load the trained model
gprMdl = loadLearnerForCoder('GPR_WRBM.mat');

testPoint = [12, 0.8, 15, 0.8, 15];

% Predict WRBM and confidence intervals
[ypred, ysd, yint] = predict(gprMdl, testPoint, 'Alpha', 0.05); % 95% CI

for i = 1:size(testPoint,1)
    fprintf('Prediction for [%s]: WRBM = %.1f Nm\n', ...
        num2str(testPoint(i,:)), ypred(i));
    fprintf('95%% Confidence Interval: [%.1f, %.1f] Nm\n\n', ...
        yint(i,1), yint(i,2));
end