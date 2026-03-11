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
% Output: table printed to console + saved to paths.mri_fex/CVA_cat12_qc.mat

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

qc_out = table();
qc_out = table('Size', [0 5], ...
               'VariableTypes', {'string','double','string','double','double'}, ...
               'VariableNames', {'subID','IQR','IQR_grade','NCR','TIV_ml'});
missingXmlCount = 0;

for s = 1:numel(subjects)
    subID   = subjects{s};
    xmlFile = fullfile(paths.mri_proc, subID, 'anat', 'report', ...
                       ['cat_' subID '_ses-01_acq-mp2rage_T1w.xml']);

    if ~exist(xmlFile, 'file')
        missingXmlCount = missingXmlCount + 1;
        continue;
    end

    try
        S = cat_io_xml(xmlFile);

        if ~isfield(S, 'qualityratings')
            warning('No qualityratings field in CAT12 XML for %s', subID);
            continue;
        end
        if ~isfield(S, 'subjectmeasures')
            warning('No subjectmeasures field in CAT12 XML for %s', subID);
            continue;
        end

        iqr = get_numeric_field(S.qualityratings, {'IQR','iqr'});
        if isfield(S.qualityratings, 'IQRp100rms')
            iqrGrade = S.qualityratings.IQRp100rms;
        else
            iqrGrade = 'NA';
        end
        ncr = get_numeric_field(S.qualityratings, {'NCR','ncr'});
        icv = get_numeric_field(S.subjectmeasures, {'vol_TIV','tiv','TIV'});

        row    = table(string(subID), iqr, string(iqrGrade), ncr, icv, ...
                       'VariableNames', {'subID','IQR','IQR_grade','NCR','TIV_ml'});
        qc_out = [qc_out; row]; %#ok<AGROW>

    catch ME
        warning('Failed to read QC for %s: %s', subID, ME.message);
    end
end

if missingXmlCount > 0
    warning('No CAT12 reports found for %d/%d subjects.', missingXmlCount, numel(subjects));
end
CVA_log_event('cat12_qc', 'xml_presence_summary', struct( ...
    'n_subjects', numel(subjects), ...
    'n_xml_missing', missingXmlCount, ...
    'n_xml_found', height(qc_out)));

%% Flag poor quality
threshold        = 3.5;
qc_out.exclude   = qc_out.IQR > threshold;

%% Report
fprintf('\n===== CAT12 QC Summary =====\n');
fprintf('Total processed:  %d\n', height(qc_out));
fprintf('Flagged (IQR>%.1f): %d\n', threshold, sum(qc_out.exclude));
fprintf('\nFlagged subjects:\n');
disp(qc_out(qc_out.exclude, :));
CVA_log_event('cat12_qc', 'qc_summary', struct( ...
    'n_processed', height(qc_out), ...
    'iqr_threshold', threshold, ...
    'n_flagged', sum(qc_out.exclude)));

%% Save
outFile = fullfile(paths.mri_fex, 'CVA_cat12_qc.mat');
save(outFile, 'qc_out');
writetable(qc_out, fullfile(paths.mri_fex, 'CVA_cat12_qc.csv'));
fprintf('QC table saved to %s\n', outFile);

function val = get_numeric_field(S, names)
val = NaN;
for k = 1:numel(names)
    fn = names{k};
    if isfield(S, fn)
        raw = S.(fn);
        if isnumeric(raw)
            val = raw;
        else
            val = str2double(string(raw));
        end
        return;
    end
end
end
