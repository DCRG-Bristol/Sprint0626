%% 5. PREDICT FOR NEW SAMPLE ---------------------------------------------- 
stationGridNorm = linspace(0, 1, 50);  % normalized stations for prediction

% Load model
data = load('GPR_gusts_locked.mat');
gprMdl_1 = data.gprMdl_1;
gprMdl_2 = data.gprMdl_11;
ranges = data.ranges;

testPoint = [18.6, 0.7, 15, 0.78, 10];  % AR, HingeEta, Flare, Mach, Sweep
ypred_1 = zeros(1,50);
ypred_2 = zeros(1,50);

for j = 1:50
    ypred_1(j) = predict(gprMdl_1{j}, testPoint, 'Alpha', 0.05);
    ypred_2(j) = predict(gprMdl_11{j}, testPoint, 'Alpha', 0.05);
end

%% 6. PLOT RESULT ---------------------------------------------------------
figure; hold on; box on;
plot(stationGridNorm, ypred_1, 'b-', 'LineWidth', 2);
plot(stationGridNorm, ypred_2, 'r-', 'LineWidth', 2);
xlabel('Normalized Spanwise Position');
ylabel('WRBM [Nm]');
title('Predicted WRBM vs Actual');
legend('My (Gusts)', 'Mx (Gusts)', 'Location', 'Best');
