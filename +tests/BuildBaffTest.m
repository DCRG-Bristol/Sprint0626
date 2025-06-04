classdef BuildBaffTest < matlab.unittest.TestCase
    properties(TestParameter)
        AR = num2cell(linspace(10,22,2));
        HingeEta = num2cell(linspace(0.5,1,2));
        M = num2cell(linspace(0.5,0.85,2));
        Sweep = num2cell(linspace(0,35,2));
        Flare = num2cell(linspace(0,30,2));
    end
    properties
        ADP TAW
    end
    
    % properties (ClassSetupParameter)
    %     classSetupParameter1 = struct("scalar",1,"vector",[1 1]);
    % end
    methods(TestClassSetup)
        function setupOnce(testCase)
            load('example_data/A220_simple.mat','ADP');
            testCase.ADP = ADP;
        end
    end

    methods(Test)
        % Test methods
        function buildTest(testCase,AR,HingeEta,M,Sweep,Flare)
            testCase.ADP.AR = AR;
            testCase.ADP.HingeEta = HingeEta;
            testCase.ADP.FlareAngle = Flare;
            testCase.ADP.ADR.M_c = M;
            testCase.ADP.SweepAngle = Sweep;
            testCase.ADP.ConstraintAnalysis();
            testCase.ADP.BuildBaff();
            testCase.ADP.UpdateAeroEstimates();
            testCase.verifyNotEmpty(testCase.ADP.WingArea);

            cd = testCase.ADP.AeroSurrogate.Get_Cd(0.5,M,FlightPhase.Cruise);
            cd0 = testCase.ADP.AeroSurrogate.Get_Cd(0,M,FlightPhase.Cruise);
            testCase.verifyGreaterThan(cd,0);
            testCase.verifyGreaterThan(cd0,0);
        end

        function sizingTest(testCase)
            testCase.ADP.AR = 15;
            testCase.ADP.HingeEta = 0.7;
            testCase.ADP.FlareAngle = 15;
            testCase.ADP.ADR.M_c = 0.78;
            testCase.ADP.SweepAngle = 25;
            testCase.ADP.ConstraintAnalysis();
            testCase.ADP.BuildBaff;
            %% ============================ Re-run Sizing =============================
            % conduct sizing
            SubHarmonic = [0.8,3000./cast.SI.Nmile];
            sizeOpts = util.SizingOpts(IncludeGusts=false,...
                IncludeTurb=false,BinFolder='bin_size',SubHarmonic=SubHarmonic);
            [testCase.ADP,res_mtom,Lds,time,isError,Cases] = testCase.ADP.Aircraft_Sizing(sizeOpts,"SizeMethod","SAH");
            [~,~,trip_fuel,~] = testCase.ADP.MJperPAX(3000./cast.SI.Nmile,0.8);
            testCase.verifyGreaterThan(trip_fuel,0);
        end
    end
end