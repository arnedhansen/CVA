%% CVA_preprocessing_mri_debug
%
% Extensive debugging script for MRI preprocessing / CAT12 segmentation.
% Run this on the server BEFORE CVA_preprocessing_mri to identify the source
% of "File not found or permission denied" and the Stroke Lesion / zeros alert.
%
% Output: printed report + optional CVA_mri_debug_report.txt
%
% Usage: Run in MATLAB with CVA project as current directory (or add to path).
%        Same environment as CVA_preprocessing_mri (startup, setup, SPM, CAT12).

%% 1. Environment setup (mirrors CVA_preprocessing_mri)
startup
[subjects, paths, ~, ~] = setup('CVA');

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
end

report = {};  % collect lines for report

fprintf('\n========== CVA MRI Preprocessing Debug Report ==========\n');
report{end+1} = '========== CVA MRI Preprocessing Debug Report =========='; fprintf('%s\n', report{end});
report{end+1} = datestr(now, 'yyyy-mm-dd HH:MM:SS'); fprintf('%s\n', report{end});

%% 2. Paths and directories
report{end+1} = ''; fprintf('%s\n', report{end});
report{end+1} = '--- 1. Paths ---'; fprintf('%s\n', report{end});
report{end+1} = sprintf('  paths.mri_raw  = %s', paths.mri_raw); fprintf('%s\n', report{end});
report{end+1} = sprintf('  paths.mri_proc = %s', paths.mri_proc); fprintf('%s\n', report{end});
report{end+1} = sprintf('  Current dir    = %s', pwd); fprintf('%s\n', report{end});

report{end+1} = ''; fprintf('%s\n', report{end});
report{end+1} = '  exist(paths.mri_raw):'; fprintf('%s\n', report{end});
if exist(paths.mri_raw, 'dir')
    report{end+1} = '    -> OK (directory exists)'; fprintf('%s\n', report{end});
else
    report{end+1} = '    -> FAIL (directory does not exist)'; fprintf('%s\n', report{end});
end

report{end+1} = ''; fprintf('%s\n', report{end});
report{end+1} = '  exist(paths.mri_proc):'; fprintf('%s\n', report{end});
if exist(paths.mri_proc, 'dir')
    report{end+1} = '    -> OK (directory exists)'; fprintf('%s\n', report{end});
else
    report{end+1} = sprintf('    -> FAIL (creating: %s)', paths.mri_proc); fprintf('%s\n', report{end});
    try mkdir(paths.mri_proc); report{end+1} = '    -> Created.'; fprintf('%s\n', report{end}); catch e, report{end+1} = sprintf('    -> Error: %s', e.message); fprintf('%s\n', report{end}); end
end

%% 3. SPM and CAT12
report{end+1} = ''; fprintf('%s\n', report{end});
report{end+1} = '--- 2. SPM / CAT12 ---'; fprintf('%s\n', report{end});
spmDir = spm('dir');
report{end+1} = sprintf('  spm(''dir'') = %s', spmDir); fprintf('%s\n', report{end});
report{end+1} = sprintf('  exist(spm_dir): %d', exist(spmDir, 'dir')); fprintf('%s\n', report{end});

% TPM (tissue probability map) - critical for segmentation
tpmPath = fullfile(spmDir, 'tpm', 'TPM.nii');
report{end+1} = ''; fprintf('%s\n', report{end});
report{end+1} = sprintf('  TPM.nii = %s', tpmPath); fprintf('%s\n', report{end});
if exist(tpmPath, 'file')
    report{end+1} = '    -> OK (exists)'; fprintf('%s\n', report{end});
    try
        V = spm_vol(tpmPath);
        report{end+1} = sprintf('    -> Readable, dim = [%s]', num2str(V.dim)); fprintf('%s\n', report{end});
    catch e
        report{end+1} = sprintf('    -> FAIL to read: %s', e.message); fprintf('%s\n', report{end});
    end
else
    report{end+1} = '    -> FAIL (file not found)'; fprintf('%s\n', report{end});
end

% Shooting template (CAT12) - structure varies by version
shootingtpm = cat_get_defaults('extopts.shootingtpm');
if isempty(shootingtpm) || ~exist(shootingtpm{1}, 'file')
    catDir = fileparts(which('cat_run'));
    if isempty(catDir), catDir = fileparts(which('cat_get_defaults')); end
    % Try common template locations (CAT12 version-dependent)
    tplCandidates = {
        fullfile(catDir, 'templates_MNI152NLin2009cAsym', 'Template_0_GS.nii')
        fullfile(catDir, 'templates_volumes', 'Template_0_GS.nii')
        fullfile(catDir, 'templates', 'Template_0_GS.nii')
    };
    for k = 1:numel(tplCandidates)
        if exist(tplCandidates{k}, 'file')
            shootingtpm = {tplCandidates{k}};
            break;
        end
    end
end

report{end+1} = ''; fprintf('%s\n', report{end});
report{end+1} = '  CAT12 shooting template:'; fprintf('%s\n', report{end});
if ~isempty(shootingtpm) && exist(shootingtpm{1}, 'file')
    report{end+1} = sprintf('    %s', shootingtpm{1}); fprintf('%s\n', report{end});
    report{end+1} = '    -> OK'; fprintf('%s\n', report{end});
else
    report{end+1} = '    -> FAIL (shooting template not found)'; fprintf('%s\n', report{end});
    report{end+1} = '    Check: cat_get_defaults(''extopts.shootingtpm'') and templates_* folders'; fprintf('%s\n', report{end});
end

%% 4. Input T1w files (first few subjects)
report{end+1} = ''; fprintf('%s\n', report{end});
report{end+1} = '--- 3. Input T1w files ---'; fprintf('%s\n', report{end});

nCheck = min(5, numel(subjects));
for i = 1:nCheck
    subID = subjects{i};
    anatDir = fullfile(paths.mri_raw, subID, 'ses-01', 'anat');
    t1wGz  = fullfile(anatDir, [subID '_ses-01_acq-mp2rage_T1w.nii.gz']);
    t1wNii = fullfile(anatDir, [subID '_ses-01_acq-mp2rage_T1w.nii']);
    destT1w = fullfile(paths.mri_proc, subID, 'anat', [subID '_ses-01_acq-mp2rage_T1w.nii']);

    report{end+1} = sprintf('  Subject %s:', subID); fprintf('%s\n', report{end});
    report{end+1} = sprintf('    raw .gz:  %s  exist=%d', t1wGz, exist(t1wGz, 'file')); fprintf('%s\n', report{end});
    report{end+1} = sprintf('    raw .nii: %s  exist=%d', t1wNii, exist(t1wNii, 'file')); fprintf('%s\n', report{end});
    report{end+1} = sprintf('    dest:     %s  exist=%d', destT1w, exist(destT1w, 'file')); fprintf('%s\n', report{end});

    if exist(destT1w, 'file')
        try
            V = spm_vol(destT1w);
            report{end+1} = sprintf('    spm_vol OK, dim=[%s]', num2str(V.dim)); fprintf('%s\n', report{end});
            Y = spm_read_vols(V);
            nz = sum(Y(:) == 0);
            nnz = numel(Y) - nz;
            report{end+1} = sprintf('    zeros: %d (%.2f%%), non-zero: %d', nz, 100*nz/numel(Y), nnz); fprintf('%s\n', report{end});
            report{end+1} = sprintf('    min=%.4g, max=%.4g, mean=%.4g', min(Y(:)), max(Y(:)), mean(Y(:))); fprintf('%s\n', report{end});
        catch e
            report{end+1} = sprintf('    FAIL to read: %s', e.message); fprintf('%s\n', report{end});
        end
    end
    report{end+1} = ''; fprintf('%s\n', report{end});
end

%% 5. spm_file('cpath') and path resolution
report{end+1} = ''; fprintf('%s\n', report{end});
report{end+1} = '--- 4. Path resolution (spm_file cpath) ---'; fprintf('%s\n', report{end});

% Build same nii_files as preprocessing
nii_files = {};
for s = 1:min(3, numel(subjects))
    subID = subjects{s};
    anatDir = fullfile(paths.mri_raw, subID, 'ses-01', 'anat');
    t1wGz   = fullfile(anatDir, [subID '_ses-01_acq-mp2rage_T1w.nii.gz']);
    t1wFile = strrep(t1wGz, '.nii.gz', '.nii');
    if ~exist(t1wFile, 'file') && exist(t1wGz, 'file')
        gunzip(t1wGz, anatDir);
    end
    if exist(t1wFile, 'file')
        outDir = fullfile(paths.mri_proc, subID, 'anat');
        if ~exist(outDir, 'dir'), mkdir(outDir); end
        destT1w = fullfile(outDir, [subID '_ses-01_acq-mp2rage_T1w.nii']);
        if ~exist(destT1w, 'file'), copyfile(t1wFile, destT1w); end
        nii_files{end+1} = destT1w; %#ok<AGROW>
    end
end

if ~isempty(nii_files)
    report{end+1} = '  Paths passed to matlabbatch (as in CVA_preprocessing_mri):'; fprintf('%s\n', report{end});
    for i = 1:numel(nii_files)
        raw = nii_files{i};
        cpath = spm_file(raw, 'cpath');
        report{end+1} = sprintf('    raw:   %s', raw); fprintf('%s\n', report{end});
        report{end+1} = sprintf('    cpath: %s', cpath); fprintf('%s\n', report{end});
        report{end+1} = sprintf('    exist(raw):   %d', exist(raw, 'file')); fprintf('%s\n', report{end});
        report{end+1} = sprintf('    exist(cpath): %d', exist(cpath, 'file')); fprintf('%s\n', report{end});
        report{end+1} = ''; fprintf('%s\n', report{end});
    end
end

%% 6. fopen / write test (simulates low-level file access)
report{end+1} = ''; fprintf('%s\n', report{end});
report{end+1} = '--- 5. File access tests (fopen) ---'; fprintf('%s\n', report{end});

testOutDir = fullfile(paths.mri_proc, subjects{1}, 'anat');
testFile = fullfile(testOutDir, 'debug_write_test.tmp');
try
    fid = fopen(testFile, 'w');
    if fid == -1
        report{end+1} = sprintf('  fopen(write) FAIL in %s', testOutDir); fprintf('%s\n', report{end});
        report{end+1} = '  Likely: permission denied or path invalid (check network drive / UNC)'; fprintf('%s\n', report{end});
    else
        fwrite(fid, 'test');
        fclose(fid);
        delete(testFile);
        report{end+1} = sprintf('  fopen(write) OK in %s', testOutDir); fprintf('%s\n', report{end});
    end
catch e
    report{end+1} = sprintf('  fopen error: %s', e.message); fprintf('%s\n', report{end});
end

if ~isempty(nii_files)
    testRead = nii_files{1};
    try
        fid = fopen(testRead, 'r');
        if fid == -1
            report{end+1} = sprintf('  fopen(read) FAIL for %s', testRead); fprintf('%s\n', report{end});
        else
            fclose(fid);
            report{end+1} = '  fopen(read) OK for first T1w'; fprintf('%s\n', report{end});
        end
    catch e
        report{end+1} = sprintf('  fopen(read) error: %s', e.message); fprintf('%s\n', report{end});
    end
end

%% 7. Zeros / Stroke Lesion alert context
report{end+1} = ''; fprintf('%s\n', report{end});
report{end+1} = '--- 6. Zeros-in-brain / Stroke Lesion alert context ---'; fprintf('%s\n', report{end});
report{end+1} = '  CAT12 reports "35.54 cm³ zeros within brain" when it detects'; fprintf('%s\n', report{end});
report{end+1} = '  many zeros inside the estimated brain mask. Possible causes:'; fprintf('%s\n', report{end});
report{end+1} = '  1. Data outside skull (air=0) included in brain mask'; fprintf('%s\n', report{end});
report{end+1} = '  2. MP2RAGE T1w: zeros in regions where INV1/INV2 ratio fails'; fprintf('%s\n', report{end});
report{end+1} = '  3. Truncated FOV or poor brain masking'; fprintf('%s\n', report{end});
report{end+1} = '  Fix: Enable Stroke Lesion Correction (SLC) in CAT12 expert mode,'; fprintf('%s\n', report{end});
report{end+1} = '  or improve input (skull-strip / check MP2RAGE processing).'; fprintf('%s\n', report{end});
report{end+1} = '  Zero fraction in first subject (above) gives a hint.'; fprintf('%s\n', report{end});

%% 8. matlabbatch dry run (no execution)
report{end+1} = ''; fprintf('%s\n', report{end});
report{end+1} = '--- 7. matlabbatch structure (first 2 data entries) ---'; fprintf('%s\n', report{end});

if ~isempty(nii_files)
    nii_files_abs = cellfun(@(x) spm_file(x, 'cpath'), nii_files, 'UniformOutput', false);
    for i = 1:min(2, numel(nii_files_abs))
        report{end+1} = sprintf('  data{%d} = %s', i, nii_files_abs{i}); fprintf('%s\n', report{end});
    end
end

%% 9. Save report
if isfield(paths, 'logs')
    reportDir = paths.logs;
else
    reportDir = fullfile(fileparts(paths.mri_raw), '..', 'logs');
end
reportPath = fullfile(reportDir, 'CVA_mri_debug_report.txt');
if ~exist(reportDir, 'dir'), mkdir(reportDir); end
fid = fopen(reportPath, 'w');
if fid ~= -1
    for i = 1:numel(report)
        fprintf(fid, '%s\n', report{i});
    end
    fclose(fid);
    report{end+1} = ''; fprintf('%s\n', report{end});
    report{end+1} = sprintf('Report saved to: %s', reportPath); fprintf('%s\n', report{end});
else
    report{end+1} = sprintf('Could not write report to %s', reportPath); fprintf('%s\n', report{end});
end

fprintf('\n========== End of Debug Report ==========\n');
