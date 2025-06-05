N = 3;

ARs = linspace(10,22, N);
Sweeps = linspace(10,30, N);
HEs = linspace(0.5,0.9, N);

Data_record1 = zeros(N^3,4);
counter = 1;

for i = 1:N
    for j = 1:N
        for k = 1:N

            % initialise class
            test = SB;

            disp(['Running AR =', num2str(ARs(i)), '   sweep =', num2str(Sweeps(j)), '   He =', num2str(HEs(k))])
            disp(['number of run   ', num2str(counter)]);

            test.ADP_model = ADP;

            % set top level parameters
            test.ADP_model.AR = ARs(i);
            test.ADP_model.SweepAngle = Sweeps(j);
            test.ADP_model.HingeEta = HEs(k);

            % initial guess of sm
            test.ADP_model.StaticMargin = 0.35;

            % calculate x0
            test.findX;
            x0 = test.ADP_model.StaticMargin;

            % record data
            Data_record1(counter,1) = ARs(i);
            Data_record1(counter,2) = Sweeps(j);
            Data_record1(counter,3) = HEs(k);
            Data_record1(counter,4) = x0;

            counter = counter + 1;

            clear test
            
        end
    end

end

save('SM_Data2.mat','Data_record1');















% test.Calc_SM;
% test.Run_sizing;

% test.Calc_SM;



% % update x0
% test.ADP_model.StaticMargin = 0.4;
% 
% test.Calc_SM;
% 
% disp(num2str(test.SM))
% 
% 
% % update x0
% test.ADP_model.StaticMargin = 0.5;
% 
% test.Calc_SM;
% 
% disp(num2str(test.SM))










