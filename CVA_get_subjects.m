function subjects = CVA_get_subjects()
% CVA_GET_SUBJECTS  Returns cell array of subject IDs available in EEG data dir.
%
%   subjects = CVA_get_subjects()

dirs    = CVA_paths();
listing = dir(fullfile(dirs.eeg_raw, 'sub-*'));
subjects = {listing([listing.isdir]).name};
fprintf('Found %d subjects.\n', numel(subjects));
