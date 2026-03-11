%% CVA_eeg_fex_gfp
%
% Extracts Global Field Power (GFP) per subject.
%
% GFP is defined as the standard deviation of the scalp potential across
% all electrodes at each time point (Lehmann & Skrandies, 1980). It is a
% reference-independent measure of total scalp field amplitude.
%
% Two GFP measures are computed:
%
%   gfp_mean  — broadband temporal GFP
%               std across channels at each sample, averaged over the
%               full resting-state recording (2-45 Hz bandpass already
%               applied during Automagic preprocessing).
%
%   gfp_alpha — alpha-band temporal GFP
%               The preprocessed data are bandpass-filtered into the
%               IAF-relative alpha band [IAF-4, IAF+2] Hz using a
%               zero-phase FIR filter, then GFP is computed identically
%               to gfp_mean. This is true GFP in the alpha band, not
%               spectral power averaged across channels.
%
% Requires CVA_alpha_power.mat to exist (for per-subject IAF values).
%
% Output: paths.eeg_fex/CVA_gfp.mat
%   gfp_out: table with columns [subID, gfp_mean, gfp_alpha]

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

if ~exist('ft_preproc_bandpassfilter', 'file')
    error(['FieldTrip function ft_preproc_bandpassfilter not found. ', ...
           'Add FieldTrip to path and rerun.']);
end

% Load IAF values — needed for IAF-relative alpha band definition
iafFile = fullfile(paths.eeg_fex, 'CVA_alpha_power.mat');
if ~exist(iafFile, 'file')
    error(['CVA_alpha_power.mat not found. ', ...
           'Run CVA_eeg_fex_alpha.m before this script.']);
end
load(iafFile, 'alpha_out');

% FIR filter order heuristic: 3 cycles of the low-frequency band edge.
% Ensures adequate frequency resolution without excessive ringing.
% E.g. IAF=10 Hz → band=[6,12] Hz → order = 3*(Fs/6) samples.
% Rounded to nearest even integer (required for zero-phase filtering).
FILTER_ORDER_CYCLES = 3;

gfp_out = table();
summary = struct();
summary.total_subjects = numel(subjects);
summary.missing_input  = 0;
summary.missing_iaf    = 0;
summary.failed         = 0;
summary.saved          = 0;

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[GFP FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    inFile = fullfile(paths.eeg_proc, [subID '_EC_clean.mat']);
    if ~exist(inFile, 'file')
        warning('Preprocessed file missing: %s', subID);
        summary.missing_input = summary.missing_input + 1;
        CVA_log_event('gfp_fex', 'subject_skip_missing_input', ...
            struct('subID', subID, 'input_file', inFile));
        continue;
    end

    % Retrieve this subject's IAF for alpha band definition
    iafRow = strcmp(alpha_out.subID, subID);
    if ~any(iafRow)
        warning('No IAF for %s — skipping GFP.', subID);
        summary.missing_iaf = summary.missing_iaf + 1;
        CVA_log_event('gfp_fex', 'subject_skip_missing_iaf', ...
            struct('subID', subID));
        continue;
    end
    iaf = alpha_out.IAF(iafRow);

    try
        load(inFile, 'data');

        % Concatenate all trials into [channels x samples]
        allData = cat(2, data.trial{:});
        fs      = data.fsample;

        %% Broadband temporal GFP
        % std across channels at each time point, then average over time.
        % This is the standard reference-independent GFP (Lehmann & Skrandies, 1980).
        gfpMean = mean(std(allData, 0, 1));

        %% Alpha-band temporal GFP
        % Step 1: bandpass filter into IAF-relative alpha band [IAF-4, IAF+2] Hz
        % Step 2: compute std across channels at each sample (= GFP)
        % Step 3: average over samples
        %
        % Using ft_preproc_bandpassfilter with a zero-phase (twopass) FIR
        % filter ensures no phase distortion, consistent with the broadband
        % preprocessing applied during Automagic.
        alphaLo     = iaf - 4;
        alphaHi     = iaf + 2;

        % Filter order: 3 cycles of lowest band edge, rounded to even integer
        filterOrder = 2 * round(FILTER_ORDER_CYCLES * fs / alphaLo / 2);

        dataAlpha = ft_preproc_bandpassfilter(allData, fs, ...
                        [alphaLo alphaHi], filterOrder, 'fir', 'twopass');

        gfpAlpha = mean(std(dataAlpha, 0, 1));

        fprintf('  GFP broadband: %.4g | GFP alpha [%.1f-%.1f Hz]: %.4g\n', ...
            gfpMean, alphaLo, alphaHi, gfpAlpha);

        %% Append
        row     = table({subID}, gfpMean, gfpAlpha, ...
                        'VariableNames', {'subID','gfp_mean','gfp_alpha'});
        gfp_out = [gfp_out; row]; %#ok<AGROW>
        summary.saved = summary.saved + 1;

        CVA_log_event('gfp_fex', 'subject_processed', struct( ...
            'subID',        subID, ...
            'gfp_mean',     gfpMean, ...
            'gfp_alpha',    gfpAlpha, ...
            'iaf_hz',       iaf, ...
            'alpha_band',   [alphaLo alphaHi], ...
            'filter_order', filterOrder));

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
        summary.failed = summary.failed + 1;
        CVA_log_event('gfp_fex', 'subject_failed', struct( ...
            'subID', subID, 'error', ME.message));
    end
end

%% Save
outFile = fullfile(paths.eeg_fex, 'CVA_gfp.mat');
save(outFile, 'gfp_out');
fprintf('\nSaved GFP for %d subjects to %s\n', height(gfp_out), outFile);
summary.output_rows = height(gfp_out);
CVA_log_event('gfp_fex', 'run_summary', summary);
