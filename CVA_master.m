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
%       1_preprocessing/CVA_preprocessing_mri.m
%
%   Controls:
%       _controls/CVA_missing_data.m
%       _controls/CVA_check_iaf.m
%
%   Feature Extraction:
%       2_feature_extraction/eeg/CVA_eeg_fex_alpha.m
%       2_feature_extraction/eeg/CVA_eeg_fex_gfp.m
%       2_feature_extraction/mri/CVA_mri_fex_csf.m
%       2_feature_extraction/mri/CVA_mri_fex_skull.m
%       2_feature_extraction/CVA_demographics.m
%       2_feature_extraction/CVA_master_matrix.m
%
%   Visualizations:
%       3_visualization/eeg/CVA_eeg_powspctrm.m
%       3_visualization/eeg/CVA_eeg_topos.m
%       3_visualization/mri/CVA_mri_csf_distribution.m
%       3_visualization/CVA_scatter_csf_alpha.m
%       3_visualization/CVA_scatter_csf_gfp.m
%
%   Stats:
%       4_stats/CVA_lme_alpha.m
%       4_stats/CVA_lme_gfp.m
%       4_stats/CVA_lme_interaction.m

%% Setup
startup;
clc;

% Set base path depending on platform
if ispc
    basePath = 'C:\Users\dummy\Documents\GitHub\CVA';
else
    basePath = '/Users/Arne/Documents/GitHub/CVA';
end

addpath(genpath(basePath));

%% Paths
dirs = CVA_paths();

%% Run Order
scripts = {
    % Preprocessing
    '1_preprocessing/CVA_preprocessing_eeg.m'
    '1_preprocessing/CVA_preprocessing_mri.m'
    % Controls
    '_controls/CVA_missing_data.m'
    '_controls/CVA_check_iaf.m'
    % Feature Extraction
    '2_feature_extraction/eeg/CVA_eeg_fex_alpha.m'
    '2_feature_extraction/eeg/CVA_eeg_fex_gfp.m'
    '2_feature_extraction/mri/CVA_mri_fex_csf.m'
    '2_feature_extraction/mri/CVA_mri_fex_skull.m'
    '2_feature_extraction/CVA_demographics.m'
    '2_feature_extraction/CVA_master_matrix.m'
    % Visualization
    '3_visualization/eeg/CVA_eeg_powspctrm.m'
    '3_visualization/eeg/CVA_eeg_topos.m'
    '3_visualization/mri/CVA_mri_csf_distribution.m'
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
    try
        run(fullfile(basePath, scriptName));
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
