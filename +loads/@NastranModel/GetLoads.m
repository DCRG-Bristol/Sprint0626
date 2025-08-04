function [Lds] = GetLoads(obj,Cases)
arguments
    obj
    Cases (:,1) cast.LoadCase % Load Cases to run
end
ads.util.printing.title('Calculating Nastran Loads',Length=60);
if obj.UpdateJigTwist
    config = struct();
    config.FuelMass = obj.Taw.MTOM*obj.Taw.Mf_Fuel;
    if ~isempty(Cases)
        config.PayloadFraction = Cases(1).ConfigParams.PayloadFraction;
    else
        config.PayloadFraction = 1;
    end
    config.IsLocked = true;
    tmpCase = util.JigTwistSizingCase(obj.Taw.ADR.M_c,obj.Taw.ADR.Alt_cruise.*cast.SI.ft,Config=config,SafetyFactor=1,Idx=99);
    Cases = [tmpCase;Cases];
end
for i = 1:length(Cases)
    % if ~obj.Silent
        ads.util.printing.title(sprintf('Running Case %s',Cases(i).Name),Length=60,Symbol='+');
    % end
    cellArgs = namedargs2cell(Cases(i).ConfigParams);
    obj.SetConfiguration(cellArgs{:});
    if ~ismethod(obj,Cases(i).Type)
        error('method %s does not exist',Cases(i).Type);
    end
    if isnan(Cases(i).IdxOverride)
        [tmp_Lds,BinFolder] = obj.(Cases(i).Type)(Cases(i),i);
    else
        [tmp_Lds,BinFolder] = obj.(Cases(i).Type)(Cases(i),Cases(i).IdxOverride);
    end
    if i == 1
        Lds = tmp_Lds;
    else
        Lds = Lds | tmp_Lds;
    end
    if obj.CleanUp
        rmdir(BinFolder,"s")
    end
end
end

