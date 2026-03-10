%% CVA_preprocessing_eeg
%
% Loads preprocessed LEMON eyes-closed EEG (.set) per subject and performs
% any additional study-specific steps (epoch rejection, average reference).
% Saves cleaned data to derivatives/EEG/.
%
% Input:  dirs.eeg_raw  / sub-XXXXXX_EC.set
% Output: dirs.eeg_proc / sub-XXXXXX_EC_clean.mat

%% Setup
startup;
setup;
dirs = CVA_paths();
subjects = CVA_get_subjects();

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

        %% Reject noisy epochs (peak-to-peak > 90 µV)
        % Step 1: detect artefact windows using ft_artifact_threshold
        cfg                                = [];
        cfg.continuous                     = 'no';       % data already epoched
        cfg.artfctdef.threshold.channel    = 'all';
        cfg.artfctdef.threshold.bpfilter   = 'no';       % no filter — raw amplitude
        cfg.artfctdef.threshold.range      = 90e-6;      % peak-to-peak threshold (V)
        [cfg, ~]                           = ft_artifact_threshold(cfg, data);

        % Step 2: reject epochs containing artefact windows
        cfg.artfctdef.reject               = 'complete'; % discard entire epoch
        cfg.artfctdef.crittoilim           = data.time{1}([1 end]);
        data                               = ft_rejectartifact(cfg, data);

        % Log how many epochs survived
        nEpochsBefore = numel(data.trial) + size(cfg.artfctdef.threshold.artifact, 1);
        nEpochsAfter  = numel(data.trial);
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
