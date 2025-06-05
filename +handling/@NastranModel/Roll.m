function [res,BinFolder] = Roll(obj,Mach,opts)
arguments
    obj handling.NastranModel
    Mach
    opts.Verbose = true;
    opts.IsLocked = true;
    opts.EV = false;
    opts.Alts = 60e3:-1e3:0;
    opts.ReleaseDoFs = [];
    opts.sol = 144
    opts.AilInput = 7;
end
obj.SetConfiguration(FuelMass=obj.Taw.MTOM*obj.Taw.Mf_Fuel*obj.Taw.Mf_TOC,IsLocked=opts.IsLocked)

% Static
if opts.sol == 144
[BinFolder,res] = obj.Roll144(Mach,NumAttempts=1,Silent=false,Alts=opts.Alts,AilDeflection=opts.AilInput);
elseif opts.sol == 146
    print('Missing SOL146')
else
    print('Choose a valid SOL (144 or 146)')
end


end