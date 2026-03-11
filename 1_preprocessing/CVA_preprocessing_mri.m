%% CVA_preprocessing_mri
%
% Runs CAT12 segmentation on MP2RAGE structural images.
%
% Outputs per subject (written by CAT12 into paths.mri_proc/subID/):
%   mri/p1*.nii       — GM probability map
%   mri/p2*.nii       — WM probability map
%   mri/p3*.nii       — CSF probability map
%   mri/p4*.nii       — Bone probability map      [requires TPMC, see below]
%   mri/p5*.nii       — Soft tissue probability map [requires TPMC]
%   report/cat_*.xml  — CAT12 report with vol_abs_CGW volumetrics
%
% TPMC NOTE:
%   Skull thickness estimation (CVA_mri_fex_skull) requires the p4 bone map.
%   This is only produced when CAT12's Tissue Probability Map (TPMC) output
%   is enabled. This script enables it explicitly via:
%     matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.native = 1
%   No additional CAT12 installation is needed — this is a standard option
%   in any recent CAT12 release (r1600+).
%
% Input:  paths.mri_raw / sub-XXXXXX / ses-01 / anat /
%           sub-XXXXXX_ses-01_acq-mp2rage_T1w.nii.gz   ← used for segmentation
%           sub-XXXXXX_ses-01_T2w.nii.gz                ← used for skull refinement
%
% Output: CAT12 outputs written to paths.mri_proc / sub-XXXXXX / anat /
%         (CAT12 creates mri/ and report/ subfolders automatically)

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

%% Collect NIfTI files and prepare output directories
% LEMON raw structure: sub-XXX/ses-01/anat/
%   T1w: sub-XXX_ses-01_acq-mp2rage_T1w.nii.gz  ← full head, use for CAT12
%   T2w: sub-XXX_ses-01_T2w.nii.gz               ← passed to CAT12 for skull refinement
%
% NOTE: Do NOT use the _brain.nii.gz files in MRI_Preprocessed_Derivatives —
% those are skull-stripped and cannot produce the p4 bone map needed for
% skull thickness estimation.

nii_files  = {};   % T1w paths (CAT12 primary input)
t2w_files  = {};   % T2w paths (CAT12 skull channel, one entry per subject or '')
valid_subjects = {};

for s = 1:numel(subjects)
    subID   = subjects{s};
    anatDir = fullfile(paths.mri_raw, subID, 'ses-01', 'anat');

    % --- T1w (MP2RAGE, full head) ---
    t1wGz   = fullfile(anatDir, [subID '_ses-01_acq-mp2rage_T1w.nii.gz']);
    t1wFile = strrep(t1wGz, '.nii.gz', '.nii');

    if exist(t1wGz, 'file') && ~exist(t1wFile, 'file')
        fprintf('[PREPROC] Decompressing T1w for %s\n', subID);
        gunzip(t1wGz, anatDir);
    end

    if ~exist(t1wFile, 'file')
        warning('[PREPROC] T1w not found for %s — skipping.', subID);
        continue;
    end

    % --- T2w (for skull boundary refinement in CAT12) ---
    t2wGz   = fullfile(anatDir, [subID '_ses-01_T2w.nii.gz']);
    t2wFile = strrep(t2wGz, '.nii.gz', '.nii');

    if exist(t2wGz, 'file') && ~exist(t2wFile, 'file')
        fprintf('[PREPROC] Decompressing T2w for %s\n', subID);
        gunzip(t2wGz, anatDir);
    end

    has_t2w = exist(t2wFile, 'file');
    if ~has_t2w
        warning('[PREPROC] T2w not found for %s — skull segmentation will use T1w only.', subID);
    end

    % --- Copy to mri_proc so CAT12 outputs land there ---
    outDir = fullfile(paths.mri_proc, subID, 'anat');
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    destT1w = fullfile(outDir, [subID '_ses-01_acq-mp2rage_T1w.nii']);
    if ~exist(destT1w, 'file')
        copyfile(t1wFile, destT1w);
    end

    nii_files{end+1}      = destT1w; %#ok<AGROW>
    valid_subjects{end+1} = subID;   %#ok<AGROW>

    if has_t2w
        destT2w = fullfile(outDir, [subID '_ses-01_T2w.nii']);
        if ~exist(destT2w, 'file')
            copyfile(t2wFile, destT2w);
        end
        t2w_files{end+1} = destT2w; %#ok<AGROW>
    else
        t2w_files{end+1} = ''; %#ok<AGROW>
    end
end

fprintf('[PREPROC] Found %d subjects with usable NIfTI files.\n', numel(nii_files));

if isempty(nii_files)
    error('[PREPROC] No NIfTI files found. Check paths.mri_raw and filename convention.');
end

%% Build CAT12 matlabbatch
% This configures the full CAT12 surface + volume pipeline with:
%   - Standard 3-class tissue segmentation (GM/WM/CSF → p1/p2/p3)
%   - TPMC enabled for skull/bone map (→ p4) needed by CVA_mri_fex_skull
%   - CAT12 XML report output needed by CVA_mri_fex_csf
%
% All other settings are CAT12 defaults. If you need to adjust templates
% or registration options, do so here.

matlabbatch{1}.spm.tools.cat.estwrite.data = nii_files';

% --- T2w images for skull boundary refinement ---
% CAT12 uses the T2w as an additional channel to better delineate the
% inner/outer skull surfaces — this directly improves p4 bone map quality.
% For subjects without T2w, we pass an empty string (CAT12 handles this).
matlabbatch{1}.spm.tools.cat.estwrite.data_wmh = t2w_files';

% --- Parallel processing: use available cores ---
% Set to 0 to disable, or a specific number (e.g. 4) to limit core usage
matlabbatch{1}.spm.tools.cat.estwrite.nproc = 0;  % 0 = auto (all cores)

% --- Segmentation options (defaults are fine for MP2RAGE) ---
matlabbatch{1}.spm.tools.cat.estwrite.opts.tpm        = ...
    {fullfile(spm('dir'), 'tpm', 'TPM.nii')};
matlabbatch{1}.spm.tools.cat.estwrite.opts.affreg     = 'mni';
matlabbatch{1}.spm.tools.cat.estwrite.opts.biasstr    = 0.5;
matlabbatch{1}.spm.tools.cat.estwrite.opts.accstr     = 0.5;

% --- Extended segmentation (AMAP) ---
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.APP        = 1070;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.NCstr      = Inf;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.LASstr     = 0.5;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.gcutstr    = 2;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.cleanupstr = 0.5;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.BVCstr     = 0.5;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.restypes.optimal = [1 0.3];

% --- Surface reconstruction (needed for cortical thickness; keep enabled) ---
matlabbatch{1}.spm.tools.cat.estwrite.extopts.surface.pbtres          = 0.5;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.surface.scale_cortex    = 0.7;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.surface.add_parahipp    = 0.1;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.surface.close_parahipp  = 1;

% --- Output: tissue probability maps in native space ---
% p1 = GM, p2 = WM, p3 = CSF (standard)
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.native  = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.mod     = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.dartel  = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.native  = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.mod     = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.dartel  = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.native = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.mod    = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.dartel = 0;

% --- TPMC: Extended tissue classes including bone (p4) ---
% p4 = bone (compact + spongy skull)
% p5 = soft tissue (scalp)
% p6 = air (head cavities) — not needed, kept off
% IMPORTANT: This is what enables CVA_mri_fex_skull to find p4*.nii
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.native = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.mod    = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.dartel = 0;

% --- Label maps (useful for QC) ---
matlabbatch{1}.spm.tools.cat.estwrite.output.label.native  = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.label.warped  = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.label.dartel  = 0;

% --- Jacobian / deformation fields: off (not needed for this study) ---
matlabbatch{1}.spm.tools.cat.estwrite.output.jacobianwarped = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.warps          = [0 0];

%% Run CAT12
fprintf('[PREPROC] Starting CAT12 for %d subjects...\n', numel(nii_files));
fprintf('[PREPROC] This will take approximately %d–%d minutes.\n', ...
    numel(nii_files) * 15, numel(nii_files) * 25);

spm('defaults', 'fmri');
spm_jobman('initcfg');
spm_jobman('run', matlabbatch);

fprintf('[PREPROC] CAT12 finished.\n');

%% Post-run: verify outputs and warn about missing files
fprintf('[PREPROC] Verifying outputs...\n');
n_ok = 0; n_missing_xml = 0; n_missing_p4 = 0;

for s = 1:numel(valid_subjects)
    subID  = valid_subjects{s};
    outDir = fullfile(paths.mri_proc, subID);

    % CAT12 writes report/ and mri/ relative to the input NIfTI location,
    % which we set to paths.mri_proc/subID/anat/ — so outputs land there.
    xmlPattern = dir(fullfile(outDir, 'anat', 'report', ['cat_' subID '_ses-01_acq-mp2rage_T1w*.xml']));
    p4Pattern  = dir(fullfile(outDir, 'anat', 'mri',    'p4*.nii'));

    xml_ok = ~isempty(xmlPattern);
    p4_ok  = ~isempty(p4Pattern);

    if xml_ok && p4_ok
        n_ok = n_ok + 1;
    else
        if ~xml_ok
            warning('[PREPROC] Missing CAT12 XML report for %s', subID);
            n_missing_xml = n_missing_xml + 1;
        end
        if ~p4_ok
            warning('[PREPROC] Missing p4 bone map for %s (TPMC may not have run)', subID);
            n_missing_p4 = n_missing_p4 + 1;
        end
    end
end

fprintf('[PREPROC] Complete: %d/%d subjects OK | %d missing XML | %d missing p4\n', ...
    n_ok, numel(valid_subjects), n_missing_xml, n_missing_p4);

%% IMPORTANT: Update paths in fex scripts
% CVA_mri_fex_csf expects XML at:
%   paths.mri_proc / subID / report / cat_*.xml
%
% CVA_mri_fex_skull expects p4 map at:
%   paths.mri_proc / subID / mri / p4*.nii
%
% CAT12 writes these relative to the input file location, which we set to:
%   paths.mri_proc / subID / anat /
%
% So the actual paths will be:
%   paths.mri_proc / subID / anat / report / cat_*.xml
%   paths.mri_proc / subID / anat / mri    / p4*.nii
%
% --> Either update fex scripts to include the 'anat' subfolder,
%     OR move outputs after CAT12 runs (uncomment block below).

% % Optional: flatten CAT12 output (moves mri/ and report/ up one level)
% for s = 1:numel(valid_subjects)
%     subID   = valid_subjects{s};
%     anatOut = fullfile(paths.mri_proc, subID, 'anat');
%     subOut  = fullfile(paths.mri_proc, subID);
%     for fold = {'mri', 'report', 'surf'}
%         src = fullfile(anatOut, fold{1});
%         dst = fullfile(subOut,  fold{1});
%         if exist(src, 'dir') && ~exist(dst, 'dir')
%             movefile(src, dst);
%         end
%     end
% end
