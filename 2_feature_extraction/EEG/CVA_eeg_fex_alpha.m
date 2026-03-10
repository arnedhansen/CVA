%% CVA_eeg_fex_alpha
%
% Extracts posterior alpha power per subject using IAF-relative band.
%
% Steps:
%   1. Compute PSD via ft_freqanalysis (Welch / mtmfft)
%   2. Identify IAF as spectral peak in 8-14 Hz over posterior cluster
%   3. Extract mean alpha power in [IAF-4, IAF+2] Hz
%
% Output: dirs.fex/CVA_alpha_power.mat
%   alpha_out: table with columns [subID, IAF, alpha_power]

%% Setup
CVA_init_toolboxes();
dirs     = CVA_paths();
subjects = CVA_get_subjects();

if ~exist('ft_freqanalysis', 'file')
    error(['FieldTrip function ft_freqanalysis not found on path. ', ...
           'Add FieldTrip and rerun.']);
end

% Posterior electrode cluster (consistent with Klimesch 1999)
posteriorChans = {'O1','O2','Oz','PO3','PO4','PO7','PO8'};

alpha_out = table();
summary = struct();
summary.total_subjects = numel(subjects);
summary.missing_input = 0;
summary.excluded_iaf_boundary = 0;
summary.failed = 0;
summary.saved = 0;

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[Alpha FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    inFile = fullfile(dirs.eeg_proc, [subID '_EC_clean.mat']);
    if ~exist(inFile, 'file')
        warning('Preprocessed file missing: %s', subID);
        summary.missing_input = summary.missing_input + 1;
        continue;
    end

    try
        load(inFile, 'data');

        %% Compute PSD
        cfg            = [];
        cfg.method     = 'mtmfft';
        cfg.taper      = 'hanning';
        cfg.foi        = 2:0.5:30;
        cfg.keeptrials = 'no';
        cfg.channel    = posteriorChans;
        freq           = ft_freqanalysis(cfg, data);

        %% Find IAF (peak in 8-14 Hz)
        iafBand  = freq.freq >= 8 & freq.freq <= 14;
        psdPost  = mean(freq.powspctrm, 1);  % avg across posterior channels
        [~, idx] = max(psdPost(iafBand));
        iafFreqs = freq.freq(iafBand);

        % Exclude if peak at boundary
        if idx == 1 || idx == sum(iafBand)
            warning('IAF at boundary for %s — excluding.', subID);
            summary.excluded_iaf_boundary = summary.excluded_iaf_boundary + 1;
            CVA_log_event('alpha_fex', 'subject_excluded', struct( ...
                'subID', subID, ...
                'reason', 'iaf_at_band_boundary'));
            continue;
        end

        iaf = iafFreqs(idx);

        %% Extract alpha power in [IAF-4, IAF+2]
        alphaBand   = freq.freq >= (iaf - 4) & freq.freq <= (iaf + 2);
        alphaPower  = mean(mean(freq.powspctrm(:, alphaBand), 2));

        %% Append
        row        = table({subID}, iaf, alphaPower, ...
                           'VariableNames', {'subID','IAF','alpha_power'});
        alpha_out  = [alpha_out; row]; %#ok<AGROW>
        summary.saved = summary.saved + 1;
        CVA_log_event('alpha_fex', 'subject_processed', struct( ...
            'subID', subID, ...
            'iaf_hz', iaf, ...
            'alpha_power', alphaPower));

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
        summary.failed = summary.failed + 1;
        CVA_log_event('alpha_fex', 'subject_failed', struct( ...
            'subID', subID, ...
            'error', ME.message));
    end
end

%% Save
outFile = fullfile(dirs.fex, 'CVA_alpha_power.mat');
save(outFile, 'alpha_out');
fprintf('Saved alpha power for %d subjects to %s\n', height(alpha_out), outFile);
summary.output_rows = height(alpha_out);
CVA_log_event('alpha_fex', 'run_summary', summary);
