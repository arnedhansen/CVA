%% CVA_mri_fex_skull
%
% Estimates mean skull thickness per subject as a nuisance covariate.
%
% Approach:
%   1. Load CAT12 p4 (bone) and p5 (soft tissue) probability maps
%   2. Threshold to binary masks and combine into a full skull mask
%   3. Restrict to a parietal-occipital ROI in MNI space — matching the
%      posterior electrode cluster used for alpha power (O1/O2/Oz/PO*)
%   4. For each coronal/axial column in the ROI, count the number of
%      skull voxels and multiply by voxel size → local thickness estimate
%   5. Average across all ROI columns → mean skull thickness in mm
%
% ROI definition (MNI coordinates, mm):
%   X: -60 to +60   (left-right, full width over posterior scalp)
%   Y: -120 to -60  (posterior, covers parietal-occipital)
%   Z:  -20 to +80  (inferior-superior, covers vault)
%
% Output: dirs.fex/CVA_skull_thickness.mat
%   skull_out: table with columns [subID, skull_thickness_mm]

%% Setup
dirs     = CVA_paths();
subjects = CVA_get_subjects();

% Parietal-occipital ROI in MNI mm coordinates
% Chosen to match posterior EEG electrode cluster (O1/O2/Oz/PO3/PO4/PO7/PO8)
roi_mni = struct();
roi_mni.X = [-60  60];    % mm left-right
roi_mni.Y = [-120 -60];   % mm anterior-posterior (negative = posterior)
roi_mni.Z = [-20   80];   % mm inferior-superior

skull_out = table();
summary = struct();
summary.total_subjects = numel(subjects);
summary.missing_bone_map = 0;
summary.failed = 0;
summary.saved = 0;

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[Skull FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    % CAT12 tissue class outputs in mri/ subfolder:
    %   p4 = bone (compact + spongy)
    %   p5 = soft tissue (not needed but useful for sanity check)
    % NOTE: CAT12 writes TPMC outputs with prefix 'p4_' when TPMC is
    % enabled. Adjust filename pattern if your CAT12 version differs.
    mriDir = fullfile(dirs.mri_proc, subID, 'mri');
    boneCandidates = dir(fullfile(mriDir, 'p4*.nii'));
    if isempty(boneCandidates)
        warning('Bone map not found for %s — skipping.', subID);
        summary.missing_bone_map = summary.missing_bone_map + 1;
        continue;
    end
    boneFile = fullfile(mriDir, boneCandidates(1).name);

    try
        %% Load bone probability map
        V = spm_vol(boneFile);
        Y = spm_read_vols(V);          % values: 0-1 bone probability

        %% Threshold to binary skull mask
        % p4 > 0.3: intentionally low threshold to capture full bone extent
        % including spongy (diploë) layer which has lower CAT12 probability
        skullMask = Y > 0.3;

        %% Convert ROI MNI bounds to voxel indices
        % V.mat is the 4x4 affine: [X;Y;Z;1] = mat * [i;j;k;1]
        % Invert to go from MNI mm → voxel indices
        mat_inv = inv(V.mat);

        % Get voxel coords of ROI corners
        corners_mni = [
            roi_mni.X(1) roi_mni.Y(1) roi_mni.Z(1) 1;
            roi_mni.X(2) roi_mni.Y(2) roi_mni.Z(2) 1
            ]';
        corners_vox = mat_inv * corners_mni;

        % Voxel index ranges (sorted, clamped to volume dims)
        dims = size(Y);
        xi   = max(1, min(dims(1), round(sort(corners_vox(1,:)))));
        yi   = max(1, min(dims(2), round(sort(corners_vox(2,:)))));
        zi   = max(1, min(dims(3), round(sort(corners_vox(3,:)))));

        %% Extract ROI subvolume
        roiMask = skullMask(xi(1):xi(2), yi(1):yi(2), zi(1):zi(2));

        %% Compute thickness: for each superior-inferior column (x,z),
        % count consecutive skull voxels along Y (anterior-posterior axis).
        % This gives a radial depth estimate through the bone at each
        % scalp location over the posterior ROI.
        voxSize_xyz = sqrt(sum(V.mat(1:3,1:3).^2, 1));
        voxSize_mm  = mean(voxSize_xyz);
        nX          = size(roiMask, 1);
        nZ          = size(roiMask, 3);
        colThickness = zeros(nX, nZ);

        for xi_ = 1:nX
            for zi_ = 1:nZ
                col             = roiMask(xi_, :, zi_);   % 1 x nY
                colThickness(xi_, zi_) = sum(col) * voxSize_mm;
            end
        end

        % Only average over columns that actually contain skull voxels
        % (zero columns = outside head entirely, should not bias mean)
        validCols     = colThickness > 0;
        skullThickMM  = mean(colThickness(validCols));

        fprintf('  Skull thickness: %.2f mm  (ROI voxels: %d)\n', ...
            skullThickMM, sum(validCols(:)));

        %% Append
        row       = table({subID}, skullThickMM, ...
                          'VariableNames', {'subID','skull_thickness_mm'});
        skull_out = [skull_out; row]; %#ok<AGROW>
        summary.saved = summary.saved + 1;
        CVA_log_event('mri_skull_fex', 'subject_processed', struct( ...
            'subID', subID, ...
            'skull_thickness_mm', skullThickMM, ...
            'n_valid_roi_columns', sum(validCols(:))));

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
        summary.failed = summary.failed + 1;
        CVA_log_event('mri_skull_fex', 'subject_failed', struct( ...
            'subID', subID, ...
            'error', ME.message));
    end
end

%% Save
outFile = fullfile(dirs.fex, 'CVA_skull_thickness.mat');
save(outFile, 'skull_out');
fprintf('Saved skull thickness for %d subjects to %s\n', height(skull_out), outFile);
summary.output_rows = height(skull_out);
CVA_log_event('mri_skull_fex', 'run_summary', summary);
