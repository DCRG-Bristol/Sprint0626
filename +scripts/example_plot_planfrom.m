load('C:\git\Sprint0626\example_data\UB321_simple.mat')
ADP.BuildBaff();

% extract correct wing elements (could do something clever with name lookup...)
Wings = ADP.Baff.Wing;

f = figure(1);
clf;
hold on

% for each wing plot the LE and TE points at each Aerodyanmic station
for i = 1:length(Wings)
    % get number of stations
    N = numel(Wings(i).AeroStations);
    Xs = zeros(3,2*N+1); % pre-allocate array
    % assign LE and TE points
    etas = [Wings(i).AeroStations.Eta];
    Xs(:,1:N) = Wings(i).GetGlobalWingPos(etas,0);
    Xs(:,N+1:2*N) = Wings(i).GetGlobalWingPos(fliplr(etas),1);
    %repeat first point
    Xs(:,end) = Xs(:,1);
    %plot wing
    plot(Xs(2,:),Xs(1,:),'k-')
end
% tidy plot
axis equal
xlabel('Y [m]')
ylabel('X [m]')
ax = gca;
ax.YDir = "reverse";
