function CVA_master
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

%% Setup
clc;

% Resolve project root from this file location (portable across machines).
projectRoot = resolve_project_root();
addpath(genpath(projectRoot));

% Optionally run user startup if available on MATLAB path.
if exist('startup', 'file')
    % Run startup in base workspace so any clear/reset remains isolated
    % from the master function workspace.
    evalin('base', 'startup;');
    % startup may reset MATLAB paths; re-add project tree afterwards.
    projectRoot = resolve_project_root();
    addpath(genpath(projectRoot));
end

%% Paths
dirs = CVA_paths();

%% Run Order
scripts = {
    % Preprocessing
    '1_preprocessing/CVA_preprocessing_eeg.m'
    '1_preprocessing/CVA_cat12_batch_config.m'
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
    % Visualization
    '3_visualization/EEG/CVA_eeg_powspctrm.m'
    '3_visualization/EEG/CVA_eeg_topos.m'
    '3_visualization/MRI/CVA_mri_csf_distribution.m'
    '3_visualization/CVA_scatter_csf_alpha.m'
    '3_visualization/CVA_scatter_csf_gfp.m'
    % Stats
    '4_stats/CVA_lme_alpha.m'
    '4_stats/CVA_lme_gfp.m'
    '4_stats/CVA_lme_interaction.m'
    };

results = struct();
for i = 1:numel(scripts)
    scriptName = scripts{i};
    fprintf('\n[%d/%d] Running: %s\n', i, numel(scripts), scriptName);
    projectRoot = resolve_project_root();
    addpath(genpath(projectRoot));
    scriptPath = fullfile(projectRoot, scriptName);

    % Do not fail full pipeline if optional scripts are absent.
    if ~exist(scriptPath, 'file')
        results(i).script = scriptName;
        results(i).status = 'SKIPPED';
        results(i).error  = 'File not found';
        warning('Script skipped (missing): %s', scriptName);
        continue;
    end

    try
        scriptPathEscaped = strrep(scriptPath, '''', '''''');
        evalin('base', sprintf('run(''%s'');', scriptPathEscaped));
        results(i).script = scriptName;
        results(i).status = 'OK';
    catch ME
        results(i).script = scriptName;
        results(i).status = 'FAILED';
        results(i).error  = ME.message;
        warning('Script failed: %s\nError: %s', scriptName, ME.message);
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

end

function rootPath = resolve_project_root()
rootPath = fileparts(mfilename('fullpath'));
if isempty(rootPath)
    rootPath = pwd;
end
end
