if opts.ArtificialForce
    for j = 1:length(obj.MainWingRHS)
        obj.MainWingRHS(j).DistributeForce(nan,Force=[0 0 0],tag='ArtLiftRHS',BeamOffset=0.15,Etas=obj.MainWingRHS(j).Stations.Eta);
    end
    for j = 1:length(obj.MainWingLHS)
        obj.MainWingLHS(j).DistributeForce(nan,Force=[0 0 0],tag='ArtLiftRHS',BeamOffset=0.15,Etas=obj.MainWingLHS(j).Stations.Eta);
    end
end