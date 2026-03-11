%% CVA_mri_fex_skull
%
% Estimates mean skull thickness per subject as a nuisance covariate.
%
% Approach:
%   1. Load CAT12 p4 (bone) probability map
%   2. Threshold to binary skull mask (p4 > 0.3)
%   3. Restrict to a parietal-occipital ROI in MNI space matching the
%      posterior EEG electrode cluster (O1/O2/Oz/PO3/PO4/PO7/PO8)
%   4. Compute skull thickness using the distance-transform method:
%        a. Identify outer skull surface voxels (skull voxels adjacent to
%           non-skull voxels on the exterior of the head)
%        b. Compute Euclidean distance transform of the INVERTED skull mask
%           (i.e., distance from each skull voxel to the nearest non-skull
%           voxel — this gives the local half-thickness at each interior point)
%        c. Find the medial surface of the skull (voxels furthest from both
%           surfaces) using the distance transform of the skull mask itself
%        d. Skull thickness at each medial-surface voxel = 2 × bwdist value
%           (since bwdist gives distance to nearest boundary)
%        e. Average over all medial-surface voxels in the ROI
%
%   This approach correctly handles the curved skull geometry and does not
%   depend on a fixed projection axis, unlike the previous column-counting
%   method which overestimated thickness for surfaces not orthogonal to Y.
%
% ROI definition (MNI coordinates, mm):
%   X: -60 to +60    (full left-right width over posterior scalp)
%   Y: -120 to -60   (posterior; negative = posterior in MNI)
%   Z:  -20 to +80   (inferior-superior; covers parietal-occipital vault)
%
% Output: paths.mri_fex/CVA_skull_thickness.mat
%   skull_out: table with columns [subID, skull_thickness_mm]

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

% Parietal-occipital ROI in MNI mm (matches posterior EEG cluster)
roi_mni.X = [-60  60];
roi_mni.Y = [-120 -60];
roi_mni.Z = [ -20  80];

% Bone probability threshold — permissive to capture spongy diploë layer
BONE_THRESH = 0.3;

skull_out = table();
summary   = struct();
summary.total_subjects   = numel(subjects);
summary.missing_bone_map = 0;
summary.empty_roi        = 0;
summary.failed           = 0;
summary.saved            = 0;

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[Skull FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    mriDir         = fullfile(paths.mri_proc, subID, 'anat', 'mri');
    boneCandidates = dir(fullfile(mriDir, 'p4*.nii'));

    if isempty(boneCandidates)
        warning('Bone map not found for %s — skipping.', subID);
        summary.missing_bone_map = summary.missing_bone_map + 1;
        CVA_log_event('mri_skull_fex', 'subject_skip_missing_bone', ...
            struct('subID', subID));
        continue;
    end
    boneFile = fullfile(mriDir, boneCandidates(1).name);

    try
        %% Load bone probability map
        V = spm_vol(boneFile);
        Y = spm_read_vols(V);

        %% Binary skull mask
        skullMask = Y > BONE_THRESH;

        %% Convert ROI MNI bounds → voxel indices via inverse affine
        mat_inv = inv(V.mat);

        corners_mni = [
            roi_mni.X(1) roi_mni.Y(1) roi_mni.Z(1) 1;
            roi_mni.X(2) roi_mni.Y(2) roi_mni.Z(2) 1
            ]';
        corners_vox = mat_inv * corners_mni;

        dims = size(Y);
        xi = max(1, min(dims(1), round(sort(corners_vox(1,:)))));
        yi = max(1, min(dims(2), round(sort(corners_vox(2,:)))));
        zi = max(1, min(dims(3), round(sort(corners_vox(3,:)))));

        %% Extract ROI subvolume
        roiMask = skullMask(xi(1):xi(2), yi(1):yi(2), zi(1):zi(2));

        if ~any(roiMask(:))
            warning('No skull voxels in ROI for %s — skipping.', subID);
            summary.empty_roi = summary.empty_roi + 1;
            CVA_log_event('mri_skull_fex', 'subject_skip_empty_roi', ...
                struct('subID', subID));
            continue;
        end

        %% Distance-transform thickness estimation
        %
        % bwdist(~roiMask) gives, for every skull voxel, its Euclidean
        % distance to the nearest non-skull voxel (i.e., to the nearest
        % bone surface). This distance is maximal at the medial axis of the
        % bone and equals half the local bone thickness there.
        %
        % We identify medial-axis voxels as local maxima of the distance
        % transform within the skull mask, then thickness = 2 × dist value.
        %
        % Voxel distances are in voxels; we convert to mm using the mean
        % voxel dimension (isotropic 1 mm for MP2RAGE, but computed from
        % the affine to be safe).
        voxSize_mm = mean(sqrt(sum(V.mat(1:3,1:3).^2, 1)));

        % Distance from each skull voxel to nearest non-skull voxel (in voxels)
        distMap = bwdist(~roiMask);   % zero outside skull, positive inside

        % Medial surface: local maxima of distMap within skull mask.
        % imdilate + equality check is a robust way to find local maxima
        % without requiring the Image Processing Toolbox's imregionalmax.
        % Uses a 3x3x3 structuring element (26-connectivity).
        se      = ones(3,3,3);
        distMax = imdilate(distMap, se);   % each voxel gets max of its neighbourhood
        medAxis = roiMask & (distMap == distMax) & (distMap > 0);

        if ~any(medAxis(:))
            % Fallback: bone is only 1 voxel thick everywhere — use all skull voxels
            medAxis = roiMask;
        end

        % Thickness at each medial-axis voxel = 2 × distance to surface (in mm)
        thicknessVals  = 2 * distMap(medAxis) * voxSize_mm;
        skullThickMM   = mean(thicknessVals);

        fprintf('  Skull thickness: %.2f mm  SD: %.2f mm  (medial voxels: %d)\n', ...
            skullThickMM, std(thicknessVals), sum(medAxis(:)));

        %% Append
        row       = table({subID}, skullThickMM, ...
                          'VariableNames', {'subID','skull_thickness_mm'});
        skull_out = [skull_out; row]; %#ok<AGROW>
        summary.saved = summary.saved + 1;

        CVA_log_event('mri_skull_fex', 'subject_processed', struct( ...
            'subID',              subID, ...
            'skull_thickness_mm', skullThickMM, ...
            'skull_thickness_sd', std(thicknessVals), ...
            'n_medial_voxels',    sum(medAxis(:))));

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
        summary.failed = summary.failed + 1;
        CVA_log_event('mri_skull_fex', 'subject_failed', struct( ...
            'subID', subID, 'error', ME.message));
    end
end

%% Save
outFile = fullfile(paths.mri_fex, 'CVA_skull_thickness.mat');
save(outFile, 'skull_out');
fprintf('\nSaved skull thickness for %d subjects to %s\n', height(skull_out), outFile);
summary.output_rows = height(skull_out);
CVA_log_event('mri_skull_fex', 'run_summary', summary);
