%% CVA_cat12_batch_config
%
% Builds and runs the CAT12 segmentation matlabbatch for all subjects.
% Requires: SPM12 + CAT12 toolbox on MATLAB path.
%
% Output per subject in dirs.mri_proc/sub-XXXXXX/:
%   mri/  — tissue segments (p0, p1, p2, p3, p4 images)
%   report/ — cat_*.xml with volumetric stats
%   surf/ — surface reconstructions (if enabled)
%
% Run this script ONCE to process all subjects. Already-processed subjects
% are skipped automatically via the check at the top of the loop.

%% Setup
CVA_init_toolboxes();
dirs     = CVA_paths();
subjects = CVA_get_subjects();

% Verify SPM + CAT12 are available
if ~exist('spm', 'file')
    add_spm12_if_available(dirs);
end
if ~exist('spm', 'file')
    error(['SPM12 not found on path. Set SPM12_DIR (or SPM_DIR) and rerun, ', ...
           'or add it manually: addpath(''/path/to/spm12'')']);
end
if ~exist('cat12', 'file')
    error('CAT12 not found. Install CAT12 into SPM12/toolbox/cat12 and restart SPM.');
end

spm('defaults', 'fmri');
spm_jobman('initcfg');

%% Collect NIfTI files (decompress .nii.gz if needed)
nii_files = {};
valid_subs = {};

for s = 1:numel(subjects)
    subID  = subjects{s};
    niiGz  = fullfile(dirs.mri_raw, subID, 'anat', ...
                      [subID '_ses-01_acq-mp2rage_brain.nii.gz']);
    niiOut = strrep(niiGz, '.nii.gz', '.nii');

    % Skip if CAT12 report already exists (resumable)
    xmlCheck = fullfile(dirs.mri_proc, subID, 'report', ...
                        ['cat_' subID '_ses-01_acq-mp2rage_brain.xml']);
    if exist(xmlCheck, 'file')
        fprintf('[SKIP - already processed] %s\n', subID);
        continue;
    end

    % Decompress
    if ~exist(niiOut, 'file')
        if exist(niiGz, 'file')
            fprintf('[Decompressing] %s\n', subID);
            gunzip(niiGz, fileparts(niiGz));
        else
            warning('[MISSING] NIfTI not found for %s', subID);
            continue;
        end
    end

    nii_files{end+1} = [niiOut ',1']; %#ok<AGROW>
    valid_subs{end+1} = subID;        %#ok<AGROW>
end

if isempty(nii_files)
    fprintf('No subjects to process.\n');
    return;
end
fprintf('\nQueued %d subjects for CAT12 segmentation.\n', numel(nii_files));

%% Build matlabbatch
matlabbatch = CVA_cat12_build_batch(nii_files, dirs);

%% Run
spm_jobman('run', matlabbatch);
fprintf('\nCAT12 segmentation complete.\n');

%% Move outputs to per-subject derivative folders
CVA_cat12_move_outputs(valid_subs, nii_files, dirs);

function add_spm12_if_available(dirs)
envCandidates = {getenv('SPM12_DIR'), getenv('SPM_DIR')};

homeDir = char(java.lang.System.getProperty('user.home'));
userFromDataRoot = '';
if isfield(dirs, 'eeg_raw') && ~isempty(dirs.eeg_raw)
    % Infer ".../Students/<user>/toolboxes" from ".../Students/<user>/CVA/data/EEG"
    userFromDataRoot = fileparts(fileparts(fileparts(dirs.eeg_raw)));
end

defaultCandidates = {
    fullfile(homeDir, 'spm12')
    fullfile(homeDir, 'toolboxes', 'spm12')
    '/Applications/spm12'
    '/opt/spm12'
    '/usr/local/spm12'
    'W:\Students\Arne\toolboxes\spm12'
    'W:\Students\Arne\toolboxes\SPM12'
    '/Volumes/g_psyplafor_methlab$/Students/Arne/toolboxes/spm12'
    '/Volumes/g_psyplafor_methlab$/Students/Arne/toolboxes/SPM12'
    '/Volumes/g_psyplafor_methlab$/spm12'
    '/Volumes/g_psyplafor_methlab$/toolboxes/spm12'
};
if ~isempty(userFromDataRoot)
    defaultCandidates = [defaultCandidates(:); {
        fullfile(userFromDataRoot, 'toolboxes', 'spm12')
        fullfile(userFromDataRoot, 'toolboxes', 'SPM12')
        fullfile(userFromDataRoot, 'spm12')
        fullfile(userFromDataRoot, 'SPM12')
    }];
end

candidates = [envCandidates(:); defaultCandidates(:)];
for i = 1:numel(candidates)
    cand = candidates{i};
    if isempty(cand)
        continue;
    end
    spmEntry = fullfile(cand, 'spm.m');
    if exist(spmEntry, 'file')
        addpath(cand);
        cat12Candidates = {
            fullfile(cand, 'toolbox', 'cat12')
            fullfile(cand, 'toolbox', 'CAT12')
        };
        for j = 1:numel(cat12Candidates)
            if exist(cat12Candidates{j}, 'dir')
                addpath(cat12Candidates{j});
                break;
            end
        end
        return;
    end
end
end
