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
dirs     = CVA_paths();
subjects = CVA_get_subjects();

% Verify SPM + CAT12 are available
if ~exist('spm', 'file')
    error('SPM12 not found on path. Add SPM12 first: addpath(''/path/to/spm12'')');
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
