function obj = UpdateAeroEstimates(obj)
    % obj.AeroSurrogate = aero.NitaPolar(obj);
    obj.AeroSurrogate = aero.NitaShevellPolar(obj);
end

