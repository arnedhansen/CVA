%% CVA_demographics
%
% Loads participant demographics from LEMON CSV and aligns to subject list.
% Age bins are converted to numeric midpoints. Sex coded as 1=female, 2=male.
%
% Output: dirs.fex/CVA_demographics.mat
%   demo_out: table with columns [subID, age_mid, sex, age_group]

%% Setup
dirs = CVA_paths();

%% Load CSV
demo = readtable(dirs.demo, 'Delimiter', ',');
% Expected columns: ID, Gender_1=female_2=male, Age

%% Rename for clarity
demo.Properties.VariableNames = {'subID', 'sex', 'age_bin'};

%% Convert age bin to numeric midpoint
% Bins observed: '20-25','25-30','30-35','60-65','65-70' etc.
ageMid = zeros(height(demo), 1);
for i = 1:height(demo)
    parts      = strsplit(demo.age_bin{i}, '-');
    ageMid(i)  = mean([str2double(parts{1}), str2double(parts{2})]);
end
demo.age_mid = ageMid;

%% Assign age group
demo.age_group = repmat({'young'}, height(demo), 1);
demo.age_group(demo.age_mid >= 55) = {'old'};

%% Save
demo_out = demo;
outFile  = fullfile(dirs.fex, 'CVA_demographics.mat');
save(outFile, 'demo_out');
fprintf('Saved demographics for %d subjects.\n', height(demo_out));
