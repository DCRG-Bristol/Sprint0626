classdef SizingOpts < cast.nast.Opts
    %SIZINGOPTS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        %Configuration options
        DisableTanks = false;
        PayloadFraction = 1;
        IncludeJigTwistOpt = true;

        % Load Cases Options
        SafetyFactor = 1.5;
        useDLM = true
        IncludeGusts = true;
        IncludeTurb = true;
        IncludeGround = true;
        IncludePosG = true;
        IncludeZeroFuel = true;
        IncludeNegG = true;
        Include1G = false;
        PosManoG = 2.5;
        NegManoG = -1;
        SubHarmonic = [nan,nan];
    end
    
    methods
        function newObj = groundOnly(obj)
            newObj = obj;
            newObj.IncludeGusts = false;
            newObj.IncludeTurb = false;
            newObj.IncludeGround = true;
            newObj.IncludePosG = false;
            newObj.IncludeZeroFuel = false;
            newObj.IncludeNegG = false;
        end
        function newObj = GustAndTurb(obj,bool)
            newObj = obj;
            newObj.IncludeGusts = bool;
            newObj.IncludeTurb = bool;
        end
        function newObj = excludeGround(obj)
            newObj = obj;
            newObj.IncludeGround = false;
        end
        function newObj = failureCase(obj)
            newObj = obj;
            newObj.SafetyFactor = 1;
        end
        function newObj = SetParams(obj,opts)
            arguments
                obj 
                opts.DisableTanks = obj.DisableTanks;
                opts.PayloadFraction = obj.PayloadFraction;
                opts.IncludeJigTwistOpt = obj.IncludeJigTwistOpt;
                opts.SafetyFactor = obj.SafetyFactor;
                opts.useDLM = obj.useDLM;
                opts.IncludeGusts = obj.IncludeGusts;
                opts.IncludeTurb = obj.IncludeTurb;
                opts.IncludeGround = obj.IncludeGround;
                opts.IncludePosG = obj.IncludePosG;
                opts.IncludeZeroFuel = obj.IncludeZeroFuel;
                opts.IncludeNegG = obj.IncludeNegG;
                opts.Include1G = obj.Include1G;
                opts.PosManoG = obj.PosManoG;
                opts.NegManoG = obj.NegManoG;
                opts.SubHarmonic = obj.SubHarmonic;
                opts.WingboxMaxStep = obj.WingboxMaxStep;
                opts.WingboxConvergence = obj.WingboxConvergence;
                opts.NGoldenSection = obj.NGoldenSection;
                opts.CleanUp = obj.CleanUp;
                opts.BinFolder = obj.BinFolder;
                opts.Verbose = obj.Verbose;
                opts.Silent = obj.Silent;
            end
            newObj = obj;
            newObj.DisableTanks = opts.DisableTanks;
            newObj.PayloadFraction = opts.PayloadFraction;
            newObj.IncludeJigTwistOpt = opts.IncludeJigTwistOpt;
            newObj.SafetyFactor = opts.SafetyFactor;
            newObj.useDLM = opts.useDLM;
            newObj.IncludeGusts = opts.IncludeGusts;
            newObj.IncludeTurb = opts.IncludeTurb;
            newObj.IncludeGround = opts.IncludeGround;
            newObj.IncludePosG = opts.IncludePosG;
            newObj.IncludeZeroFuel = opts.IncludeZeroFuel;
            newObj.IncludeNegG = opts.IncludeNegG;
            newObj.Include1G = opts.Include1G;
            newObj.PosManoG = opts.PosManoG;
            newObj.NegManoG = opts.NegManoG;
            newObj.SubHarmonic = opts.SubHarmonic;
            newObj.WingboxMaxStep = opts.WingboxMaxStep;
            newObj.WingboxConvergence = opts.WingboxConvergence;
            newObj.NGoldenSection = opts.NGoldenSection;
            newObj.CleanUp = opts.CleanUp;
            newObj.BinFolder = opts.BinFolder;
            newObj.Verbose = opts.Verbose;
            newObj.Silent = opts.Silent;
        end
        function obj = SizingOpts(opts)
            arguments
                opts.DisableTanks = false;
                opts.PayloadFraction=1;
                opts.IncludeJigTwistOpt = true;
                opts.SafetyFactor = 1.5;
                opts.useDLM = true
                opts.IncludeGusts = true;
                opts.IncludeTurb = true;
                opts.IncludeGround = true;
                opts.IncludePosG = true;
                opts.IncludeZeroFuel = true;
                opts.IncludeNegG = true;
                opts.Include1G = false;
                opts.PosManoG = 2.5;
                opts.NegManoG = -1;
                opts.WingboxMaxStep = 1;
                opts.NGoldenSection = 10;
                opts.WingboxConvergence = 0.25;
                opts.SubHarmonic = [nan,nan];
                opts.CleanUp = true;
                opts.BinFolder ='';
                opts.Verbose = false;
                opts.Silent = false;
            end
            obj.DisableTanks  = opts.DisableTanks;
            obj.PayloadFraction = opts.PayloadFraction;
            obj.IncludeJigTwistOpt = opts.IncludeJigTwistOpt;
            obj.SafetyFactor = opts.SafetyFactor;
            obj.useDLM = opts.useDLM;
            obj.IncludeGusts = opts.IncludeGusts;
            obj.IncludeTurb = opts.IncludeTurb;
            obj.IncludeGround = opts.IncludeGround;
            obj.IncludePosG = opts.IncludePosG;
            obj.IncludeZeroFuel = opts.IncludeZeroFuel;
            obj.IncludeNegG = opts.IncludeNegG;
            obj.Include1G = opts.Include1G;
            obj.PosManoG = opts.PosManoG;
            obj.NegManoG = opts.NegManoG;
            obj.WingboxMaxStep = opts.WingboxMaxStep;
            obj.NGoldenSection = opts.NGoldenSection;
            obj.WingboxConvergence = opts.WingboxConvergence;
            obj.SubHarmonic = opts.SubHarmonic;
            obj.CleanUp = opts.CleanUp ;
            obj.BinFolder = opts.BinFolder;
            obj.Verbose = opts.Verbose;
            obj.Silent = opts.Silent;
        end
    end
end

