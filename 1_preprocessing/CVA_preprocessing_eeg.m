%% CVA_preprocessing_eeg
%
% Loads preprocessed LEMON eyes-closed EEG (.set) per subject and performs
% any additional study-specific steps (epoch rejection, average reference).
% Saves cleaned data to derivatives/EEG/.
%
% Input:  dirs.eeg_raw  / sub-XXXXXX_EC.set
% Output: dirs.eeg_proc / sub-XXXXXX_EC_clean.mat

%% Setup
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
        cfg         = [];
        cfg.length  = 2;
        cfg.overlap = 0;
        data        = ft_redefinetrial(cfg, data);

        %% Reject noisy epochs (peak-to-peak > 90 µV)
        cfg                        = [];
        cfg.artfctdef.zvalue.channel   = 'all';
        cfg.artfctdef.reject           = 'complete';
        cfg.artfctdef.crittoilim       = data.time{1}([1 end]);
        % TODO: add ft_rejectartifact call

        %% Save
        outFile = fullfile(dirs.eeg_proc, [subID '_EC_clean.mat']);
        save(outFile, 'data', '-v7.3');

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
    end
end
