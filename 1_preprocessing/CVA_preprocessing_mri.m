%% CVA_preprocessing_mri
%
% Runs CAT12 segmentation on MP2RAGE structural images to extract:
%   - GM volume, WM volume, CSF volume, TBV
%   - Skull thickness (via SPM/MNE watershed or CAT12 thickness map)
%
% Requires: SPM12 + CAT12 toolbox on MATLAB path
%
% Input:  paths.mri_raw  / sub-XXXXXX / sub-XXXXXX_ses-01_acq-mp2rage_brain.nii.gz
% Output: paths.mri_proc / CAT12 derivatives per subject

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

%% Batch CAT12 segmentation
% Collect all NIfTI files
nii_files = {};
for s = 1:numel(subjects)
    subID   = subjects{s};
    niiGz   = fullfile(paths.mri_raw, subID, 'anat', ...
                       [subID '_ses-01_acq-mp2rage_brain.nii.gz']);
    niiFile = strrep(niiGz, '.nii.gz', '.nii');

    % Decompress if needed
    if exist(niiGz, 'file') && ~exist(niiFile, 'file')
        gunzip(niiGz, fileparts(niiGz));
    end

    if exist(niiFile, 'file')
        nii_files{end+1} = niiFile; %#ok<AGROW>
    else
        warning('NIfTI not found for %s', subID);
    end
end

%% Run CAT12 segmentation batch
% TODO: configure matlabbatch for cat12 segmentation
% matlabbatch{1}.spm.tools.cat.estwrite.data = nii_files';
% matlabbatch{1}.spm.tools.cat.estwrite.output.GM.native = 1;
% matlabbatch{1}.spm.tools.cat.estwrite.output.WM.native = 1;
% matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.native = 1;
% spm_jobman('run', matlabbatch);

fprintf('CAT12 batch ready for %d subjects.\n', numel(nii_files));
fprintf('TODO: configure and run matlabbatch.\n');
