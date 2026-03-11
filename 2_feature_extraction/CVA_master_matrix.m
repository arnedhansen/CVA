%% CVA_master_matrix
%
% Merges all feature tables into one master matrix for statistical analysis.
% Subjects missing any variable required for modelling are excluded.
%
% Output: paths.master/CVA_master_matrix.mat + CVA_master_matrix.csv
%   master: table with columns:
%     [subID, age_bin, age_group, sex,
%      CSF, GM, WM, TBV, TIV, CSF_TIV, GM_TIV, WM_TIV,
%      skull_thickness_mm,
%      IAF, alpha_power, gfp_mean, gfp_alpha]
%
% TIV-corrected variables (% of TIV) enter statistical models:
%   CSF_TIV, GM_TIV, WM_TIV
% Raw volumes are retained for descriptive reporting only.

%% Setup
startup
[~, paths, ~, ~] = setup('CVA');

%% Load feature tables
load(fullfile(paths.demo_fex, 'CVA_demographics.mat'),    'demo_out');
load(fullfile(paths.mri_fex,  'CVA_mri_volumes.mat'),     'vol_out');
load(fullfile(paths.mri_fex,  'CVA_skull_thickness.mat'), 'skull_out');
load(fullfile(paths.eeg_fex,  'CVA_alpha_power.mat'),     'alpha_out');
load(fullfile(paths.eeg_fex,  'CVA_gfp.mat'),             'gfp_out');

% Normalize schemas for robust joins
demo_out  = ensure_id_and_vars(demo_out,  {'age_bin','sex','age_group'});
vol_out   = ensure_id_and_vars(vol_out,   {'TBV','GM','WM','CSF','TIV', ...
                                            'CSF_TIV','GM_TIV','WM_TIV'});
skull_out = ensure_id_and_vars(skull_out, {'skull_thickness_mm'});
alpha_out = ensure_id_and_vars(alpha_out, {'IAF','alpha_power'});
gfp_out   = ensure_id_and_vars(gfp_out,  {'gfp_mean','gfp_alpha'});

%% Merge
master = demo_out;
master = outerjoin(master, vol_out,   'Keys','subID','MergeKeys',true);
master = outerjoin(master, skull_out, 'Keys','subID','MergeKeys',true);
master = outerjoin(master, alpha_out, 'Keys','subID','MergeKeys',true);
master = outerjoin(master, gfp_out,   'Keys','subID','MergeKeys',true);

%% Exclude subjects missing any model variable
modelVars = {'CSF_TIV','GM_TIV','WM_TIV','skull_thickness_mm', ...
             'IAF','alpha_power','gfp_mean','gfp_alpha'};

nBefore     = height(master);
missingMask = any(ismissing(master(:, modelVars)), 2);
nExcluded   = sum(missingMask);
fprintf('%d/%d subjects excluded due to missing model variables.\n', ...
    nExcluded, nBefore);
master(missingMask, :) = [];

if height(master) == 0 && nBefore > 0
    warning(['Master matrix is empty after exclusion. ', ...
             'Check upstream modality outputs (most often CAT12).']);
end

%% Descriptive summary
nYoung = sum(strcmp(master.age_group, 'young'));
nOld   = sum(strcmp(master.age_group, 'old'));
fprintf('\nFinal N = %d  (young: %d, old: %d)\n', height(master), nYoung, nOld);
fprintf('CSF/TIV:  M=%.2f%%  SD=%.2f%%  [%.2f, %.2f]\n', ...
    mean(master.CSF_TIV), std(master.CSF_TIV), ...
    min(master.CSF_TIV),  max(master.CSF_TIV));
fprintf('GM/TIV:   M=%.2f%%  SD=%.2f%%\n', mean(master.GM_TIV),  std(master.GM_TIV));
fprintf('WM/TIV:   M=%.2f%%  SD=%.2f%%\n', mean(master.WM_TIV),  std(master.WM_TIV));
fprintf('Skull:    M=%.2fmm  SD=%.2fmm\n', ...
    mean(master.skull_thickness_mm), std(master.skull_thickness_mm));
fprintf('Alpha:    M=%.4g  SD=%.4g\n', mean(master.alpha_power), std(master.alpha_power));
fprintf('GFP:      M=%.4g  SD=%.4g\n', mean(master.gfp_mean),   std(master.gfp_mean));

%% Save
outMat = fullfile(paths.master, 'CVA_master_matrix.mat');
outCSV = fullfile(paths.master, 'CVA_master_matrix.csv');
save(outMat, 'master');
writetable(master, outCSV);
fprintf('\nMaster matrix saved: N=%d → %s\n', height(master), outCSV);

CVA_log_event('master_matrix', 'summary', struct( ...
    'n_before',   nBefore, ...
    'n_excluded', nExcluded, ...
    'n_final',    height(master), ...
    'n_young',    nYoung, ...
    'n_old',      nOld, ...
    'output_csv', outCSV));

% -------------------------------------------------------------------------
function T = ensure_id_and_vars(T, requiredVars)
if ~istable(T)
    error('Expected a table as input.');
end

if ~ismember('subID', T.Properties.VariableNames)
    varNames  = T.Properties.VariableNames;
    normNames = lower(regexprep(varNames, '[^a-zA-Z0-9]', ''));
    idIdx     = find(contains(normNames, 'subid') | ...
                     contains(normNames, 'participantid') | ...
                     strcmp(normNames, 'id'), 1);
    if ~isempty(idIdx)
        varNames{idIdx} = 'subID';
        T.Properties.VariableNames = varNames;
    elseif width(T) == 0
        T.subID = cell(0,1);
    else
        error('Could not identify subject ID column.');
    end
end

if isstring(T.subID)
    T.subID = cellstr(T.subID);
elseif iscategorical(T.subID)
    T.subID = cellstr(string(T.subID));
elseif isnumeric(T.subID)
    T.subID = cellstr(string(T.subID));
end

for i = 1:numel(requiredVars)
    v = requiredVars{i};
    if ismember(v, T.Properties.VariableNames), continue; end
    if ismember(v, {'age_group','age_bin'})
        T.(v) = repmat({''}, height(T), 1);
    else
        T.(v) = NaN(height(T), 1);
    end
end
end
