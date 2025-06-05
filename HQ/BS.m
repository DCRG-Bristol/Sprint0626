
data1 = load('C:\Matlab_workspace\Sprint0626\SM_Data1.mat');
data2 = load('C:\Matlab_workspace\Sprint0626\SM_Data2.mat');
data3 = load('C:\Matlab_workspace\Sprint0626\SM_Data3.mat');

data_set1 = data1.Data_record;
data_set2 = data2.Data_record1;
data_set3 = data3.Data_record1;


data_set1( ~any(data_set1,2), : ) = [];  
data_set2( ~any(data_set2,2), : ) = []; 
data_set3( ~any(data_set3,2), : ) = []; 

data_all = [data_set1; data_set2; data_set3];

input = data_all(:,1:3); 
output = data_all(:,4);

x_interp = scatteredInterpolant(input, reshape(output, [], 1));

test_out = x_interp(10,15, 0.7);