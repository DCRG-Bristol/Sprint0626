function ApplyWingParams(obj,Par)
arguments
    obj
    Par = []
end
if isempty(obj.Baff)
    error('No Baff Model generated')
end
if ~isempty(Par)
    obj.WingBoxParams = Par;
end
%% apply properties to the wings
obj.Masses.PrimaryWingMass = 0;
obj.Masses.SecondaryWingMass = 0;
obj.Masses.ConnectorMass = 0;
for i = 1:length(obj.WingBoxParams)
    [Area,Iyy, Izz, J] = obj.WingBoxParams(i).BeamCondensation;
    Masses = obj.WingBoxParams(i).GetMass;
    %divide stiffner + fixtures mass amougst ribs
    eta = Masses.Ribs./sum(Masses.Ribs);
    % update primary and secondary mass
    if contains(obj.Baff.Wing(obj.WingBoxParams(i).Index(1)).Name,"Connector")
        obj.Masses.ConnectorMass = obj.Masses.ConnectorMass + Masses.Total*2;% + obj.MTOM*0.0003*2.5*1.5;
%         SecMass = Masses.Ribs + eta.*(Masses.Web_stiff_total + obj.MTOM*0.0003*2.5*1.5/2 + Masses.Total*0.4);
        SecMass = 0;% + obj.MTOM*0.0003*2.5*1.5/2);
    else
        obj.Masses.PrimaryWingMass = obj.Masses.PrimaryWingMass + Masses.Total*2;
        switch obj.SecondaryMethod
            case "Prop"
                SecMass = 0.7376*Masses.Total;
            case "Planform"
                RefMass = ads.util.tern(~isnan(obj.RefMass),obj.RefMass,obj.MTOM);
                % penalty for non-ideal tapering of skin etc...
                tmp_wing = obj.Baff.Wing(obj.WingBoxParams(i).Index(1));
                S = tmp_wing.PlanformArea; 
                M_nid = 1.2*1e-3*obj.WingBoxParams(i).Mat.rho*S; %Eq. 11.55
                % penalty for Damage tolerance
                M_nid = M_nid + 0.15*Masses.SparWeb; % Eq 11.56
                % penalty for manhole covers
                R = 1+2*0.25*tmp_wing.GetBeamLength/S;
                M_nid = M_nid + Masses.Skin/2*R;
                if contains(obj.Baff.Wing(obj.WingBoxParams(i).Index(1)).Name,"Wing_")
                    % assuming this section has all control surfaces
                    SecMass = EstimateSecondaryMass(obj,tmp_wing,0.9,0.2*obj.WingArea/2,0.05*obj.WingArea/2,obj.FowlerSlots,RefMass);
                    % penalty for Engine mount
                    eng = tmp_wing.Children(find(contains([tmp_wing.Children.Name],'engine'),1));
                    if ~isempty(eng)
                        M_nid = M_nid + 0.015*(1+0.2*1)*eng.GetMass();
                    end
                    % penaly for landing gear 
                    M_nid = M_nid + 0.006 * obj.Mf_Ldg*RefMass;
                    %penalty for wing fuselage conenction 
                    M_nid = M_nid + 0.0003 * 1.5*2.5 * RefMass;
                else
                    SecMass = EstimateSecondaryMass(obj,tmp_wing,0,0,0,1,RefMass);
                end
                SecMass = SecMass + M_nid;
        end
        % apply additional masses to the structure
        obj.Masses.SecondaryWingMass = obj.Masses.SecondaryWingMass + SecMass*2;
    end
    SecMass = Masses.Ribs + eta.*(Masses.Web_stiff_total + SecMass);
    if any(isnan(SecMass))
        error('NaN Sec mass')
    end
    for j = 1:length(obj.WingBoxParams(i).Index)
        tmp_wing = obj.Baff.Wing(obj.WingBoxParams(i).Index(j));
        % assign cross-section properties
        I_tmp = permute([Iyy + Izz;Iyy;Izz],[1,3,2]).*eye(3);
        tmp_wing.Stations.A = Area.cross_section;
        tmp_wing.Stations.I = I_tmp;
        tmp_wing.Stations.J = J;
        % assign Additional masses
        idx = find(contains([tmp_wing.Children.Name],string(['ribs_',num2str(j),'_'])));
        
        if isempty(idx)
            warning('No ribs found')
        end
        if length(idx)~=length(eta)
            warning('havent found enough ribs')
        end
        for k = 1:length(idx)
            tmp_wing.Children(idx(k)).mass = SecMass(k);
        end
    end
end
obj.WingMass =  obj.Masses.PrimaryWingMass + obj.Masses.SecondaryWingMass + obj.Masses.WingletMass;
end