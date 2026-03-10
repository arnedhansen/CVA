%% CVA_master_matrix
%
% Merges all feature tables into one master matrix for statistical analysis.
% Subjects missing any modality are flagged and excluded.
%
% Output: dirs.fex/CVA_master_matrix.mat + CVA_master_matrix.csv
%   master: table with columns:
%     [subID, age_mid, age_group, sex,
%      CSF, GM, WM, TBV, skull_thickness_mm,
%      IAF, alpha_power, gfp_mean, gfp_alpha]

%% Setup
dirs = CVA_paths();

%% Load feature tables
load(fullfile(dirs.fex, 'CVA_demographics.mat'),    'demo_out');
load(fullfile(dirs.fex, 'CVA_mri_volumes.mat'),     'vol_out');
load(fullfile(dirs.fex, 'CVA_skull_thickness.mat'), 'skull_out');
load(fullfile(dirs.fex, 'CVA_alpha_power.mat'),     'alpha_out');
load(fullfile(dirs.fex, 'CVA_gfp.mat'),             'gfp_out');

%% Merge
master = demo_out;
master = outerjoin(master,    vol_out,   'Keys','subID','MergeKeys',true);
master = outerjoin(master,  skull_out,   'Keys','subID','MergeKeys',true);
master = outerjoin(master,  alpha_out,   'Keys','subID','MergeKeys',true);
master = outerjoin(master,    gfp_out,   'Keys','subID','MergeKeys',true);

%% Flag incomplete rows
nVars     = {'CSF','GM','WM','TBV','skull_thickness_mm','IAF','alpha_power','gfp_mean','gfp_alpha'};
missingMask = any(ismissing(master(:, nVars)), 2);
fprintf('%d subjects excluded due to missing data.\n', sum(missingMask));
master(missingMask, :) = [];

%% Report
fprintf('Final N = %d  (young: %d, old: %d)\n', ...
    height(master), ...
    sum(strcmp(master.age_group,'young')), ...
    sum(strcmp(master.age_group,'old')));

%% Save
outMat = fullfile(dirs.fex, 'CVA_master_matrix.mat');
outCSV = fullfile(dirs.fex, 'CVA_master_matrix.csv');
save(outMat, 'master');
writetable(master, outCSV);
fprintf('Master matrix saved: N=%d subjects.\n', height(master));
