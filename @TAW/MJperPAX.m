function [doc,M_f,trip_fuel,trip_time,block_fuel] = MJperPAX(obj,range,payloadFactor,opts)
arguments
    obj
    range
    payloadFactor
    opts.M_f = obj.MTOM-obj.ADR.Payload-obj.OEM;
end
[M_f,trip_fuel,trip_time,doc,block_fuel] = deal(zeros(size(range)));
if length(payloadFactor) == 1
    payloadFactor = ones(size(range))*payloadFactor;
elseif length(payloadFactor) ~= length(range)
    error('payloadfactor must have length of 1 or the same length as range')
end
for i = 1:length(range)
    mission = cast.Mission.StandardWithAlternate(obj.ADR,range(i));
    M_to = 0;
    if i == 1
        M_f(i) = opts.M_f;
    else
        M_f(i) = M_f(i-1);
    end
    while abs(M_to-(obj.OEM+obj.ADR.Payload*payloadFactor(i)+M_f(i)))>10
        M_to = obj.OEM+obj.ADR.Payload*payloadFactor(i)+M_f(i);
        [EWF,fs,ts] = obj.MissionFraction(mission.Segments,M_TO=M_to,OverideLD=true);
        M_f(i) =  (1-EWF)/(EWF)*(obj.OEM+obj.ADR.Payload*payloadFactor(i));
    end
    trip_fuel(i) = (1-prod(fs(1:6)))*M_to;
    block_fuel(i) = (1-prod(fs))*M_to;
    trip_time(i) = sum(ts(1:6));
    doc(i) = trip_fuel(i)*obj.FuelType.SpecificEnergy/(obj.ADR.PAX*payloadFactor(i))/(range(i));
end
end