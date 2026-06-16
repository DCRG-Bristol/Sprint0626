function [EWF,fs,ts] = MissionFraction(obj,Segments,opts)
    arguments
        obj TAW
        Segments cast.mission.Segment
        opts.M_TO = obj.MTOM;
        opts.OverideLD = false;
    end
    EWF = 1;   % empty weight fraction
    fs = zeros(1,length(Segments));
    ts = zeros(1,length(Segments));
    for i = 1:length(Segments)
        s = Segments(i);
        if isempty(obj.Thrust)
            TW = 0.3;
        else
            TW = obj.Thrust/(obj.MTOM*9.81);
        end
        switch class(s)
            case 'cast.mission.GroundOp'
                f = 1 - obj.Engine.TSFC(0,0)*9.81*(s.TaxiTime*obj.TW_idle + s.TakeOffTime*TW);  % Snorri Eq. 6-32 (p.155)
                t = s.TaxiTime + s.TakeOffTime;
            case 'cast.mission.Climb'
                [hs,M] = s.ClimbProperties();
                %calc properties in each section
                deltaH = hs(2:end)-hs(1:end-1);
                h_mean = (hs(2:end)-hs(1:end-1))/2;
                [rho,a] = ads.util.atmos(h_mean);
                M = (M(2:end)+M(1:end-1))/2;
                deltaf = 1;
                t = 0;
                for j = 1:length(deltaH)
                    if opts.OverideLD
                        CL_c = EWF*deltaf*opts.M_TO*9.81/(1/2*rho(j)*(a(j)*M(j))^2*obj.WingArea);
                        CD_c = obj.AeroSurrogate.Get_Cd(CL_c,M(j),FlightPhase.Cruise);
                        LD_c = CL_c/CD_c;
                    else
                        LD_c = obj.LD_c;
                    end
                    TW = 1/(LD_c)+s.ROC/(M(j)*a(j));
                    deltaf = deltaf*(1 - deltaH(j)*obj.Engine.TSFC(M(j),h_mean(j))*9.81*TW/s.ROC); % Snorri Eq. 6-34 (p. 155)
                    t = t + deltaH(j)/s.ROC;
                end      
                f = deltaf;        
            case 'cast.mission.Cruise'
                [rho,a,~,P] = ads.util.atmos(s.StartAlt);
                [rho_s,a_s,~,P_s] = ads.util.atmos(0);
                VCAS = ads.util.calibrated_airspeed(s.Mach,P,P_s,a_s,1.4);
                if ~isnan(s.CAS) && VCAS>s.CAS
                    TAS = ads.util.equivelent_true_airspeed(P,rho,P_s,rho_s,1.4,s.CAS);
                    M_cruise = TAS/a;
                else
                    M_cruise = s.Mach;
                end
                if opts.OverideLD
                    CL_c = EWF*opts.M_TO*9.81/(1/2*rho*(a*M_cruise)^2*obj.WingArea);
                    CD_c = obj.AeroSurrogate.Get_Cd(CL_c,M_cruise,FlightPhase.Cruise);
                    LD_c = CL_c/CD_c;
                else
                    LD_c = obj.LD_c;
                end
                f = exp(-s.Range*9.81*obj.Engine.TSFC(M_cruise,s.StartAlt)/(M_cruise*a*LD_c));        % Rearranged Brequet
                t = s.Range/(M_cruise*a);
            case 'cast.mission.Decent'

                [hs,M] = s.DecentProperties();
                deltaH = abs(hs(2:end)-hs(1:end-1));
                h_mean = (hs(2:end)+hs(1:end-1))/2;
                M = (M(2:end)+M(1:end-1))/2;

                deltaf = 1;
                TW = obj.TW_idle; % assume idle power
                t = 0;
                for j = 1:length(deltaH)
                    deltaf = deltaf * (1-abs(deltaH(j))*obj.Engine.TSFC(M(j),h_mean(j))*9.81*TW/s.ROC);              % Snorri Eq. 6-34 (p. 155)
                    t = t + abs(deltaH(j))/s.ROC;
                end
                f = deltaf;
            case 'cast.mission.Loiter'
                [rho,a,~,P] = ads.util.atmos(s.StartAlt);
                if opts.OverideLD
                    CL = EWF*opts.M_TO*9.81/(1/2*rho*(a*s.Mach)^2*obj.WingArea);
                    CD = obj.AeroSurrogate.Get_Cd(CL,s.Mach,FlightPhase.Cruise);
                    LD = CL/CD;
                else
                    LD = obj.LD_app;
                end
                f = exp(-s.Time*9.81*obj.Engine.TSFC(s.Mach,s.StartAlt)/LD);
                t = s.Time;
            case 'cast.mission.Contingency'
                % assumes all sections prior make up trip fuel and add 5 minutes 
                % loiter or 3% trip fuel, whichever is higher
                [rho,a] = ads.util.atmos(s.StartAlt);
                if opts.OverideLD
                    CL = EWF*opts.M_TO*9.81/(1/2*rho*(a*s.Mach)^2*obj.WingArea);
                    CD = obj.AeroSurrogate.Get_Cd(CL,s.Mach,FlightPhase.Cruise);
                    LD = CL/CD;
                else
                    LD = obj.LD_app;
                end
                % calc fuel for 5 minute loiter
                f1 = exp(-s.Time*9.81*obj.Engine.TSFC(0.3,5e3./cast.SI.ft)/LD);
                % calc 5% of current fuel burn
                df = (1-EWF)*0.03;
                f2 = 1-df/EWF;
                f = max(f1,f2);
                t = s.Time;
            case 'cast.mission.Nothing'
                f = 1;
                t = 0;
        end
        fs(i) = f;
        ts(i) = t;
        EWF = EWF*f;
    end
end