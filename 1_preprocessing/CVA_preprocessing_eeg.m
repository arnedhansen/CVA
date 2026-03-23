%% CVA_preprocessing_eeg
%
% Loads preprocessed LEMON eyes-closed EEG (.set) per subject and performs
% study-specific steps. Saves to data/EEG/EEG-preprocessed/.
%
% LEMON preprocessed data (Babayan et al. 2019) already includes:
%   - Downsampling 2500→250 Hz, bandpass 1–45 Hz
%   - Bad channel rejection, bad-interval removal (visual)
%   - PCA, ICA (Infomax), artifact component removal, back-projection
%   - Reference: FCz (no average re-reference applied)
%
% This script adds ONLY:
%   - Re-reference to average (LEMON left data FCz-referenced)
%   - Epoch segmentation (2 s, no overlap)
%   - Automated epoch rejection (peak-to-peak > 90 µV) — complementary to
%     LEMON's visual bad-interval removal; study-specific QC
%
% Input:  paths.eeg_raw  / sub-XXXXXX / sub-XXXXXX_EC.set
% Output: paths.eeg_proc / sub-XXXXXX_EC_clean.mat

%% Setup
startup
[subjects, paths, ~, ~] = setup('CVA');

if ~exist('ft_preprocessing', 'file')
    error(['FieldTrip function ft_preprocessing not found on path. ', ...
           'Add FieldTrip and rerun.']);
end

summary = struct();
summary.total_subjects = numel(subjects);
summary.missing_input = 0;
summary.failed = 0;
summary.excluded_no_epochs = 0;
summary.excluded_all_rejected = 0;
summary.excluded_too_few_epochs = 0;
summary.saved = 0;
summary.total_epochs_before = 0;
summary.total_epochs_after = 0;
summary.total_epochs_rejected = 0;

%% Run Preprocessing
for s = 1:numel(subjects)
    subID = subjects{s};
    clc
    fprintf('[EEG Preprocessing] %s (%d/%d)\n', subID, s, numel(subjects));

    inFile = fullfile(paths.eeg_raw, subID, [subID '_EC.set']);
    if ~exist(inFile, 'file')
        warning('File not found, skipping: %s', inFile);
        summary.missing_input = summary.missing_input + 1;
        CVA_log_event('eeg_preprocessing', 'subject_skip_missing_input', struct( ...
            'subID', subID, 'input_file', inFile));
        continue;
    end

    try
        %% Load
        cfg         = [];
        cfg.dataset = inFile;
        data        = ft_preprocessing(cfg);

        %% Re-reference to average (LEMON data is FCz-referenced; not done upstream)
        cfg            = [];
        cfg.reref      = 'yes';
        cfg.refchannel = 'all';
        data           = ft_preprocessing(cfg, data);

        %% Epoch into 2s segments
        cfg        = [];
        cfg.length = 2;
        cfg.overlap = 0;
        data       = ft_redefinetrial(cfg, data);

        if isempty(data.trial)
            warning('  No epochs available after segmentation for %s — excluding subject.', ...
                subID);
            summary.excluded_no_epochs = summary.excluded_no_epochs + 1;
            CVA_log_event('eeg_preprocessing', 'subject_excluded', struct( ...
                'subID', subID, ...
                'reason', 'no_epochs_after_segmentation'));
            continue;
        end

        %% Reject noisy epochs (peak-to-peak > 90 µV) — CVA-specific QC, not in LEMON
        nEpochsBefore = numel(data.trial);

        % Use threshold in the native data unit to avoid over-rejection.
        p2pThreshold = 90e-6; % default: 90 µV expressed in V
        if isfield(data, 'unit') && ischar(data.unit)
            switch lower(strtrim(data.unit))
                case {'uv', 'microvolt', 'microvolts'}
                    p2pThreshold = 90;
                case {'mv', 'millivolt', 'millivolts'}
                    p2pThreshold = 0.09;
                otherwise
                    p2pThreshold = 90e-6;
            end
        else
            % FieldTrip datasets often omit data.unit.
            % Infer a likely scale from robust amplitude statistics.
            probeN = min(5, nEpochsBefore);
            probeVals = [];
            for tProbe = 1:probeN
                xProbe = data.trial{tProbe};
                probeVals = [probeVals; xProbe(:)]; %#ok<AGROW>
            end
            probeVals = probeVals(isfinite(probeVals));
            if ~isempty(probeVals)
                a95 = prctile(abs(probeVals), 95);
                if a95 > 1
                    p2pThreshold = 90;    % likely µV
                elseif a95 > 1e-3
                    p2pThreshold = 0.09;  % likely mV
                else
                    p2pThreshold = 90e-6; % likely V
                end
            end
        end
        fprintf('  Peak-to-peak threshold used: %.6g (native unit)\n', p2pThreshold);

        % Epoch is rejected only if too many channels exceed threshold.
        maxBadChannelFrac = 0.15; % reject epoch if >10%% channels are bad

        % Determine clean epochs directly from peak-to-peak amplitude.
        % This avoids ft_rejectartifact edge-case crashes when all epochs are marked bad.
        keepMask = false(1, nEpochsBefore);
        for t = 1:nEpochsBefore
            x = data.trial{t};
            if isempty(x)
                keepMask(t) = false;
                continue;
            end
            p2p = max(x, [], 2) - min(x, [], 2);
            badFrac = mean(p2p > p2pThreshold);
            keepMask(t) = all(isfinite(p2p)) && (badFrac <= maxBadChannelFrac);
        end

        nEpochsAfter = sum(keepMask);
        if nEpochsAfter == 0
            warning('  All epochs rejected for %s — excluding subject.', subID);
            summary.excluded_all_rejected = summary.excluded_all_rejected + 1;
            summary.total_epochs_before = summary.total_epochs_before + nEpochsBefore;
            summary.total_epochs_rejected = summary.total_epochs_rejected + nEpochsBefore;
            CVA_log_event('eeg_preprocessing', 'subject_excluded', struct( ...
                'subID', subID, ...
                'reason', 'all_epochs_rejected', ...
                'epochs_before', nEpochsBefore, ...
                'epochs_after', nEpochsAfter, ...
                'epochs_rejected', nEpochsBefore, ...
                'p2p_threshold_native', p2pThreshold, ...
                'max_bad_channel_frac', maxBadChannelFrac));
            continue;
        end

        data.trial  = data.trial(keepMask);
        data.time   = data.time(keepMask);
        if isfield(data, 'sampleinfo') && ~isempty(data.sampleinfo)
            data.sampleinfo = data.sampleinfo(keepMask, :);
        end
        if isfield(data, 'trialinfo') && ~isempty(data.trialinfo)
            data.trialinfo = data.trialinfo(keepMask, :);
        end

        % Log how many epochs survived
        nRejected     = nEpochsBefore - nEpochsAfter;
        fprintf('  Epochs: %d retained, %d rejected (%.0f%%)\n', ...
            nEpochsAfter, nRejected, 100 * nRejected / nEpochsBefore);
        summary.total_epochs_before = summary.total_epochs_before + nEpochsBefore;
        summary.total_epochs_after = summary.total_epochs_after + nEpochsAfter;
        summary.total_epochs_rejected = summary.total_epochs_rejected + nRejected;

        % Exclude subject if fewer than 30 clean epochs remain
        if nEpochsAfter < 30
            warning('  Only %d epochs remain for %s — excluding subject.', ...
                nEpochsAfter, subID);
            summary.excluded_too_few_epochs = summary.excluded_too_few_epochs + 1;
            CVA_log_event('eeg_preprocessing', 'subject_excluded', struct( ...
                'subID', subID, ...
                'reason', 'fewer_than_30_epochs', ...
                'epochs_before', nEpochsBefore, ...
                'epochs_after', nEpochsAfter, ...
                'epochs_rejected', nRejected, ...
                'p2p_threshold_native', p2pThreshold, ...
                'max_bad_channel_frac', maxBadChannelFrac));
            continue;
        end

        %% Save
        outFile = fullfile(paths.eeg_proc, [subID '_EC_clean.mat']);
        save(outFile, 'data', '-v7.3');
        summary.saved = summary.saved + 1;
        CVA_log_event('eeg_preprocessing', 'subject_processed', struct( ...
            'subID', subID, ...
            'status', 'saved', ...
            'epochs_before', nEpochsBefore, ...
            'epochs_after', nEpochsAfter, ...
            'epochs_rejected', nRejected, ...
            'rejected_pct', 100 * nRejected / nEpochsBefore, ...
            'p2p_threshold_native', p2pThreshold, ...
            'max_bad_channel_frac', maxBadChannelFrac, ...
            'output_file', outFile));

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
        summary.failed = summary.failed + 1;
        CVA_log_event('eeg_preprocessing', 'subject_failed', struct( ...
            'subID', subID, ...
            'error', ME.message));
    end
end

CVA_log_event('eeg_preprocessing', 'run_summary', summary);