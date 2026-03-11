%% CVA_missing_data
%
% Reports missing data across modalities per subject.
% Produces a summary table of available N per modality.

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

modalities = {'EEG','MRI_anat','MRI_CAT12'};
missing    = struct();

for s = 1:numel(subjects)
    subID = subjects{s};

    missing(s).subID    = subID;
    missing(s).EEG      = exist(fullfile(paths.eeg_raw, subID, [subID '_EC.set']), 'file') > 0;
    missing(s).MRI_anat = exist(fullfile(paths.mri_raw, subID, 'anat', ...
                                [subID '_ses-01_acq-mp2rage_brain.nii.gz']), 'file') > 0;
    missing(s).MRI_CAT12 = exist(fullfile(paths.mri_proc, subID), 'dir') > 0;
end

T = struct2table(missing);
fprintf('\n--- Data availability ---\n');
fprintf('EEG available:       %d / %d\n', sum(T.EEG),       numel(subjects));
fprintf('MRI (raw) available: %d / %d\n', sum(T.MRI_anat),  numel(subjects));
fprintf('MRI (CAT12) done:    %d / %d\n', sum(T.MRI_CAT12), numel(subjects));
CVA_log_event('missing_data', 'availability_summary', struct( ...
    'n_subjects', numel(subjects), ...
    'n_eeg_available', sum(T.EEG), ...
    'n_mri_raw_available', sum(T.MRI_anat), ...
    'n_mri_cat12_available', sum(T.MRI_CAT12)));

missing_all = T(~T.EEG | ~T.MRI_anat, :);
if ~isempty(missing_all)
    fprintf('\nSubjects missing at least one modality:\n');
    disp(missing_all.subID);
    CVA_log_event('missing_data', 'subjects_missing_modalities', struct( ...
        'n_subjects_missing_any', height(missing_all), ...
        'subjects', {missing_all.subID}));
end
