function CVA_master(varargin)
%% CVA Master Analysis Script
%
% Executes all MATLAB-based analysis steps for the CVA study.
% Investigates whether inter-individual differences in total CSF volume
% predict scalp EEG amplitudes (posterior alpha power, GFP), controlling
% for skull thickness, age, and sex.
%
% Data: MPI-Leipzig Mind-Brain-Body (LEMON) dataset
%   EEG:  preprocessed resting-state, eyes-closed (.set/.fdt)
%   MRI:  MP2RAGE structural images (.nii.gz)
%   Demo: Participants_MPILMBB_LEMON.csv
%
% Table of contents (run order)
%
%   Preprocessing:
%       1_preprocessing/CVA_preprocessing_eeg.m
%       1_preprocessing/CVA_cat12_batch_config.m
%
%   Controls:
%       _controls/CVA_missing_data.m
%       _controls/CVA_cat12_qc.m
%       _controls/CVA_check_iaf.m
%
%   Feature Extraction:
%       2_feature_extraction/EEG/CVA_eeg_fex_alpha.m
%       2_feature_extraction/EEG/CVA_eeg_fex_gfp.m
%       2_feature_extraction/MRI/CVA_mri_fex_csf.m
%       2_feature_extraction/MRI/CVA_mri_fex_skull.m
%       2_feature_extraction/CVA_demographics.m
%       2_feature_extraction/CVA_master_matrix.m
%
%   Visualizations:
%       3_visualization/EEG/CVA_eeg_powspctrm.m
%       3_visualization/EEG/CVA_eeg_topos.m
%       3_visualization/MRI/CVA_mri_csf_distribution.m
%       3_visualization/CVA_scatter_csf_alpha.m
%       3_visualization/CVA_scatter_csf_gfp.m
%
%   Stats:
%       4_stats/CVA_lme_alpha.m
%       4_stats/CVA_lme_gfp.m
%       4_stats/CVA_lme_interaction.m
%
%   Input:
%
% setenv('CVA_SUBJECTS','sub-032301');   % or '032301'
% CVA_master('test_mode', true);
% setenv('CVA_SUBJECTS','');             % clear override after test

%% Setup
clc;

% Resolve project root from this file location (portable across machines).
projectRoot = resolve_project_root();
addpath(genpath(projectRoot));

% One-time toolbox initialization for the full pipeline. setup() is
% intentionally not called here because external setup scripts may be
% project-specific and fail when the repository is nested differently.
CVA_init_toolboxes(false);

%% Paths
dirs = CVA_paths();

%% Options
opts = parse_master_options(varargin{:});

%% Run Order
preprocessingScripts = {
    % Preprocessing
    '1_preprocessing/CVA_preprocessing_eeg.m'
    '1_preprocessing/CVA_cat12_batch_config.m'
    };

controlAndFeatureScripts = {
    % Controls
    '_controls/CVA_missing_data.m'
    '_controls/CVA_cat12_qc.m'
    % Feature Extraction
    '2_feature_extraction/EEG/CVA_eeg_fex_alpha.m'
    '_controls/CVA_check_iaf.m'
    '2_feature_extraction/EEG/CVA_eeg_fex_gfp.m'
    '2_feature_extraction/MRI/CVA_mri_fex_csf.m'
    '2_feature_extraction/MRI/CVA_mri_fex_skull.m'
    '2_feature_extraction/CVA_demographics.m'
    '2_feature_extraction/CVA_master_matrix.m'
    };

visualizationScripts = {
    % Visualization
    '3_visualization/EEG/CVA_eeg_powspctrm.m'
    '3_visualization/EEG/CVA_eeg_topos.m'
    '3_visualization/MRI/CVA_mri_csf_distribution.m'
    '3_visualization/CVA_scatter_csf_alpha.m'
    '3_visualization/CVA_scatter_csf_gfp.m'
    };

statsScripts = {
    % Stats
    '4_stats/CVA_lme_alpha.m'
    '4_stats/CVA_lme_gfp.m'
    '4_stats/CVA_lme_interaction.m'
    };

if opts.test_mode
    scripts = [preprocessingScripts; controlAndFeatureScripts];
else
    scripts = [preprocessingScripts; controlAndFeatureScripts; visualizationScripts; statsScripts];
end
CVA_log_event('master', 'pipeline_start', struct('n_scripts', numel(scripts)));

results = struct();
for i = 1:numel(scripts)
    scriptName = scripts{i};
    fprintf('\n[%d/%d] Running: %s\n', i, numel(scripts), scriptName);
    scriptTimer = tic;
    CVA_log_event('master', 'script_start', struct('script', scriptName, 'index', i));
    projectRoot = resolve_project_root();
    addpath(genpath(projectRoot));
    scriptPath = fullfile(projectRoot, scriptName);

    % Do not fail full pipeline if optional scripts are absent.
    if ~exist(scriptPath, 'file')
        results(i).script = scriptName;
        results(i).status = 'SKIPPED';
        results(i).error  = 'File not found';
        warning('Script skipped (missing): %s', scriptName);
        CVA_log_event('master', 'script_end', struct( ...
            'script', scriptName, ...
            'index', i, ...
            'status', 'SKIPPED', ...
            'duration_sec', toc(scriptTimer), ...
            'error', 'File not found'));
        continue;
    end

    try
        scriptPathEscaped = strrep(scriptPath, '''', '''''');
        evalin('base', sprintf('run(''%s'');', scriptPathEscaped));
        results(i).script = scriptName;
        results(i).status = 'OK';
        CVA_log_event('master', 'script_end', struct( ...
            'script', scriptName, ...
            'index', i, ...
            'status', 'OK', ...
            'duration_sec', toc(scriptTimer)));
    catch ME
        results(i).script = scriptName;
        results(i).status = 'FAILED';
        results(i).error  = ME.message;
        warning('Script failed: %s\nError: %s', scriptName, ME.message);
        CVA_log_event('master', 'script_end', struct( ...
            'script', scriptName, ...
            'index', i, ...
            'status', 'FAILED', ...
            'duration_sec', toc(scriptTimer), ...
            'error', ME.message));
    end
end

%% Summary Log
fprintf('\n\n========== CVA MASTER LOG ==========\n');
for i = 1:numel(results)
    fprintf('[%s] %s\n', results(i).status, results(i).script);
    if strcmp(results(i).status, 'FAILED')
        fprintf('      >> %s\n', results(i).error);
    end
end
fprintf('=====================================\n');
CVA_log_event('master', 'pipeline_end', struct( ...
    'n_ok', sum(strcmp({results.status}, 'OK')), ...
    'n_failed', sum(strcmp({results.status}, 'FAILED')), ...
    'n_skipped', sum(strcmp({results.status}, 'SKIPPED')), ...
    'test_mode', opts.test_mode));

end

function rootPath = resolve_project_root()
rootPath = fileparts(mfilename('fullpath'));
if isempty(rootPath)
    rootPath = pwd;
end
end

function opts = parse_master_options(varargin)
opts = struct('test_mode', false);

if nargin == 0
    return;
end

if nargin == 1 && islogical(varargin{1}) && isscalar(varargin{1})
    opts.test_mode = varargin{1};
    return;
end

if mod(nargin, 2) ~= 0
    error('CVA_master:InvalidOptions', ...
        'Options must be provided as name/value pairs.');
end

for i = 1:2:nargin
    key = string(varargin{i});
    val = varargin{i + 1};
    switch lower(strtrim(key))
        case "test_mode"
            if ~(islogical(val) && isscalar(val))
                error('CVA_master:InvalidTestMode', ...
                    'test_mode must be a scalar logical.');
            end
            opts.test_mode = val;
        otherwise
            error('CVA_master:UnknownOption', ...
                'Unknown option: %s', char(key));
    end
end
end
