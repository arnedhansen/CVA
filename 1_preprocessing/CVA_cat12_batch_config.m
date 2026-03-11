%% CVA_cat12_batch_config
%
% Builds and runs the CAT12 segmentation matlabbatch for all subjects.
% Requires: SPM12 + CAT12 toolbox on MATLAB path.
%
% Output per subject in paths.mri_proc/sub-XXXXXX/:
%   mri/  — tissue segments (p0, p1, p2, p3, p4 images)
%   report/ — cat_*.xml with volumetric stats
%   surf/ — surface reconstructions (if enabled)
%
% Run this script ONCE to process all subjects. Already-processed subjects
% are skipped automatically via the check at the top of the loop.

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

summary = struct();
summary.total_subjects = numel(subjects);
summary.already_processed = 0;
summary.missing_nifti = 0;
summary.decompressed = 0;
summary.queued = 0;

% Verify SPM + CAT12 are available
if ~exist('spm', 'file')
    add_spm12_if_available(paths);
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
assert_spm_mex_compiled();

%% Collect NIfTI files (decompress .nii.gz if needed)
nii_files = {};
valid_subs = {};

for s = 1:numel(subjects)
    subID  = subjects{s};
    niiGz  = fullfile(paths.mri_raw, subID, 'anat', ...
                      [subID '_ses-01_acq-mp2rage_brain.nii.gz']);
    niiOut = strrep(niiGz, '.nii.gz', '.nii');

    % Skip if CAT12 report already exists (resumable)
    xmlCheck = fullfile(paths.mri_proc, subID, 'report', ...
                        ['cat_' subID '_ses-01_acq-mp2rage_brain.xml']);
    if exist(xmlCheck, 'file')
        fprintf('[SKIP - already processed] %s\n', subID);
        summary.already_processed = summary.already_processed + 1;
        continue;
    end

    % Decompress
    if ~exist(niiOut, 'file')
        if exist(niiGz, 'file')
            fprintf('[Decompressing] %s\n', subID);
            gunzip(niiGz, fileparts(niiGz));
            summary.decompressed = summary.decompressed + 1;
        else
            warning('[MISSING] NIfTI not found for %s', subID);
            summary.missing_nifti = summary.missing_nifti + 1;
            CVA_log_event('cat12_batch', 'subject_skip_missing_nifti', struct( ...
                'subID', subID, ...
                'expected_nii_gz', niiGz));
            continue;
        end
    end

    nii_files{end+1} = [niiOut ',1']; %#ok<AGROW>
    valid_subs{end+1} = subID;        %#ok<AGROW>
    summary.queued = summary.queued + 1;
end

if isempty(nii_files)
    fprintf('No subjects to process.\n');
    CVA_log_event('cat12_batch', 'run_summary', summary);
    return;
end
fprintf('\nQueued %d subjects for CAT12 segmentation.\n', numel(nii_files));
CVA_log_event('cat12_batch', 'run_queued', struct( ...
    'n_queued', numel(nii_files), ...
    'n_already_processed', summary.already_processed, ...
    'n_missing_nifti', summary.missing_nifti, ...
    'n_decompressed', summary.decompressed));

%% Build matlabbatch
matlabbatch = CVA_cat12_build_batch(nii_files, paths);

%% Run
spm_jobman('run', matlabbatch);
fprintf('\nCAT12 segmentation complete.\n');
CVA_log_event('cat12_batch', 'segmentation_complete', struct('n_processed', numel(nii_files)));

%% Move outputs to per-subject derivative folders
CVA_cat12_move_outputs(valid_subs, nii_files, paths);
summary.moved_outputs = numel(valid_subs);
CVA_log_event('cat12_batch', 'run_summary', summary);

function add_spm12_if_available(paths)
envCandidates = {getenv('SPM12_DIR'), getenv('SPM_DIR')};

homeDir = char(java.lang.System.getProperty('user.home'));
userFromDataRoot = '';
if isfield(paths, 'eeg_raw') && ~isempty(paths.eeg_raw)
    % Infer ".../Students/<user>/toolboxes" from ".../Students/<user>/CVA/data/EEG"
    userFromDataRoot = fileparts(fileparts(fileparts(paths.eeg_raw)));
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

function assert_spm_mex_compiled()
% CAT12 segmentation requires compiled SPM MEX functions on this platform.
% Without these binaries, segmentation fails at runtime in spm_slice_vol.
spmDir = spm('dir');
mexBin = mexext;

required = {'spm_slice_vol'};
missing = {};

for i = 1:numel(required)
    mexPath = fullfile(spmDir, [required{i} '.' mexBin]);
    if ~exist(mexPath, 'file')
        fallback = dir(fullfile(spmDir, [required{i} '.mex*']));
        if isempty(fallback)
            missing{end+1} = required{i}; %#ok<AGROW>
        end
    end
end

if ~isempty(missing)
    msg = sprintf([ ...
        'SPM is present but required compiled binaries are missing for this platform.\n' ...
        'Missing: %s\n' ...
        'Expected extension: .%s\n' ...
        'SPM path: %s\n' ...
        'Compile SPM MEX files (e.g., run spm_make in MATLAB with a working compiler) and rerun CAT12.'], ...
        strjoin(missing, ', '), mexBin, spmDir);
    CVA_log_event('cat12_batch', 'spm_mex_missing', struct( ...
        'spm_dir', spmDir, ...
        'mexext', mexBin, ...
        'missing_functions', {missing}));
    error('CVA:MissingSpmMex', '%s', msg);
end
end
