%% CVA_eeg_fex_gfp
%
% Extracts Global Field Power (GFP) per subject.
%
% GFP = std across all electrodes at each time point, averaged over recording.
% Spectral GFP uses the same IAF-relative alpha band as CVA_eeg_fex_alpha.
%
% Output: dirs.fex/CVA_gfp.mat
%   gfp_out: table with columns [subID, gfp_mean, gfp_alpha]

%% Setup
dirs     = CVA_paths();
subjects = CVA_get_subjects();

% Load IAF values from alpha extraction
load(fullfile(dirs.fex, 'CVA_alpha_power.mat'), 'alpha_out');

gfp_out = table();

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[GFP FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    inFile = fullfile(dirs.eeg_proc, [subID '_EC_clean.mat']);
    if ~exist(inFile, 'file')
        warning('Preprocessed file missing: %s', subID);
        continue;
    end

    % Check IAF exists for this subject
    iafRow = strcmp(alpha_out.subID, subID);
    if ~any(iafRow)
        warning('No IAF for %s — skipping GFP.', subID);
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

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
    end
end

%% Save
outFile = fullfile(dirs.fex, 'CVA_gfp.mat');
save(outFile, 'gfp_out');
fprintf('Saved GFP for %d subjects to %s\n', height(gfp_out), outFile);
