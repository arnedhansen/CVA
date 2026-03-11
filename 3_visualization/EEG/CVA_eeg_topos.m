%% CVA_eeg_topos
%
% Computes and plots a group-level posterior alpha topography.
% Alpha band is defined per subject as [IAF-4, IAF+2], then averaged.

%% Setup
startup
[~, paths, ~, ~] = setup('CVA');

if ~exist('ft_topoplotER', 'file') || ~exist('ft_freqanalysis', 'file')
    error(['FieldTrip plotting/spectral functions not found on path. ', ...
           'Add FieldTrip and rerun.']);
end

alphaFile = fullfile(paths.eeg_fex, 'CVA_alpha_power.mat');
if ~exist(alphaFile, 'file')
    warning('Missing file: %s. Run CVA_eeg_fex_alpha first.', alphaFile);
    return;
end
load(alphaFile, 'alpha_out');

if isempty(alpha_out) || height(alpha_out) == 0
    warning('alpha_out is empty. No topography plotted.');
    return;
end

topoBySubj = {};
labelRef = {};

for s = 1:height(alpha_out)
    subID = alpha_out.subID{s};
    inFile = fullfile(paths.eeg_proc, [subID '_EC_clean.mat']);
    if ~exist(inFile, 'file')
        continue;
    end

    load(inFile, 'data');
    cfg = [];
    cfg.method = 'mtmfft';
    cfg.taper = 'hanning';
    cfg.foi = 2:0.5:30;
    cfg.keeptrials = 'no';
    cfg.channel = 'all';
    freq = ft_freqanalysis(cfg, data);

    iaf = alpha_out.IAF(s);
    alphaBand = freq.freq >= (iaf - 4) & freq.freq <= (iaf + 2);
    topoBySubj{end+1,1} = mean(freq.powspctrm(:, alphaBand), 2); %#ok<AGROW>
    labelRef = freq.label;
end

if isempty(topoBySubj)
    warning('No valid subject spectra available for topography plot.');
    return;
end

groupTopo = mean(cell2mat(topoBySubj'), 2);

tmp = [];
tmp.label = labelRef;
tmp.avg = groupTopo;
tmp.time = 0;
tmp.dimord = 'chan_time';

cfg = [];
cfg.layout = 'easycapM11.lay';
cfg.comment = 'no';
cfg.marker = 'on';

fig = figure('Position', [0 0 1512 982], 'Name', 'CVA Alpha Topography');
ft_topoplotER(cfg, tmp);
title('Group alpha topography (IAF-relative band)');
colorbar;

exportgraphics(fig, fullfile(paths.figures, 'CVA_eeg_topos.png'), 'Resolution', 300);
close(fig);
