%% CVA_cat12_qc
%
% Reads CAT12 XML reports and flags subjects with poor segmentation quality.
%
% CAT12 assigns an Image Quality Rating (IQR) score per subject:
%   A (1-2)  = excellent
%   B (2-3)  = good
%   C (3-4)  = acceptable       ← recommended exclusion threshold: > 3.5
%   D (4-5)  = poor  → exclude
%   E (5-6)  = very poor → exclude
%
% Output: table printed to console + saved to dirs.fex/CVA_cat12_qc.mat

%% Setup
dirs     = CVA_paths();
subjects = CVA_get_subjects();

qc_out = table();

for s = 1:numel(subjects)
    subID   = subjects{s};
    xmlFile = fullfile(dirs.mri_proc, subID, 'report', ...
                       ['cat_' subID '_ses-01_acq-mp2rage_brain.xml']);

    if ~exist(xmlFile, 'file')
        warning('No CAT12 report for %s', subID);
        continue;
    end

    try
        S = cat_io_xml(xmlFile);

        iqr      = S.qualityratings.IQR;          % numeric score
        iqrGrade = S.qualityratings.IQRp100rms;   % letter grade string
        ncr      = S.qualityratings.NCR;          % noise-to-contrast ratio
        icv      = S.subjectmeasures.vol_TIV;     % total intracranial volume (ml)

        row    = table({subID}, iqr, {iqrGrade}, ncr, icv, ...
                       'VariableNames', {'subID','IQR','IQR_grade','NCR','TIV_ml'});
        qc_out = [qc_out; row]; %#ok<AGROW>

    catch ME
        warning('Failed to read QC for %s: %s', subID, ME.message);
    end
end

%% Flag poor quality
threshold        = 3.5;
qc_out.exclude   = qc_out.IQR > threshold;

%% Report
fprintf('\n===== CAT12 QC Summary =====\n');
fprintf('Total processed:  %d\n', height(qc_out));
fprintf('Flagged (IQR>%.1f): %d\n', threshold, sum(qc_out.exclude));
fprintf('\nFlagged subjects:\n');
disp(qc_out(qc_out.exclude, :));

%% Save
outFile = fullfile(dirs.fex, 'CVA_cat12_qc.mat');
save(outFile, 'qc_out');
writetable(qc_out, fullfile(dirs.fex, 'CVA_cat12_qc.csv'));
fprintf('QC table saved to %s\n', outFile);
