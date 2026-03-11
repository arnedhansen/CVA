%% CVA_mri_fex_csf
%
% Extracts tissue volumes from CAT12 segmentation output per subject.
%
% Raw volumes (ml):
%   TBV  = GM + WM  (total brain volume)
%   GM   = gray matter
%   WM   = white matter
%   CSF  = cerebrospinal fluid
%   TIV  = total intracranial volume
%
% TIV-corrected volumes (% of TIV) — these enter statistical models:
%   CSF_TIV = CSF / TIV * 100
%   GM_TIV  = GM  / TIV * 100
%   WM_TIV  = WM  / TIV * 100
%
% Raw volumes are retained in the output table for descriptive statistics.
% TIV correction removes the confound of head size: larger heads contain
% more tissue for purely geometric reasons, independent of atrophy or
% group differences (Buckner et al., 2004).
%
% Source: CAT12 XML report (cat_*.xml), fields:
%   subjectmeasures.vol_abs_CGW  → [CSF, GM, WM] in ml
%   subjectmeasures.vol_TIV      → TIV in ml
%
% Output: paths.mri_fex/CVA_mri_volumes.mat
%   vol_out: table with columns
%     [subID, TBV, GM, WM, CSF, TIV, CSF_TIV, GM_TIV, WM_TIV]

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

vol_out = table();
summary = struct();
summary.total_subjects         = numel(subjects);
summary.missing_xml            = 0;
summary.missing_vol_abs_cgw    = 0;
summary.bad_vol_abs_cgw_format = 0;
summary.missing_tiv            = 0;
summary.bad_tiv                = 0;
summary.failed                 = 0;
summary.saved                  = 0;

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[MRI CSF FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    xmlFile = fullfile(paths.mri_proc, subID, 'anat', 'report', ...
                       ['cat_' subID '_ses-01_acq-mp2rage_T1w.xml']);

    if ~exist(xmlFile, 'file')
        warning('CAT12 XML not found for %s', subID);
        summary.missing_xml = summary.missing_xml + 1;
        CVA_log_event('mri_csf_fex', 'subject_skip_missing_xml', ...
            struct('subID', subID, 'expected_xml', xmlFile));
        continue;
    end

    try
        S = cat_io_xml(xmlFile);

        %% Tissue volumes
        if ~isfield(S, 'subjectmeasures') || ~isfield(S.subjectmeasures, 'vol_abs_CGW')
            warning('Missing vol_abs_CGW in CAT12 XML for %s', subID);
            summary.missing_vol_abs_cgw = summary.missing_vol_abs_cgw + 1;
            continue;
        end

        cgw = S.subjectmeasures.vol_abs_CGW;
        if numel(cgw) < 3
            warning('Unexpected vol_abs_CGW format for %s (expected 3, got %d)', ...
                subID, numel(cgw));
            summary.bad_vol_abs_cgw_format = summary.bad_vol_abs_cgw_format + 1;
            continue;
        end

        % CAT12 order: [CSF, GM, WM]
        csf = cgw(1);
        gm  = cgw(2);
        wm  = cgw(3);
        tbv = gm + wm;

        %% TIV
        if ~isfield(S.subjectmeasures, 'vol_TIV')
            warning('Missing vol_TIV in CAT12 XML for %s', subID);
            summary.missing_tiv = summary.missing_tiv + 1;
            continue;
        end

        tiv = S.subjectmeasures.vol_TIV;
        if ~isscalar(tiv) || ~isfinite(tiv) || tiv <= 0
            warning('Invalid vol_TIV (%.4g) for %s — skipping', tiv, subID);
            summary.bad_tiv = summary.bad_tiv + 1;
            continue;
        end

        %% TIV-corrected volumes (% of TIV)
        csf_tiv = (csf / tiv) * 100;
        gm_tiv  = (gm  / tiv) * 100;
        wm_tiv  = (wm  / tiv) * 100;

        fprintf('  CSF: %.1fml (%.1f%%)  GM: %.1fml (%.1f%%)  WM: %.1fml (%.1f%%)  TIV: %.1fml\n', ...
            csf, csf_tiv, gm, gm_tiv, wm, wm_tiv, tiv);

        %% Append
        row = table({subID}, tbv, gm, wm, csf, tiv, csf_tiv, gm_tiv, wm_tiv, ...
                    'VariableNames', ...
                    {'subID','TBV','GM','WM','CSF','TIV','CSF_TIV','GM_TIV','WM_TIV'});
        vol_out = [vol_out; row]; %#ok<AGROW>
        summary.saved = summary.saved + 1;

        CVA_log_event('mri_csf_fex', 'subject_processed', struct( ...
            'subID',   subID, ...
            'tbv',     tbv, ...
            'gm',      gm,  'gm_tiv',  gm_tiv, ...
            'wm',      wm,  'wm_tiv',  wm_tiv, ...
            'csf',     csf, 'csf_tiv', csf_tiv, ...
            'tiv',     tiv));

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
        summary.failed = summary.failed + 1;
        CVA_log_event('mri_csf_fex', 'subject_failed', struct( ...
            'subID', subID, 'error', ME.message));
    end
end

%% Save
outFile = fullfile(paths.mri_fex, 'CVA_mri_volumes.mat');
save(outFile, 'vol_out');
fprintf('\nSaved MRI volumes for %d subjects to %s\n', height(vol_out), outFile);
summary.output_rows = height(vol_out);
CVA_log_event('mri_csf_fex', 'run_summary', summary);
