%% CVA_mri_fex_csf
%
% Extracts tissue volumes from CAT12 segmentation output per subject:
%   - TBV  (total brain volume = GM + WM)
%   - GM   (gray matter volume)
%   - WM   (white matter volume)
%   - CSF  (cerebrospinal fluid volume)
%
% Reads from CAT12 XML report files (cat_*.xml) or alternatively the
% catROI_*.mat files in the CAT12 derivatives folder.
%
% Output: dirs.fex/CVA_mri_volumes.mat
%   vol_out: table with columns [subID, TBV, GM, WM, CSF]

%% Setup
dirs     = CVA_paths();
subjects = CVA_get_subjects();

vol_out = table();
summary = struct();
summary.total_subjects = numel(subjects);
summary.missing_xml = 0;
summary.missing_vol_abs_cgw = 0;
summary.bad_vol_abs_cgw_format = 0;
summary.failed = 0;
summary.saved = 0;

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[MRI CSF FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    % CAT12 report XML location (adjust subfolder name if needed)
    xmlFile = fullfile(dirs.mri_proc, subID, 'report', ...
                       ['cat_' subID '_ses-01_acq-mp2rage_brain.xml']);

    if ~exist(xmlFile, 'file')
        warning('CAT12 XML not found for %s', subID);
        summary.missing_xml = summary.missing_xml + 1;
        continue;
    end

    try
        %% Parse CAT12 XML
        S = cat_io_xml(xmlFile);   % CAT12 helper function

        if ~isfield(S, 'subjectmeasures') || ~isfield(S.subjectmeasures, 'vol_abs_CGW')
            warning('Missing vol_abs_CGW in CAT12 XML for %s', subID);
            summary.missing_vol_abs_cgw = summary.missing_vol_abs_cgw + 1;
            continue;
        end

        cgw = S.subjectmeasures.vol_abs_CGW;
        if numel(cgw) < 3
            warning('Unexpected vol_abs_CGW format for %s', subID);
            summary.bad_vol_abs_cgw_format = summary.bad_vol_abs_cgw_format + 1;
            continue;
        end

        % CAT12 order in vol_abs_CGW is [CSF, GM, WM].
        csf = cgw(1);
        gm  = cgw(2);
        wm  = cgw(3);
        tbv = gm + wm;

        %% Append
        row     = table({subID}, tbv, gm, wm, csf, ...
                        'VariableNames', {'subID','TBV','GM','WM','CSF'});
        vol_out = [vol_out; row]; %#ok<AGROW>
        summary.saved = summary.saved + 1;
        CVA_log_event('mri_csf_fex', 'subject_processed', struct( ...
            'subID', subID, ...
            'tbv', tbv, ...
            'gm', gm, ...
            'wm', wm, ...
            'csf', csf));

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
        summary.failed = summary.failed + 1;
        CVA_log_event('mri_csf_fex', 'subject_failed', struct( ...
            'subID', subID, ...
            'error', ME.message));
    end
end

%% Save
outFile = fullfile(dirs.fex, 'CVA_mri_volumes.mat');
save(outFile, 'vol_out');
fprintf('Saved MRI volumes for %d subjects to %s\n', height(vol_out), outFile);
summary.output_rows = height(vol_out);
CVA_log_event('mri_csf_fex', 'run_summary', summary);
