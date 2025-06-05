function [Lds,BinFolder] = JigTwistSizing(obj,Case,idx,opts,RunOpts)
arguments
    obj
    Case cast.LoadCase
    idx

    opts.MaxIter = 20           % Max iterations
    opts.TargetDelta = 0.01     % target mean twist change
    opts.TargetAoA = 3;         % target trim AoA
    opts.Verbose = true;
    
    RunOpts.NumAttempts = 1
    RunOpts.Silent = true;
    RunOpts.TruelySilent = true;
end
% get dynamic pressure
[rho,a,T,P,~,~,~] = ads.util.atmos(convlength(Case.Alt,'ft','m'));
V = a*Case.Mach;
q = 0.5*rho*V^2;

ads.util.printing.title('Jig Twist Optimisation',Length=60,Symbol='~');
deltas = ones(1,opts.MaxIter+1)*inf;

for i = 1:opts.MaxIter+1
    %create model
    cellArgs = namedargs2cell(Case.ConfigParams);
    obj.SetConfiguration(cellArgs{:});
    %run Nastran
    optsCell = namedargs2cell(RunOpts);
    BinFolder = obj.Sol144(Case.Mach,Case.Alt,Case.LoadFactor,optsCell{:});
    filename = fullfile(BinFolder,'bin','sol144.h5');
    %extract trimAoA
    resFile = mni.result.hdf5(filename);
    tRes = resFile.read_trim;
    AoA = rad2deg(tRes.ANGLEA);
    % extract lift Distribution
    [ys,~,~,Fs,~,~,chords] = util.get_lift_dist(obj,resFile,[[obj.Taw.MainWingRHS.Name],[obj.Taw.MainWingLHS.Name]]);
    eta = ys./max(ys); %normalise span

    % Fs_norm = interp1(eta,Fs,obj.RefEta);
    if obj.UseJones
        % scale by area
        A = trapz(eta,Fs)/trapz(eta,gamma_jones(eta,obj.JonesFactor));
        % scale at a specified eta
        %         A = Fs_norm./gamma_jones(obj.RefEta,obj.JonesFactor);
        %get target distribution
        target_lift = A.*gamma_jones(eta,obj.JonesFactor);
    else % use prandtl
        % scale by area
        A = trapz(eta,Fs)/trapz(eta,gamma_prandtl(eta,obj.PrandtlFactor));
        % scale at a specified eta
        %         A = Fs_norm./gamma_prandtl(obj.RefEta,obj.PrandtlFactor);
        %get target distribution
        target_lift = A.*gamma_prandtl(eta,obj.PrandtlFactor);
    end
    %get delta between two distributions
    delta = target_lift-(Fs);
    % re-nomralised eta so that zero at wing root and 1 at tip
    e_i = ys>=0;
    etas = eta(e_i);
    %convert delta into a required change in angle (assuming a local lift-curve-slope of 2pi)
    delta_angle = rad2deg(delta(e_i)./(q.*chords(e_i)*2*pi));
    delta_aoa = AoA-opts.TargetAoA;
    deltas(i) = max(abs(delta_angle).*(Fs(e_i)./max(Fs(e_i))));
    if deltas(i)<opts.TargetDelta && delta_aoa<opts.TargetDelta
        ads.util.printing.title(sprintf('Jig Twist Complete! Delta %0.3f deg. AoA %0.2f deg',deltas(i),AoA),Length=60,Symbol='~');
        break
    elseif i>1 && delta_aoa<opts.TargetDelta && abs(deltas(i)-deltas(i-1))<opts.TargetDelta/2 %close enough
        ads.util.printing.title(sprintf('Jig Twist Converged! Delta %0.3f deg. AoA %0.2f deg',deltas(i),AoA),Length=60,Symbol='~');
        break
    elseif i == opts.MaxIter+1
        ads.util.printing.title(sprintf('Warning Jig Twist Max Step Reached! Delta %0.3f deg',deltas(i)),Length=60,Symbol='!');
        error('CAST:SizingError','Jig Twist Sizing did not converge.')
    end
    if opts.Verbose
        ads.util.printing.title(sprintf('Jig Twist Step %.0f. Delta %0.3f deg. AoA %0.2f deg',i,deltas(i),AoA),Length=60,Symbol='~');
    end
    if i>1 && abs(deltas(i)-deltas(i-1))<0.05 && abs(delta_aoa)>0.05
        %focus on AoA
        delta_angle = delta_aoa;
    else
        delta_angle = delta_angle + delta_aoa;
    end

    %extract current twist an add delta
    twists = -interp1(obj.Taw.InterpEtas,obj.Taw.InterpTwists,etas);
    target = twists+delta_angle;
    %apply to wing (extrapolate for root + tip to avoid quirks in distribution)
    obj.Taw.InterpEtas = 0:0.01:1;
    %     obj.InterpTwists = -interp1(etas,target,obj.InterpEtas,"linear","extrap");
    obj.Taw.InterpTwists = -interp1(etas,target,obj.Taw.InterpEtas,"linear","extrap");
    % obj.Taw.InterpTwists(end) = obj.Taw.InterpTwists(end-1);
    obj.Taw.InterpTwists(end) = 0;
    % obj.InterpTwists(obj.InterpEtas<eta(find(idx,1))) = target(find(idx,1));
    %smooth the curve
    %     obj.InterpTwists = polyval(polyfit(obj.InterpEtas,obj.InterpTwists,6),obj.InterpEtas);

    if opts.Verbose
        f = figure(11);
        clf;

        tt = tiledlayout(1,2);
        nexttile(1);
        scale = max(target_lift);
        plot(eta,target_lift./scale,'k--');
        hold on;
        plot(eta,Fs./scale,'b-');
        plot(eta,abs(delta)./max(abs(delta)),'r-')
        nexttile(2);
        plot(etas,twists,'k--');
        hold on
        plot(etas,target,'r-');
    end
end
%calc the loads for the last test run
Lds = obj.ExtractStaticLoads(filename,obj.Tags).abs() .* Case.SafetyFactor;
Lds = Lds.SetIdx(idx);

% set theoretical oswald efficency
% obj.e_theo = Lds(1).Meta.CL_wing^2/(pi*obj.Taw.AR*Lds(1).Meta.CDi_wing);
end

function G = gamma_jones(y,R)
a = (1-4*R/(3*pi))/(2*(1-4/(3*pi)));
b = R/2-a;
G = 2*(a+b/pi).*sqrt(1-y.^2) + 2*b./pi.*y.^2.*acosh(1./abs(y));
G(y==0) = 2*(a+b/pi);
end
function G = gamma_prandtl(y,R)
G = ((1-R.*y.^2).*sqrt(1-y.^2));
end

