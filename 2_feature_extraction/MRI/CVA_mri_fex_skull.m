%% CVA_mri_fex_skull
%
% Estimates mean skull thickness per subject as a nuisance covariate.
%
% Approach: uses CAT12 bone segmentation output or SPM unified segmentation
% to define inner/outer skull surfaces. Mean distance between surfaces
% computed over parietal-occipital ROI (matching posterior EEG cluster).
%
% Output: dirs.fex/CVA_skull_thickness.mat
%   skull_out: table with columns [subID, skull_thickness_mm]

%% Setup
dirs     = CVA_paths();
subjects = CVA_get_subjects();

skull_out = table();

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[Skull FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    % CAT12 bone thickness map (p4 = bone image from CAT12 segmentation)
    boneFile = fullfile(dirs.mri_proc, subID, ...
                        ['p4' subID '_ses-01_acq-mp2rage_brain.nii']);

    if ~exist(boneFile, 'file')
        warning('Bone segmentation not found for %s', subID);
        continue;
    end

    try
        %% Load bone probability map
        V    = spm_vol(boneFile);
        Y    = spm_read_vols(V);

        %% Threshold to binary skull mask (CAT12 bone prob > 0.5)
        skullMask = Y > 0.5;

        %% TODO: restrict to parietal-occipital ROI and compute thickness
        % Placeholder: mean nonzero voxel value * voxel size as proxy
        voxSize       = abs(V.mat(1,1));   % assume isotropic
        skullThickMM  = sum(skullMask(:)) / (size(Y,1)*size(Y,2)) * voxSize;

        %% Append
        row       = table({subID}, skullThickMM, ...
                          'VariableNames', {'subID','skull_thickness_mm'});
        skull_out = [skull_out; row]; %#ok<AGROW>

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
    end
end

%% Save
outFile = fullfile(dirs.fex, 'CVA_skull_thickness.mat');
save(outFile, 'skull_out');
fprintf('Saved skull thickness for %d subjects to %s\n', height(skull_out), outFile);
