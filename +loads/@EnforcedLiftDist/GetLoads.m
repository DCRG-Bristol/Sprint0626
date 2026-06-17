function [Lds] = GetLoads(obj,Cases)
arguments
    obj
    Cases (:,1) cast.LoadCase % Load Cases to run
end
dcrg.printing.title('Calculating Enforced Loads',Length=60);

for i = 1:length(Cases)
    % if ~obj.Silent
        dcrg.printing.title(sprintf('Running Case %s',Cases(i).Name),Length=60,Symbol='+');
    % end
    cellArgs = namedargs2cell(Cases(i).ConfigParams);
    obj.SetConfiguration(cellArgs{:});
    if ~ismethod(obj,Cases(i).Type)
        error('method %s does not exist',Cases(i).Type);
    end
    idx = dcrg.tern(isnan(Cases(i).IdxOverride),i,Cases(i).IdxOverride);
    tmp_Lds = obj.(Cases(i).Type)(Cases(i),idx);
    if i == 1
        Lds = tmp_Lds;
    else
        Lds = Lds | tmp_Lds;
    end
end
end

