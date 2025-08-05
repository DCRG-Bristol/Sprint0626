function [Par,Lds,isError,indicator] = StructuralSizing(obj,Cases,opts)
arguments
    obj
    Cases (:,1) cast.LoadCase % Load Cases to run
    opts cast.nast.Opts = cast.nast.Opts % Options for sizing
end

%initialise wing box params
Par{1} = obj.WingBoxParams;
indicator = inf;
if isempty(opts.BinFolder)
        opts.BinFolder = ads.nast.create_tmp_bin;
end

%build Surrogate
switch obj.LoadsSurrogateType
    case "Enforced"
        obj.LoadsSurrogate = loads.EnforcedLiftDist(obj);
    case "Nastran"
        obj.LoadsSurrogate = loads.NastranModel(obj);
end

% run loops
isError = true; 
for n = 1:opts.WingboxMaxStep+1
    if indicator*100 < opts.WingboxConvergence
        isError = false;
        break
    else
        if n == opts.WingboxMaxStep+1
            if opts.WingboxMaxStep==1
                % warning('Max iteration steps reached')
                isError = false;
                break
            else
                error('CAST:SizingError','Inner Sizing Loop did not converge.')
            end            
        end
    end
    if ~opts.Silent
        ads.util.printing.title(sprintf('Sizing %s, Step %.0f',obj.Name,n),Length=60);
    end
    obj.WingBoxParams = Par{n};
    %get loads for each case
    
    [Lds] = obj.LoadsSurrogate.GetLoads(Cases);
    %size aircraft
    Par{n+1} = obj.WingBoxParams.Size(Lds.max(),1,"Verbose",opts.Verbose,"Converge",0.05);
    %add check if slow to converge
    if (n>5 &&  (Par{n+1} == Par{n})>0.05) || n>opts.NGoldenSection
        Par{n+1} = Par{n} + (Par{n+1} - Par{n}).*0.382;
    end
    % check for convergence
    indicator = Par{n} == Par{n+1};
    if ~opts.Silent
        ads.util.printing.title(sprintf('Sizing step %.0f Complete, Total Percentage Change %.2f',n,indicator*100),Length=60,Symbol='~');
    end
end
Par = Par{end};
obj.WingBoxParams = Par;
if ~opts.Silent
    ads.util.printing.title(sprintf('Sizing %s Complete!',obj.Name),Length=60);
end
end

