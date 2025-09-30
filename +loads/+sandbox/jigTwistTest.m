clear all;fclose all;
load('example_data\A220_simple.mat')

% build Nastran Object
ld = loads.NastranModel(ADP);
ld.BinFolder = 'bin_jig';


% build load case
config = struct();
config.FuelMass = ld.Taw.MTOM*ld.Taw.Mf_Fuel;
config.PayloadFraction = 1;
config.IsLocked = true;
tmpCase = util.JigTwistSizingCase(ld.Taw.ADR.M_c,ld.Taw.ADR.Alt_cruise.*cast.SI.ft,Config=config,SafetyFactor=1,Idx=99);

% tic;
% [Lds,BinFolder] = ld.JigTwistSizing(tmpCase,99); % ~38 seconds
% toc;


tic;
[Lds,BinFolder] = ld.JigTwistSizing2(tmpCase,99,Silent=true,TruelySilent=true);
toc;



