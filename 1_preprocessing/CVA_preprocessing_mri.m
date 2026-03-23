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
% Input:  paths.mri_raw / sub-XXXXXX / ses-01 / anat /
%           sub-XXXXXX_ses-01_acq-mp2rage_T1w.nii.gz   ← used for segmentation
%           sub-XXXXXX_ses-01_T2w.nii.gz                ← used for skull refinement
%
% Output: CAT12 outputs written to paths.mri_proc / sub-XXXXXX / anat /
%         (CAT12 creates mri/ and report/ subfolders automatically)

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

% SPM/CAT12: ensure on path before matlabbatch (needed for spm('dir') below) 
% On servers (e.g. Windows W:\) startup may not add SPM. Fallback to methlab SPM:
if ~exist('spm', 'file')
    if ispc
        SPM_DIR = 'W:\Students\Arne\toolboxes\spm12';
    else
        SPM_DIR = '/Volumes/g_psyplafor_methlab$/Students/Arne/toolboxes/spm12';
    end
    addpath(SPM_DIR);
    addpath(fullfile(SPM_DIR, 'toolbox', 'cat12'));
    spm('defaults', 'fmri');
    spm_jobman('initcfg');
    fprintf('[MRI Preprocessing] SPM loaded from %s\n', SPM_DIR);
end

% Paths check
firstSub = subjects{1};
exampleAnat = fullfile(paths.mri_raw, firstSub, 'ses-01', 'anat');
exampleT1w = fullfile(exampleAnat, [firstSub '_ses-01_acq-mp2rage_T1w.nii.gz']);
fprintf('[MRI Preprocessing] paths.mri_raw = %s\n', paths.mri_raw);
fprintf('[MRI Preprocessing] Example T1w:   %s\n', exampleT1w);
if ~exist(paths.mri_raw, 'dir')
    error('[MRI Preprocessing] paths.mri_raw does not exist. Check setup or data location.');
end

%% Collect NIfTI files and prepare output directories
% LEMON raw structure: sub-XXX/ses-01/anat/
%   T1w: sub-XXX_ses-01_acq-mp2rage_T1w.nii.gz     full head for CAT12
%   T2w: sub-XXX_ses-01_T2w.nii.gz                 optional (not used by CAT12; reserved for future use)

nii_files  = {};   % T1w paths (CAT12 primary input)
t2w_files  = {};   % T2w paths (CAT12 skull channel, one entry per subject or '')
valid_subjects = {};
missing_t1w = {};  % subjects skipped due to missing T1w

for s = 1:numel(subjects)
    subID   = subjects{s};
    anatDir = fullfile(paths.mri_raw, subID, 'ses-01', 'anat');

    % T1w (MP2RAGE, full head) 
    t1wGz   = fullfile(anatDir, [subID '_ses-01_acq-mp2rage_T1w.nii.gz']);
    t1wFile = strrep(t1wGz, '.nii.gz', '.nii');

    if exist(t1wGz, 'file') && ~exist(t1wFile, 'file')
        fprintf('[MRI Preprocessing] Decompressing T1w for %s\n', subID);
        gunzip(t1wGz, anatDir);
    end

    if ~exist(t1wFile, 'file')
        missing_t1w{end+1} = subID; %#ok<AGROW>
        continue;
    end

    % T2w (for skull boundary refinement in CAT12) 
    t2wGz   = fullfile(anatDir, [subID '_ses-01_T2w.nii.gz']);
    t2wFile = strrep(t2wGz, '.nii.gz', '.nii');

    if exist(t2wGz, 'file') && ~exist(t2wFile, 'file')
        fprintf('[MRI Preprocessing] Decompressing T2w for %s\n', subID);
        gunzip(t2wGz, anatDir);
    end

    has_t2w = exist(t2wFile, 'file');
    if ~has_t2w
        warning('[MRI Preprocessing] T2w not found for %s (optional; CAT12 uses T1w only).', subID);
    end

    % Copy to mri_proc so CAT12 outputs land there 
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

fprintf('[MRI Preprocessing] Found %d subjects with usable NIfTI files.\n', numel(nii_files));

if ~isempty(missing_t1w)
    warning('[MRI Preprocessing] T1w not found for %d subjects — skipped. Example: %s', ...
        numel(missing_t1w), missing_t1w{1});
    if numel(missing_t1w) <= 5
        fprintf('[MRI Preprocessing] Missing: %s\n', strjoin(missing_t1w, ', '));
    else
        fprintf('[MRI Preprocessing] Missing (first 5): %s ... and %d more.\n', ...
            strjoin(missing_t1w(1:5), ', '), numel(missing_t1w) - 5);
    end
end

if isempty(nii_files)
    error(['[MRI Preprocessing] No NIfTI files found.\n', ...
        'Check: (1) paths.mri_raw in setup, (2) raw MRI placed at:\n', ...
        '  %s/sub-XXXXXX/ses-01/anat/sub-XXXXXX_ses-01_acq-mp2rage_T1w.nii.gz\n', ...
        'Example path printed above.'], paths.mri_raw);
end

%% Build CAT12 matlabbatch
% Optimized for 1 mm accuracy, CSF volume (vol_abs_CGW), and skull thickness (p4).
%   - Standard tissue segmentation (GM/WM/CSF → p1/p2/p3) → CSF from XML
%   - TPMC (p4 bone) → skull thickness via CVA_mri_fex_skull
%
% NOTE: CAT12 batch structure varies by version. This uses the FLAT opts/extopts
% structure (no opts.segmentation, opts.surface sub-structs). If you see
% "No field(s) named" errors, check your CAT12 version and cfg_*.m batch config.

matlabbatch{1}.spm.tools.cat.estwrite.data = nii_files';  % T1w input images for segmentation

% WMH/lesion correction input (FLAIR). Empty = T1-only (do not use T2w).
matlabbatch{1}.spm.tools.cat.estwrite.data_wmh = repmat({''}, numel(nii_files), 1);

matlabbatch{1}.spm.tools.cat.estwrite.nproc = 8;  % parallel processes (0 = auto)

% opts — basic options (flat; avoid biasstr/accstr if your CAT12 uses biasacc)
matlabbatch{1}.spm.tools.cat.estwrite.opts.tpm    = ...
    {fullfile(spm('dir'), 'tpm', 'TPM.nii')};
matlabbatch{1}.spm.tools.cat.estwrite.opts.affreg = 'mni';
% Use biasacc (single param) — older CAT12; remove if your version uses biasstr/accstr
matlabbatch{1}.spm.tools.cat.estwrite.opts.biasacc = 0.75;

% extopts — only fields accepted by flat batch (NCstr, cleanupstr, BVCstr, pbtres
% cause "No field(s) named" in some CAT12/SPM25 versions)
matlabbatch{1}.spm.tools.cat.estwrite.extopts.APP        = 1070;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.setCOM     = 1;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.LASstr     = 0.5;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.gcutstr    = 0;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.WMHC       = 2;
% registration: explicit Shooting struct (avoids "unresolved dependencies" when omitted or '<UNDEFINED>')
shootingtpm = cat_get_defaults('extopts.shootingtpm');
if isempty(shootingtpm) || ~exist(shootingtpm{1}, 'file')
    tplDir = fullfile(fileparts(which('spm_CAT')), 'templates_MNI152NLin2009cAsym');
    tplPath = fullfile(tplDir, 'Template_0_GS.nii');
    if exist(tplPath, 'file')
        shootingtpm = {tplPath};
    else
        error('[MRI Preprocessing] CAT12 shooting template not found. Check: %s', tplPath);
    end
end
matlabbatch{1}.spm.tools.cat.estwrite.extopts.registration.shooting.shootingtpm = shootingtpm;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.registration.shooting.regstr = 0.5;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.ignoreErrors = 1;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.vox        = 1;     % 1 mm normalized output
% Resolution for internal processing
matlabbatch{1}.spm.tools.cat.estwrite.extopts.restypes.fixed = [1 0.1];

% Output: tissue probability maps (p1=GM, p2=WM, p3=CSF)
matlabbatch{1}.spm.tools.cat.estwrite.output.surface    = 0;   % skip surface (not needed for CVA)
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.native  = 1;   % write GM in native space
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.mod     = 0;   % no modulated normalized
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.dartel  = 0;   % no Dartel export
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.native  = 1;   % write WM in native space
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.mod     = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.dartel  = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.native = 1;   % write CSF in native space
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.mod    = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.dartel = 0;

% TPMC: extended classes (p4=bone, p5=soft tissue)
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.native = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.mod    = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.dartel = 0;

% PVE label map (tissue labels)
matlabbatch{1}.spm.tools.cat.estwrite.output.label.native  = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.label.warped  = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.label.dartel  = 0;

matlabbatch{1}.spm.tools.cat.estwrite.output.jacobianwarped = 0;  % no Jacobian
matlabbatch{1}.spm.tools.cat.estwrite.output.warps          = [0 0];  % no deformations

%% Run CAT12
fprintf('[MRI Preprocessing] Starting CAT12 for %d subjects...\n', numel(nii_files));
fprintf('[MRI Preprocessing] This will take approximately %d–%d minutes.\n', ...
    numel(nii_files) * 15, numel(nii_files) * 25);

spm('defaults', 'fmri');
spm_jobman('initcfg');
spm_jobman('run', matlabbatch);

fprintf('[MRI Preprocessing] CAT12 finished.\n');

%% Post-run: verify outputs and warn about missing files
fprintf('[MRI Preprocessing] Verifying outputs...\n');
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
            warning('[MRI Preprocessing] Missing CAT12 XML report for %s', subID);
            n_missing_xml = n_missing_xml + 1;
        end
        if ~p4_ok
            warning('[MRI Preprocessing] Missing p4 bone map for %s (TPMC may not have run)', subID);
            n_missing_p4 = n_missing_p4 + 1;
        end
    end
end

fprintf('[MRI Preprocessing] Complete: %d/%d subjects OK | %d missing XML | %d missing p4\n', ...
    n_ok, numel(valid_subjects), n_missing_xml, n_missing_p4);
