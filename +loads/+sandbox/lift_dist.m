clear all
ARs = 10:4:22;
Sweep = 0:7.5:30;
HingeEtas = [0.6,0.8];
runs = fh.combvec(Sweep,HingeEtas,ARs);

% util.notify("Info",'Param Sweep Started','fintan.healy@bristol.ac.uk')
data = {};
for i = 1:size(runs,1)
    fh.printing.title(sprintf('Run %.0f of %.0f,AR %.0f, Sweep %.1f, Eta %.1f',i,size(runs,1),runs(i,3),runs(i,1),runs(i,2)));
    % util.notify("Info",sprintf('Started Run %.0f of %.0f',i,size(runs,1)),'fintan.healy@bristol.ac.uk')
    try
        %% Size using Enforced Stuff
        if i>1 && runs(i,3)==runs(i-1,3) && runs(i,1)==runs(i-1,1)
            ads.util.printing.title('Reuse ADP','Length',60,'Symbol','$')
        else
            load('example_data\A220_simple.mat')
        end
        % ========================= Set Hyper-parameters =========================
        ADP.AR = runs(i,3);
        ADP.HingeEta = runs(i,2);
        ADP.FlareAngle = 15;
        ADP.ADR.M_c = 0.78;
        ADP.SweepAngle = runs(i,1); % if empty will link to mach number...
        % ============================ Re-run Sizing =============================
        ads.util.printing.title('Example Surrogates','Length',60,'Symbol','$')
        SubHarmonic = [0.8,3000./cast.SI.Nmile];
        sizeOpts = util.SizingOpts(IncludeGusts=false,...
            IncludeTurb=false,BinFolder='bin_size',SubHarmonic=SubHarmonic);
        [ADP,res_mtom,Lds,time,isError,Cases] = ADP.Aircraft_Sizing(sizeOpts,"SizeMethod","SAH");
        
        %% ========================= Run Nastran Proper ===========================
        
        % build Nastran Object
        ld = loads.NastranModel(ADP);
        ld.BinFolder = 'bin_jig';
        %build load cases
        opts = util.SizingOpts(IncludeGusts=false,IncludeTurb=false,IncludeGround=false,Include1G=true);
        Cases = LoadCaseFactory.GetCases(ADP,opts,"SAH");
        Lds = ld.GetLoads(Cases);
    
        tmp = struct();
        tmp.AR = ADP.AR;
        tmp.HingeEta = ADP.HingeEta;
        tmp.SweepAngle = ADP.SweepAngle;
        tmp.MTOM = ADP.MTOM;
        tmp.Span = ADP.Span;
        tmp.Lds = Lds;
        tmp.Meta = ADP.ToMeta();
        tmp.LoadFactor = [1,[Cases.LoadFactor]];
        data{i} = tmp;
    catch
        % util.notify("Info",sprintf('Run %.0f of %.0f Failed',i,size(runs,1)),'fintan.healy@bristol.ac.uk')
    end
    if mod(i,5)==0
        save("C:\Users\qe19391\OneDrive - University of Bristol\LiftDistData.mat","data");
    end
end
% util.notify("Complete","Param Sweep completed",'fintan.healy@bristol.ac.uk')
save("LiftDistData.mat","data");
save("C:\Users\qe19391\OneDrive - University of Bristol\LiftDistData.mat","data");
