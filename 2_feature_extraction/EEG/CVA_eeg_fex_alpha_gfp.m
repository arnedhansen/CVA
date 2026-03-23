%% CVA_eeg_fex_alpha_gfp
%
% Extracts posterior alpha power and GFP per subject in a single pass.
%
% Alpha:
%   PSD via Welch's method (mtmconvol, 2s window, 50% overlap).
%   IAF = local peak in 8-14 Hz over posterior cluster (O1,O2,Oz,PO3-8).
%   Alpha power = mean power in [IAF-4, IAF+2] Hz.
%
% GFP (Lehmann & Skrandies, 1980):
%   gfp_mean  — broadband temporal GFP (std across channels, averaged over time).
%   gfp_alpha — alpha-band temporal GFP (bandpass [IAF-4, IAF+2] Hz, then same).
%
% Outputs:
%   paths.eeg_fex/CVA_alpha_power.mat  — alpha_out: [subID, IAF, alpha_power]
%   paths.eeg_fex/CVA_gfp.mat          — gfp_out:   [subID, gfp_mean, gfp_alpha]

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

if ~exist('ft_freqanalysis', 'file')
    error(['FieldTrip function ft_freqanalysis not found on path. ', ...
           'Add FieldTrip and rerun.']);
end
if ~exist('ft_preproc_bandpassfilter', 'file')
    error(['FieldTrip function ft_preproc_bandpassfilter not found. ', ...
           'Add FieldTrip to path and rerun.']);
end

% Posterior electrode cluster (consistent with Klimesch 1999)
posteriorChans = {'O1','O2','Oz','PO3','PO4','PO7','PO8'};

% Welch parameters
WINDOW_SEC  = 2;
OVERLAP_PCT = 0.50;
FOI         = 2:0.5:30;

% IAF search band
IAF_LO = 8;
IAF_HI = 14;

% FIR filter for alpha-band GFP
FILTER_ORDER_CYCLES = 3;

alpha_out = table();
gfp_out   = table();
summary   = struct();
summary.total_subjects        = numel(subjects);
summary.missing_input         = 0;
summary.excluded_no_peak      = 0;
summary.excluded_iaf_boundary = 0;
summary.failed                = 0;
summary.alpha_saved           = 0;
summary.gfp_saved             = 0;

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[Alpha+GFP FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    inFile = fullfile(paths.eeg_proc, [subID '_EC_clean.mat']);
    if ~exist(inFile, 'file')
        warning('Preprocessed file missing: %s', subID);
        summary.missing_input = summary.missing_input + 1;
        CVA_log_event('alpha_gfp_fex', 'subject_skip_missing_input', struct( ...
            'subID', subID, 'input_file', inFile));
        continue;
    end

    try
        load(inFile, 'data');
        fs = data.fsample;

        %% --- Alpha: PSD, IAF, alpha power ---
        tStart = data.time{1}(1)   + WINDOW_SEC / 2;
        tEnd   = data.time{end}(end) - WINDOW_SEC / 2;
        tStep  = WINDOW_SEC * (1 - OVERLAP_PCT);
        toi    = tStart : tStep : tEnd;

        cfg               = [];
        cfg.method        = 'mtmconvol';
        cfg.taper         = 'hanning';
        cfg.foi           = FOI;
        cfg.t_ftimwin     = repmat(WINDOW_SEC, size(FOI));
        cfg.toi           = toi;
        cfg.keeptrials    = 'no';
        cfg.channel       = posteriorChans;
        cfg.pad           = 'nextpow2';
        freq              = ft_freqanalysis(cfg, data);

        psdChan = mean(freq.powspctrm, 3);
        psdPost = mean(psdChan, 1);

        iafMask  = freq.freq >= IAF_LO & freq.freq <= IAF_HI;
        iafFreqs = freq.freq(iafMask);
        iafPSD   = psdPost(iafMask);

        [peakPow, peakLoc] = findpeaks(iafPSD);

        if isempty(peakPow)
            warning('No local IAF peak found for %s — excluding.', subID);
            summary.excluded_no_peak = summary.excluded_no_peak + 1;
            CVA_log_event('alpha_gfp_fex', 'subject_excluded', struct( ...
                'subID', subID, 'reason', 'no_local_peak_in_iaf_band'));
            continue;
        end

        [~, maxIdx]  = max(peakPow);
        peakBinIdx   = peakLoc(maxIdx);

        if peakBinIdx == 1 || peakBinIdx == numel(iafFreqs)
            warning('IAF peak at search window boundary for %s — excluding.', subID);
            summary.excluded_iaf_boundary = summary.excluded_iaf_boundary + 1;
            CVA_log_event('alpha_gfp_fex', 'subject_excluded', struct( ...
                'subID', subID, 'reason', 'iaf_at_band_boundary'));
            continue;
        end

        iaf = iafFreqs(peakBinIdx);
        alphaBand  = freq.freq >= (iaf - 4) & freq.freq <= (iaf + 2);
        alphaPower = mean(mean(psdChan(:, alphaBand), 2));

        rowAlpha = table({subID}, iaf, alphaPower, ...
                        'VariableNames', {'subID','IAF','alpha_power'});
        alpha_out = [alpha_out; rowAlpha]; %#ok<AGROW>
        summary.alpha_saved = summary.alpha_saved + 1;

        %% --- GFP: broadband and alpha-band ---
        allData = cat(2, data.trial{:});
        gfpMean = mean(std(allData, 0, 1));

        alphaLo     = iaf - 4;
        alphaHi     = iaf + 2;
        filterOrder = 2 * round(FILTER_ORDER_CYCLES * fs / alphaLo / 2);
        dataAlpha   = ft_preproc_bandpassfilter(allData, fs, ...
                        [alphaLo alphaHi], filterOrder, 'fir', 'twopass');
        gfpAlpha    = mean(std(dataAlpha, 0, 1));

        rowGfp = table({subID}, gfpMean, gfpAlpha, ...
                      'VariableNames', {'subID','gfp_mean','gfp_alpha'});
        gfp_out = [gfp_out; rowGfp]; %#ok<AGROW>
        summary.gfp_saved = summary.gfp_saved + 1;

        fprintf('  IAF: %.1f Hz | Alpha: %.4g | GFP: %.4g / %.4g\n', ...
            iaf, alphaPower, gfpMean, gfpAlpha);
        CVA_log_event('alpha_gfp_fex', 'subject_processed', struct( ...
            'subID',       subID, ...
            'iaf_hz',      iaf, ...
            'alpha_power', alphaPower, ...
            'gfp_mean',    gfpMean, ...
            'gfp_alpha',   gfpAlpha));

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
        summary.failed = summary.failed + 1;
        CVA_log_event('alpha_gfp_fex', 'subject_failed', struct( ...
            'subID', subID, 'error', ME.message));
    end
end

%% Save
outAlpha = fullfile(paths.eeg_fex, 'CVA_alpha_power.mat');
outGfp   = fullfile(paths.eeg_fex, 'CVA_gfp.mat');
save(outAlpha, 'alpha_out');
save(outGfp,   'gfp_out');
fprintf('\nSaved alpha power: %d subjects → %s\n', height(alpha_out), outAlpha);
fprintf('Saved GFP:         %d subjects → %s\n', height(gfp_out), outGfp);
CVA_log_event('alpha_gfp_fex', 'run_summary', summary);
