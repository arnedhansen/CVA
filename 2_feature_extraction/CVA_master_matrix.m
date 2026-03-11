%% CVA_master_matrix
%
% Merges all feature tables into one master matrix for statistical analysis.
% Subjects missing any modality are flagged and excluded.
%
% Output: paths.master/CVA_master_matrix.mat + CVA_master_matrix.csv
%   master: table with columns:
%     [subID, age_mid, age_group, sex,
%      CSF, GM, WM, TBV, TIV, CSF_TIV,
%      skull_thickness_mm,
%      IAF, alpha_power, gfp_mean, gfp_alpha]
%
% Statistical models use CSF_TIV (CSF as % of TIV) as the primary CSF
% predictor. Raw CSF and TIV are retained in the table for reporting
% descriptive statistics and for sanity checks.

%% Setup
startup
[~, paths, ~, ~] = setup('CVA');

%% Load feature tables
load(fullfile(paths.demo_fex, 'CVA_demographics.mat'),   'demo_out');
load(fullfile(paths.mri_fex,  'CVA_mri_volumes.mat'),    'vol_out');
load(fullfile(paths.mri_fex,  'CVA_skull_thickness.mat'),'skull_out');
load(fullfile(paths.eeg_fex,  'CVA_alpha_power.mat'),    'alpha_out');
load(fullfile(paths.eeg_fex,  'CVA_gfp.mat'),            'gfp_out');

% Normalize table schemas so joins remain stable even when some modalities
% have no rows (e.g., CAT12 not completed yet for the current subset).
demo_out  = ensure_id_and_vars(demo_out,  {'age_mid','sex','age_group'});
vol_out   = ensure_id_and_vars(vol_out,   {'TBV','GM','WM','CSF','TIV','CSF_TIV'});
skull_out = ensure_id_and_vars(skull_out, {'skull_thickness_mm'});
alpha_out = ensure_id_and_vars(alpha_out, {'IAF','alpha_power'});
gfp_out   = ensure_id_and_vars(gfp_out,  {'gfp_mean','gfp_alpha'});

%% Merge
master = demo_out;
master = outerjoin(master,  vol_out,   'Keys','subID','MergeKeys',true);
master = outerjoin(master,  skull_out, 'Keys','subID','MergeKeys',true);
master = outerjoin(master,  alpha_out, 'Keys','subID','MergeKeys',true);
master = outerjoin(master,  gfp_out,   'Keys','subID','MergeKeys',true);

%% Exclude subjects with missing data in any variable required for modelling
%
% CSF_TIV is the model predictor; raw CSF and TIV are kept for reporting
% but are not required to be non-missing independently (CSF_TIV missing
% implies either CSF or TIV was missing upstream).
modelVars = {'CSF_TIV','GM','WM','TBV','skull_thickness_mm', ...
             'IAF','alpha_power','gfp_mean','gfp_alpha'};

nBefore     = height(master);
missingMask = any(ismissing(master(:, modelVars)), 2);
nExcluded   = sum(missingMask);
fprintf('%d subjects excluded due to missing data in model variables.\n', nExcluded);
master(missingMask, :) = [];

if height(master) == 0 && nBefore > 0
    warning(['Master matrix is empty after exclusion. ', ...
             'This indicates missing upstream modality outputs ', ...
             '(most often CAT12 segmentation outputs).']);
end

%% Descriptive summary
nYoung = sum(strcmp(master.age_group, 'young'));
nOld   = sum(strcmp(master.age_group, 'old'));
fprintf('Final N = %d  (young: %d, old: %d)\n', height(master), nYoung, nOld);
fprintf('CSF/TIV:  M = %.2f%%  SD = %.2f%%  Range = [%.2f, %.2f]\n', ...
    mean(master.CSF_TIV), std(master.CSF_TIV), ...
    min(master.CSF_TIV),  max(master.CSF_TIV));
fprintf('Skull:    M = %.2f mm  SD = %.2f mm\n', ...
    mean(master.skull_thickness_mm), std(master.skull_thickness_mm));
fprintf('Alpha:    M = %.4g  SD = %.4g\n', ...
    mean(master.alpha_power), std(master.alpha_power));
fprintf('GFP:      M = %.4g  SD = %.4g\n', ...
    mean(master.gfp_mean), std(master.gfp_mean));

%% Save
outMat = fullfile(paths.master, 'CVA_master_matrix.mat');
outCSV = fullfile(paths.master, 'CVA_master_matrix.csv');
save(outMat, 'master');
writetable(master, outCSV);
fprintf('\nMaster matrix saved: N=%d subjects → %s\n', height(master), outCSV);

CVA_log_event('master_matrix', 'summary', struct( ...
    'n_before_exclusion',      nBefore, ...
    'n_excluded_missing_data', nExcluded, ...
    'n_final',                 height(master), ...
    'n_young',                 nYoung, ...
    'n_old',                   nOld, ...
    'csf_tiv_mean',            mean(master.CSF_TIV), ...
    'csf_tiv_sd',              std(master.CSF_TIV), ...
    'output_csv',              outCSV));

% -------------------------------------------------------------------------
function T = ensure_id_and_vars(T, requiredVars)
if ~istable(T)
    error('Expected table input while building master matrix.');
end

% Recover an ID column if "subID" is absent but a likely alternative exists.
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
        error('Could not identify a subject ID column in the input table.');
    end
end

% Standardize ID datatype to cellstr for robust strcmp / joins.
if isstring(T.subID)
    T.subID = cellstr(T.subID);
elseif iscategorical(T.subID)
    T.subID = cellstr(string(T.subID));
elseif isnumeric(T.subID)
    T.subID = cellstr(string(T.subID));
end

% Add any missing required columns as NaN / empty so joins don't fail.
for i = 1:numel(requiredVars)
    v = requiredVars{i};
    if ismember(v, T.Properties.VariableNames)
        continue;
    end
    if strcmp(v, 'age_group')
        T.(v) = repmat({''}, height(T), 1);
    else
        T.(v) = NaN(height(T), 1);
    end
end
end
