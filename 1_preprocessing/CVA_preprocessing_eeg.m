%% CVA_preprocessing_eeg
%
% Loads preprocessed LEMON eyes-closed EEG (.set) per subject and performs
% any additional study-specific steps (epoch rejection, average reference).
% Saves cleaned data to derivatives/EEG/.
%
% Input:  dirs.eeg_raw  / sub-XXXXXX_EC.set
% Output: dirs.eeg_proc / sub-XXXXXX_EC_clean.mat

%% Setup
CVA_init_toolboxes();
dirs = CVA_paths();
subjects = CVA_get_subjects();

if ~exist('ft_preprocessing', 'file')
    error(['FieldTrip function ft_preprocessing not found on path. ', ...
           'Add FieldTrip and rerun.']);
end

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[EEG Preprocessing] %s (%d/%d)\n', subID, s, numel(subjects));

    inFile = fullfile(dirs.eeg_raw, subID, [subID '_EC.set']);
    if ~exist(inFile, 'file')
        warning('File not found, skipping: %s', inFile);
        continue;
    end

    try
        %% Load
        cfg         = [];
        cfg.dataset = inFile;
        data        = ft_preprocessing(cfg);

        %% Re-reference to average
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
            continue;
        end

        %% Reject noisy epochs (peak-to-peak > 90 uV)
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
        end

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
            keepMask(t) = all(isfinite(p2p)) && ~any(p2p > p2pThreshold);
        end

        nEpochsAfter = sum(keepMask);
        if nEpochsAfter == 0
            warning('  All epochs rejected for %s — excluding subject.', subID);
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

        % Exclude subject if fewer than 30 clean epochs remain
        if nEpochsAfter < 30
            warning('  Only %d epochs remain for %s — excluding subject.', ...
                nEpochsAfter, subID);
            continue;
        end

        %% Save
        outFile = fullfile(dirs.eeg_proc, [subID '_EC_clean.mat']);
        save(outFile, 'data', '-v7.3');

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
    end
end
