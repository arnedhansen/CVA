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

% Normalize table schemas so joins remain stable even when some modalities
% have no rows (e.g., CAT12 not completed yet for the current subset).
demo_out  = ensure_id_and_vars(demo_out,  {'age_mid','sex','age_group'});
vol_out   = ensure_id_and_vars(vol_out,   {'TBV','GM','WM','CSF'});
skull_out = ensure_id_and_vars(skull_out, {'skull_thickness_mm'});
alpha_out = ensure_id_and_vars(alpha_out, {'IAF','alpha_power'});
gfp_out   = ensure_id_and_vars(gfp_out,   {'gfp_mean','gfp_alpha'});

%% Merge
master = demo_out;
master = outerjoin(master,    vol_out,   'Keys','subID','MergeKeys',true);
master = outerjoin(master,  skull_out,   'Keys','subID','MergeKeys',true);
master = outerjoin(master,  alpha_out,   'Keys','subID','MergeKeys',true);
master = outerjoin(master,    gfp_out,   'Keys','subID','MergeKeys',true);

%% Flag incomplete rows
nVars     = {'CSF','GM','WM','TBV','skull_thickness_mm','IAF','alpha_power','gfp_mean','gfp_alpha'};
nBefore = height(master);
missingMask = any(ismissing(master(:, nVars)), 2);
fprintf('%d subjects excluded due to missing data.\n', sum(missingMask));
nExcluded = sum(missingMask);
master(missingMask, :) = [];

if height(master) == 0 && nBefore > 0
    warning(['Master matrix is empty after exclusion. ', ...
             'This indicates missing upstream modality outputs ', ...
             '(most often CAT12 segmentation outputs).']);
end

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
CVA_log_event('master_matrix', 'summary', struct( ...
    'n_excluded_missing_data', nExcluded, ...
    'n_final', height(master), ...
    'n_young', sum(strcmp(master.age_group,'young')), ...
    'n_old', sum(strcmp(master.age_group,'old')), ...
    'output_csv', outCSV));

function T = ensure_id_and_vars(T, requiredVars)
if ~istable(T)
    error('Expected table input while building master matrix.');
end

% Recover an ID column if "subID" is absent but a likely alternative exists.
if ~ismember('subID', T.Properties.VariableNames)
    varNames = T.Properties.VariableNames;
    normNames = lower(regexprep(varNames, '[^a-zA-Z0-9]', ''));
    idIdx = find(contains(normNames, 'subid') | contains(normNames, 'participantid') | strcmp(normNames, 'id'), 1);
    if ~isempty(idIdx)
        varNames{idIdx} = 'subID';
        T.Properties.VariableNames = varNames;
    elseif width(T) == 0
        T.subID = cell(0,1);
    else
        error('Unrecognized table variable name ''subID''.');
    end
end

% Standardize ID datatype to cellstr for robust strcmp/joins.
if isstring(T.subID)
    T.subID = cellstr(T.subID);
elseif iscategorical(T.subID)
    T.subID = cellstr(string(T.subID));
elseif isnumeric(T.subID)
    T.subID = cellstr(string(T.subID));
end

% Add missing columns as NaN (numeric) or empty strings (text).
for i = 1:numel(requiredVars)
    v = requiredVars{i};
    if ismember(v, T.Properties.VariableNames)
        continue;
    end
    if strcmp(v, 'age_group')
        T.(v) = repmat({''}, height(T), 1);
    elseif strcmp(v, 'sex')
        T.(v) = NaN(height(T), 1);
    else
        T.(v) = NaN(height(T), 1);
    end
end
end
