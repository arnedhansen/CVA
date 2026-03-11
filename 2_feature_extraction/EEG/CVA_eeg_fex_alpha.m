%% CVA_eeg_fex_alpha
%
% Extracts posterior alpha power per subject using an IAF-relative band.
%
% PSD estimation uses Welch's method, implemented in FieldTrip via
% cfg.method = 'mtmconvol' with a 2-second Hanning-tapered sliding window
% and 50% overlap (1-second step). This is mathematically equivalent to
% Welch's method and matches the procedure described in the paper.
%
% Steps:
%   1. Compute PSD via Welch's method (mtmconvol, 2s window, 50% overlap)
%   2. Identify IAF as a true local spectral peak in 8-14 Hz over the
%      posterior electrode cluster using findpeaks (not just a max)
%   3. Extract mean alpha power in [IAF-4, IAF+2] Hz
%
% Output: paths.eeg_fex/CVA_alpha_power.mat
%   alpha_out: table with columns [subID, IAF, alpha_power]

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

if ~exist('ft_freqanalysis', 'file')
    error(['FieldTrip function ft_freqanalysis not found on path. ', ...
           'Add FieldTrip and rerun.']);
end

% Posterior electrode cluster (consistent with Klimesch 1999)
posteriorChans = {'O1','O2','Oz','PO3','PO4','PO7','PO8'};

% Welch parameters — keep consistent with paper and CVA_eeg_fex_gfp
WINDOW_SEC  = 2;     % Hanning window length in seconds
OVERLAP_PCT = 0.50;  % 50% overlap between windows
FOI         = 2:0.5:30;  % frequencies of interest (Hz), 0.5 Hz resolution

% IAF search band
IAF_LO = 8;
IAF_HI = 14;

alpha_out = table();
summary = struct();
summary.total_subjects        = numel(subjects);
summary.missing_input         = 0;
summary.excluded_no_peak      = 0;   % no local peak found in 8-14 Hz
summary.excluded_iaf_boundary = 0;   % peak at edge of search window
summary.failed                = 0;
summary.saved                 = 0;

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[Alpha FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    inFile = fullfile(paths.eeg_proc, [subID '_EC_clean.mat']);
    if ~exist(inFile, 'file')
        warning('Preprocessed file missing: %s', subID);
        summary.missing_input = summary.missing_input + 1;
        CVA_log_event('alpha_fex', 'subject_skip_missing_input', struct( ...
            'subID', subID, 'input_file', inFile));
        continue;
    end

    try
        load(inFile, 'data');

        % Infer sampling rate from data
        fs = data.fsample;

        %% Compute PSD via Welch's method (mtmconvol with sliding window)
        %
        % cfg.t_ftimwin: length of each sliding window in seconds (per freq).
        %   Set to WINDOW_SEC for all frequencies → 2 s Hanning window.
        % cfg.toi: window centres. Step = WINDOW_SEC * (1 - OVERLAP_PCT) = 1 s.
        %   Start at WINDOW_SEC/2 (so first window is fully within the data)
        %   and end at data end minus WINDOW_SEC/2.
        %
        % FieldTrip concatenates trials internally before sliding — use
        % cfg.keeptrials = 'no' to average directly to a single PSD per subject.

        % Determine data time extent (use first trial start/end as reference)
        tStart = data.time{1}(1)   + WINDOW_SEC / 2;
        tEnd   = data.time{end}(end) - WINDOW_SEC / 2;
        tStep  = WINDOW_SEC * (1 - OVERLAP_PCT);
        toi    = tStart : tStep : tEnd;

        cfg               = [];
        cfg.method        = 'mtmconvol';
        cfg.taper         = 'hanning';
        cfg.foi           = FOI;
        cfg.t_ftimwin     = repmat(WINDOW_SEC, size(FOI));  % 2 s window at all freqs
        cfg.toi           = toi;
        cfg.keeptrials    = 'no';    % average over windows → single PSD per subject
        cfg.channel       = posteriorChans;
        cfg.pad           = 'nextpow2';
        freq              = ft_freqanalysis(cfg, data);

        % Average power over time (Welch estimate: mean of windowed periodograms)
        % freq.powspctrm is [channels x frequencies x time] when keeptrials='no'
        psdChan = mean(freq.powspctrm, 3);   % [channels x frequencies]
        psdPost = mean(psdChan, 1);           % [1 x frequencies], avg over channels

        %% Find IAF as a true local peak in 8-14 Hz (not just a global max)
        %
        % findpeaks requires a local maximum with neighbours on both sides.
        % This correctly excludes monotone edges and flat plateaus.
        iafMask  = freq.freq >= IAF_LO & freq.freq <= IAF_HI;
        iafFreqs = freq.freq(iafMask);
        iafPSD   = psdPost(iafMask);

        [peakPow, peakLoc] = findpeaks(iafPSD);

        if isempty(peakPow)
            % No local peak in 8-14 Hz — not a well-defined alpha peak
            warning('No local IAF peak found for %s — excluding.', subID);
            summary.excluded_no_peak = summary.excluded_no_peak + 1;
            CVA_log_event('alpha_fex', 'subject_excluded', struct( ...
                'subID', subID, ...
                'reason', 'no_local_peak_in_iaf_band'));
            continue;
        end

        % Select the highest peak if multiple local maxima exist in band
        [~, maxIdx]  = max(peakPow);
        peakBinIdx   = peakLoc(maxIdx);

        % Exclude if the winning peak is at the boundary of the search window
        % (a boundary peak is not a confirmed local maximum relative to outside)
        if peakBinIdx == 1 || peakBinIdx == numel(iafFreqs)
            warning('IAF peak at search window boundary for %s — excluding.', subID);
            summary.excluded_iaf_boundary = summary.excluded_iaf_boundary + 1;
            CVA_log_event('alpha_fex', 'subject_excluded', struct( ...
                'subID', subID, ...
                'reason', 'iaf_at_band_boundary'));
            continue;
        end

        iaf = iafFreqs(peakBinIdx);

        %% Extract mean alpha power in IAF-relative band [IAF-4, IAF+2] Hz
        alphaBand  = freq.freq >= (iaf - 4) & freq.freq <= (iaf + 2);
        % Average over channels then over frequencies
        alphaPower = mean(mean(psdChan(:, alphaBand), 2));

        %% Append to output table
        row       = table({subID}, iaf, alphaPower, ...
                          'VariableNames', {'subID','IAF','alpha_power'});
        alpha_out = [alpha_out; row]; %#ok<AGROW>
        summary.saved = summary.saved + 1;

        fprintf('  IAF: %.1f Hz | Alpha power: %.4g\n', iaf, alphaPower);
        CVA_log_event('alpha_fex', 'subject_processed', struct( ...
            'subID',       subID, ...
            'iaf_hz',      iaf, ...
            'alpha_power', alphaPower, ...
            'n_iaf_peaks', numel(peakPow)));

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
        summary.failed = summary.failed + 1;
        CVA_log_event('alpha_fex', 'subject_failed', struct( ...
            'subID', subID, ...
            'error', ME.message));
    end
end

%% Save
outFile = fullfile(paths.eeg_fex, 'CVA_alpha_power.mat');
save(outFile, 'alpha_out');
fprintf('\nSaved alpha power for %d subjects to %s\n', height(alpha_out), outFile);
summary.output_rows = height(alpha_out);
CVA_log_event('alpha_fex', 'run_summary', summary);
