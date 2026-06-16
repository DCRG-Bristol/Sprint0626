classdef (Abstract) AbstractPolar
    methods (Abstract)
        Cd0  = Get_Wing_Cd0(obj)
        Cd = Get_Cd(obj,Cl,M,Phase)
    end
end

