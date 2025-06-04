load('LiftDistData.mat')
res = struct.empty;
for i = 1:length(data)
    res = dcrg.struct.concat(res,data{i});
end