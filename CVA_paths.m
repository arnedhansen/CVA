function dirs = CVA_paths()
% CVA_PATHS  Returns a struct of all project-relevant directories.
%
%   dirs = CVA_paths()
%
%   Automatically resolves data root based on platform. Add any new
%   directories here and reference dirs throughout all scripts.

%% Data root
if ispc
    dataRoot = 'C:\Users\dummy\CVA\data';
else
    dataRoot = '/Volumes/g_psyplafor_methlab$/Students/Arne/CVA/data';
end

%% Raw data
dirs.eeg_raw   = fullfile(dataRoot, 'EEG');   % preprocessed .set/.fdt from LEMON
dirs.mri_raw   = fullfile(dataRoot, 'MRI');   % MP2RAGE .nii.gz from LEMON
dirs.demo      = fullfile(dataRoot, 'Participants_MPILMBB_LEMON.csv');

%% Processed / derivatives
dirs.eeg_proc  = fullfile(dataRoot, 'derivatives', 'EEG');
dirs.mri_proc  = fullfile(dataRoot, 'derivatives', 'MRI');   % CAT12 output

%% Feature matrices
dirs.fex       = fullfile(dataRoot, 'features');

%% Results
dirs.stats     = fullfile(dataRoot, 'results', 'stats');
dirs.figures   = fullfile(dataRoot, 'results', 'figures');

%% Create missing directories
fields = fieldnames(dirs);
for i = 1:numel(fields)
    d = dirs.(fields{i});
    if ~contains(d, '.csv') && ~exist(d, 'dir')
        mkdir(d);
    end
end
