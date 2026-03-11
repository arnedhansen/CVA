%% CVA_mri_fex_csf
%
% Extracts tissue volumes from CAT12 segmentation output per subject:
%   - TBV     (total brain volume = GM + WM, in ml)
%   - GM      (gray matter volume, in ml)
%   - WM      (white matter volume, in ml)
%   - CSF     (cerebrospinal fluid volume, in ml) — raw, for reference only
%   - TIV     (total intracranial volume, in ml)
%   - CSF_TIV (CSF as percentage of TIV: CSF / TIV * 100)
%
% CSF_TIV is the variable that enters statistical models. Raw CSF volume
% correlates strongly with head size — larger heads contain more CSF purely
% for geometric reasons, independent of atrophy. Expressing CSF as a
% proportion of TIV removes this confound and makes the measure comparable
% across individuals (Buckner et al., 2004).
%
% TIV is read from S.subjectmeasures.vol_TIV in the CAT12 XML report.
% All volumes are from CAT12's AMAP segmentation in native space.
%
% Reads from CAT12 XML report files (cat_*.xml).
%
% Output: paths.mri_fex/CVA_mri_volumes.mat
%   vol_out: table with columns [subID, TBV, GM, WM, CSF, TIV, CSF_TIV]

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

vol_out = table();
summary = struct();
summary.total_subjects          = numel(subjects);
summary.missing_xml             = 0;
summary.missing_vol_abs_cgw     = 0;
summary.bad_vol_abs_cgw_format  = 0;
summary.missing_tiv             = 0;
summary.bad_tiv                 = 0;
summary.failed                  = 0;
summary.saved                   = 0;

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[MRI CSF FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    % CAT12 report XML — located in anat/report/ relative to paths.mri_proc
    xmlFile = fullfile(paths.mri_proc, subID, 'anat', 'report', ...
                       ['cat_' subID '_ses-01_acq-mp2rage_T1w.xml']);

    if ~exist(xmlFile, 'file')
        warning('CAT12 XML not found for %s', subID);
        summary.missing_xml = summary.missing_xml + 1;
        CVA_log_event('mri_csf_fex', 'subject_skip_missing_xml', struct( ...
            'subID', subID, 'expected_xml', xmlFile));
        continue;
    end

    try
        %% Parse CAT12 XML
        S = cat_io_xml(xmlFile);

        %% Extract tissue volumes (CSF, GM, WM)
        if ~isfield(S, 'subjectmeasures') || ~isfield(S.subjectmeasures, 'vol_abs_CGW')
            warning('Missing vol_abs_CGW in CAT12 XML for %s', subID);
            summary.missing_vol_abs_cgw = summary.missing_vol_abs_cgw + 1;
            continue;
        end

        cgw = S.subjectmeasures.vol_abs_CGW;
        if numel(cgw) < 3
            warning('Unexpected vol_abs_CGW format for %s (expected 3 values, got %d)', ...
                subID, numel(cgw));
            summary.bad_vol_abs_cgw_format = summary.bad_vol_abs_cgw_format + 1;
            continue;
        end

        % CAT12 order in vol_abs_CGW: [CSF, GM, WM]
        csf = cgw(1);
        gm  = cgw(2);
        wm  = cgw(3);
        tbv = gm + wm;

        %% Extract TIV
        if ~isfield(S.subjectmeasures, 'vol_TIV')
            warning('Missing vol_TIV in CAT12 XML for %s — cannot compute CSF/TIV', subID);
            summary.missing_tiv = summary.missing_tiv + 1;
            continue;
        end

        tiv = S.subjectmeasures.vol_TIV;

        if ~isscalar(tiv) || ~isfinite(tiv) || tiv <= 0
            warning('Invalid vol_TIV (%.4g) for %s — skipping', tiv, subID);
            summary.bad_tiv = summary.bad_tiv + 1;
            continue;
        end

        %% TIV-corrected CSF
        % Expressed as percentage of TIV so the coefficient in regression
        % models has an interpretable unit: 1 unit = 1 percentage point of
        % intracranial volume occupied by CSF.
        csf_tiv = (csf / tiv) * 100;

        fprintf('  CSF: %.1f ml | TIV: %.1f ml | CSF/TIV: %.2f%%\n', ...
            csf, tiv, csf_tiv);

        %% Append
        row     = table({subID}, tbv, gm, wm, csf, tiv, csf_tiv, ...
                        'VariableNames', {'subID','TBV','GM','WM','CSF','TIV','CSF_TIV'});
        vol_out = [vol_out; row]; %#ok<AGROW>
        summary.saved = summary.saved + 1;

        CVA_log_event('mri_csf_fex', 'subject_processed', struct( ...
            'subID',   subID, ...
            'tbv',     tbv, ...
            'gm',      gm, ...
            'wm',      wm, ...
            'csf',     csf, ...
            'tiv',     tiv, ...
            'csf_tiv', csf_tiv));

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
        summary.failed = summary.failed + 1;
        CVA_log_event('mri_csf_fex', 'subject_failed', struct( ...
            'subID', subID, ...
            'error', ME.message));
    end
end

%% Save
outFile = fullfile(paths.mri_fex, 'CVA_mri_volumes.mat');
save(outFile, 'vol_out');
fprintf('\nSaved MRI volumes for %d subjects to %s\n', height(vol_out), outFile);
summary.output_rows = height(vol_out);
CVA_log_event('mri_csf_fex', 'run_summary', summary);
