classdef NastranModel < cast.ADP & cast.nast.LoadsSurrogate
    %TAW Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        WingboxEtas = [0.15,0.65];
        Taw TAW
    end
    %jig twist
    properties
        UpdateJigTwist logical = true;

        PrandtlFactor double = 0; % zero targets elipse, one targets bell distribution
        UseJones logical = false; % whether to use jones lift distribtion
        JonesFactor double = 1; % one targets elipse, less than one goes from triangular to bell

    end
    properties
        GravVector = [0;0;-1];
        g = 9.81;
    end

    properties
        Tags
    end
    methods
        function val = get.Tags(obj)
            val = obj.getTag();
        end
    end
    methods (Access=protected)
        function val = getTag(obj)
            if ~isnan(obj.Taw.HingeEta) && obj.Taw.HingeEta<1
                val = {["Wing_Connector_RHS","Wing_Connector_LHS"],["Wing_RHS","Wing_LHS"],["FFWT_RHS","FFWT_LHS"]};
            else
                val = {["Wing_Connector_RHS","Wing_Connector_LHS"],["Wing_RHS","Wing_LHS"]};
            end
        end
    end
    
    methods
        function obj = NastranModel(Taw)
            arguments
                Taw TAW
            end
            obj.Taw = Taw;
            obj.Verbose = false;
            obj.BinFolder = "bin_aem";
        end
    end
end
