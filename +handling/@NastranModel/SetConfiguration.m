function SetConfiguration(obj,opts,Lopts)
%SETCONFIGURATION Summary of this function goes here
%   Detailed explanation goes here
arguments
    obj
    opts.FuelMass = obj.Taw.MTOM*obj.Taw.Mf_Fuel;
    opts.PayloadFraction = 1;
    opts.IsLocked = true;
    Lopts.NChord = 5;
end
optsCell = namedargs2cell(opts);
obj.Taw.SetConfiguration(optsCell{:});

obj.ToFE('GenAero',true,'NChord',Lopts.NChord);
if obj.Taw.HingeEta<1
    for i = 1:2
        obj.fe.Hinges(i).isLocked = opts.IsLocked;
    end
end
end

