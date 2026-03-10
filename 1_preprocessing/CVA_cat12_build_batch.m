function matlabbatch = CVA_cat12_build_batch(nii_files, dirs)
% CVA_CAT12_BUILD_BATCH  Constructs the CAT12 segmentation matlabbatch.
%
%   matlabbatch = CVA_cat12_build_batch(nii_files, dirs)
%
%   nii_files : cell array of NIfTI paths with volume index, e.g.
%               {'/path/sub-032301_...brain.nii,1', ...}
%   dirs      : struct from CVA_paths()
%
%   Returns a matlabbatch struct ready for spm_jobman('run', matlabbatch).
%
% CAT12 settings are configured for:
%   - MP2RAGE T1 input (no bias correction needed — already uniform)
%   - Full volumetric segmentation (GM, WM, CSF, bone, soft tissue)
%   - Surface reconstruction DISABLED (not needed, saves ~10x time)
%   - Native space tissue maps saved (p1, p2, p3)
%   - Bone map saved (p4) for skull thickness extraction
%   - XML report saved for volume extraction in CVA_mri_fex_csf.m

%% --- Segmentation & Spatial Normalization ---
matlabbatch{1}.spm.tools.cat.estwrite.data = nii_files(:);

% Expert options: use default CAT12 shooting registration
matlabbatch{1}.spm.tools.cat.estwrite.data_wmh = {''};

% CAT12 internal registration (Shooting)
matlabbatch{1}.spm.tools.cat.estwrite.nproc = 0;   % 0 = use all available cores

%% --- APP (Adaptive MRI Preprocessing) ---
% 0=none, 1070=default light, 1144=full. Use 1070 for MP2RAGE (already clean)
matlabbatch{1}.spm.tools.cat.estwrite.opts.tpm = ...
    {fullfile(spm('dir'), 'tpm', 'TPM.nii')};
matlabbatch{1}.spm.tools.cat.estwrite.opts.affreg      = 'mni';
matlabbatch{1}.spm.tools.cat.estwrite.opts.biasstr      = 0.5;   % light bias correction
matlabbatch{1}.spm.tools.cat.estwrite.opts.accstr       = 0.5;   % accuracy/speed tradeoff
matlabbatch{1}.spm.tools.cat.estwrite.opts.APP          = 1070;
matlabbatch{1}.spm.tools.cat.estwrite.opts.redspmres    = 0;

%% --- Segmentation options ---
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.restypes.optimal = [1 0.3];
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.setCOM           = 1;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.mrf              = 1;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.cleanupstr       = 0.5;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.WMHC             = 1;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.SLC              = 0;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.segmentation.fix_val          = 0;

%% --- Registration (Shooting) ---
matlabbatch{1}.spm.tools.cat.estwrite.extopts.registration.T1               = ...
    {fullfile(spm('dir'), 'toolbox', 'cat12', 'templates_MNI152NLin2009cAsym', 'T1.nii')};
matlabbatch{1}.spm.tools.cat.estwrite.extopts.registration.brainmask        = ...
    {fullfile(spm('dir'), 'toolbox', 'cat12', 'templates_MNI152NLin2009cAsym', 'brainmask.nii')};
matlabbatch{1}.spm.tools.cat.estwrite.extopts.registration.cat12atlas       = ...
    {fullfile(spm('dir'), 'toolbox', 'cat12', 'templates_MNI152NLin2009cAsym', 'cat.nii')};
matlabbatch{1}.spm.tools.cat.estwrite.extopts.registration.darteltpm        = ...
    {fullfile(spm('dir'), 'toolbox', 'cat12', 'templates_volumes', 'Template_1_IXI555_MNI152_GS.nii')};
matlabbatch{1}.spm.tools.cat.estwrite.extopts.registration.shootingtpm      = ...
    {fullfile(spm('dir'), 'toolbox', 'cat12', 'templates_volumes', 'Template_0_IXI555_MNI152_GS.nii')};
matlabbatch{1}.spm.tools.cat.estwrite.extopts.registration.regstr           = 0.5;

%% --- Voxel size for normalized output ---
matlabbatch{1}.spm.tools.cat.estwrite.extopts.vox        = 1.5;   % mm, normalized space
matlabbatch{1}.spm.tools.cat.estwrite.extopts.bb         = 12;    % bounding box

%% --- Surface reconstruction: DISABLED (not needed for volumetry) ---
matlabbatch{1}.spm.tools.cat.estwrite.extopts.surface.pbtres          = 0.5;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.surface.pbtmethod       = 'pbt2x';
matlabbatch{1}.spm.tools.cat.estwrite.extopts.surface.SRP             = 22;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.surface.reduce_mesh     = 1;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.surface.vdist           = 1.33333333333333;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.surface.scale_cortex    = 0.7;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.surface.add_parahipp    = 0;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.surface.close_parahipp  = 1;

% KEY: set dosurf = 0 to skip surface recon entirely
matlabbatch{1}.spm.tools.cat.estwrite.output.surface = 0;

%% --- Admin / quality control ---
matlabbatch{1}.spm.tools.cat.estwrite.extopts.admin.experimental  = 0;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.admin.new_release    = 0;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.admin.lazy           = 0;   % 0 = reprocess all
matlabbatch{1}.spm.tools.cat.estwrite.extopts.admin.ignoreErrors   = 1;   % continue on failure
matlabbatch{1}.spm.tools.cat.estwrite.extopts.admin.verb           = 2;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.admin.print          = 2;   % save PDF report

%% --- Output: tissue maps in native space ---
% GM (p1), WM (p2), CSF (p3)
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.native    = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.warped    = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.mod       = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.dartel    = 0;

matlabbatch{1}.spm.tools.cat.estwrite.output.WM.native    = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.warped    = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.mod       = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.dartel    = 0;

matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.native   = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.warped   = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.mod      = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.dartel   = 0;

% WMH label map
matlabbatch{1}.spm.tools.cat.estwrite.output.WMH.native   = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WMH.warped   = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WMH.mod      = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WMH.dartel   = 0;

% Skull/bone map (p4) — needed for skull thickness in CVA_mri_fex_skull.m
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.native  = 1;   % all 6 tissue classes
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.warped  = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.mod     = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.dartel  = 0;

% Label image (p0 — integer tissue class map)
matlabbatch{1}.spm.tools.cat.estwrite.output.label.native = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.label.warped = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.label.dartel = 0;

% Bias-corrected T1 in native space (useful for QC)
matlabbatch{1}.spm.tools.cat.estwrite.output.bias.native  = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.bias.warped  = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.bias.dartel  = 0;

% Jacobian — not needed
matlabbatch{1}.spm.tools.cat.estwrite.output.jacobianwarped = 0;

% Warped images to MNI — not needed for volumetry
matlabbatch{1}.spm.tools.cat.estwrite.output.warps = [0 0];

end
