fuel_price = 0.64995; % USD/kg
oil_price = 30.0; % USD/kg
range_mission = 3000./cast.SI.Nmile*cast.SI.km; % range of mission convert Nautical miles to km [km]
N_pax = 140; % Number of passengers
N_eng = 2; % Number of engines

%% ========================= Set Hyper-parameters =========================
nSamplesvec = [1000,5000];
%nSamplesvec = [1 3 5];
% type = 'test';
types = {'training'};
for i = 1:length(nSamplesvec)
    pw = fh.PoolWaitbar(nSamplesvec(i), 'Training Data');
    for j = 1:length(types)
        nSamples = nSamplesvec(i);
        type = types{j};
        if strcmp(type,'test')
            inputScaled = rand(nSamples,5);
        else
            inputScaled = lhsdesign(nSamples,5);
        end
        % expand by 5%
        inputScaled = inputScaled.* 1.1 - 0.05;
        % define input bounds
        inputs = [11 23; ... %AR
            0.475 0.925; ... %Norm SAH pos
            10 20;... % SAH Flare angle
            0.45 0.9;... % Cruise speed (mach)
            0 45]; %Qtr-Chord sweep angle
        inScale = inputs(:,2)-inputs(:,1);

        inputUnscaled = inputScaled*diag(inScale)+ones(size(inputScaled))*diag(inputs(:,1));

        printoutput = false;
        saveMat = false;

        outArray = nan(nSamples,8);
        tic
        % for k = 1:nSamples
        parfor k = 1:nSamples
        % for k = 311
        % % sampleOut = sizeSample(inputUnscaled(i,:),saveMat,printoutput);
            try
                ads.Log.setLevel("Warn");
                sampleOut = sizeSample(inputUnscaled(k,:),saveMat,printoutput);
                outArray(k,:) = sampleOut;
            catch ME
                % Store error message and identifier
                errors{k} = struct('index', k, 'message', ME.message, 'identifier', ME.identifier);
                fprintf('Error in sample %d: %s\n', k, ME.message);
            end
            pw.increment();
        end
        toc
        if strcmp(type,'test')
            TrainingSet = [inputUnscaled outArray];
            filename = ['Testset_' num2str(nSamples) '.mat'];
            save(filename, 'TrainingSet');

            % Save as .csv
            filename_csv = ['Testset_' num2str(nSamples) '.csv'];
            writematrix(TrainingSet, filename_csv);  % Use csvwrite if using older MATLAB
        else
            TrainingSet = [inputUnscaled outArray];
            filename = ['Trainingset_' num2str(nSamples) '.mat'];
            save(filename, 'TrainingSet');

            % Save as .csv
            filename_csv = ['Trainingset_' num2str(nSamples) '.csv'];
            writematrix(TrainingSet, filename_csv);  % Use csvwrite if using older MATLAB
        end
    end
    pw.delete();
end
