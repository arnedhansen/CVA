%% CVA_eeg_fex_gfp
%
% Extracts Global Field Power (GFP) per subject.
%
% GFP = std across all electrodes at each time point, averaged over recording.
% Spectral GFP uses the same IAF-relative alpha band as CVA_eeg_fex_alpha.
%
% Output: paths.eeg_fex/CVA_gfp.mat
%   gfp_out: table with columns [subID, gfp_mean, gfp_alpha]

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

if ~exist('ft_freqanalysis', 'file')
    error(['FieldTrip function ft_freqanalysis not found on path. ', ...
           'Add FieldTrip and rerun.']);
end

% Load IAF values from alpha extraction
load(fullfile(paths.eeg_fex, 'CVA_alpha_power.mat'), 'alpha_out');

gfp_out = table();
summary = struct();
summary.total_subjects = numel(subjects);
summary.missing_input = 0;
summary.missing_iaf = 0;
summary.failed = 0;
summary.saved = 0;

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[GFP FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    inFile = fullfile(paths.eeg_proc, [subID '_EC_clean.mat']);
    if ~exist(inFile, 'file')
        warning('Preprocessed file missing: %s', subID);
        summary.missing_input = summary.missing_input + 1;
        continue;
    end

    % Check IAF exists for this subject
    iafRow = strcmp(alpha_out.subID, subID);
    if ~any(iafRow)
        warning('No IAF for %s — skipping GFP.', subID);
        summary.missing_iaf = summary.missing_iaf + 1;
        continue;
    end
    iaf = alpha_out.IAF(iafRow);

    try
        load(inFile, 'data');

        %% Temporal GFP: std across channels at each sample, then mean
        allData  = cat(2, data.trial{:});   % channels x samples
        gfpMean  = mean(std(allData, 0, 1));

        %% Spectral GFP: PSD across all channels, IAF-relative alpha band
        cfg            = [];
        cfg.method     = 'mtmfft';
        cfg.taper      = 'hanning';
        cfg.foi        = 2:0.5:30;
        cfg.keeptrials = 'no';
        cfg.channel    = 'all';
        freq           = ft_freqanalysis(cfg, data);

        alphaBand = freq.freq >= (iaf - 4) & freq.freq <= (iaf + 2);
        gfpAlpha  = mean(mean(freq.powspctrm(:, alphaBand), 2));

        %% Append
        row     = table({subID}, gfpMean, gfpAlpha, ...
                        'VariableNames', {'subID','gfp_mean','gfp_alpha'});
        gfp_out = [gfp_out; row]; %#ok<AGROW>
        summary.saved = summary.saved + 1;
        CVA_log_event('gfp_fex', 'subject_processed', struct( ...
            'subID', subID, ...
            'gfp_mean', gfpMean, ...
            'gfp_alpha', gfpAlpha));

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
        summary.failed = summary.failed + 1;
        CVA_log_event('gfp_fex', 'subject_failed', struct( ...
            'subID', subID, ...
            'error', ME.message));
    end
end

%% Save
outFile = fullfile(paths.eeg_fex, 'CVA_gfp.mat');
save(outFile, 'gfp_out');
fprintf('Saved GFP for %d subjects to %s\n', height(gfp_out), outFile);
summary.output_rows = height(gfp_out);
CVA_log_event('gfp_fex', 'run_summary', summary);
