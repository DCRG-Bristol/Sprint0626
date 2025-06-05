%% 5. PREDICT FOR NEW SAMPLE ----------------------------------------------
stationGridNorm = linspace(0, 1, 50);  % normalized stations for prediction

data = load('GPR_turb_locked.mat');
gprMdl = data.gprMdl_3;
ranges = data.ranges;

testPoint = [18.6, 0.7, 15, 0.78, 10];  % AR, HingeEta, Flare, Mach, Sweep
ypred = zeros(1,50);
ysd   = zeros(1,50);
yint  = zeros(50,2);

fprintf('Normalized Pos\tPrediction [Nm]\tLower 95%% CI\tUpper 95%% CI\n');
fprintf('--------------------------------------------------------------\n');

for j = 1:50
    [ypred(j), ysd(j), yint(j,:)] = predict(gprMdl{j}, testPoint, 'Alpha', 0.05);
    
end

%% 6. PLOT RESULT ---------------------------------------------------------
figure; hold on; box on;
plot(stationGridNorm, ypred, 'b-', 'LineWidth', 2);
xlabel('Normalized Spanwise Position');
ylabel('WRBM [Nm]');
title('Predicted WRBM across Wing Span');