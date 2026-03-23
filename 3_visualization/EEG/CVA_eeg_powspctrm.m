%% CVA_eeg_powspctrm
%
% Visual summary of EEG spectral outcomes used in the project:
%   - IAF distribution
%   - Posterior alpha power distribution
%   - Alpha power by age group (if master matrix exists)

%% Setup
startup
[~, paths, ~, ~] = setup('CVA');

alphaFile = fullfile(paths.eeg_fex, 'CVA_alpha_power.mat');
if ~exist(alphaFile, 'file')
    warning('Missing file: %s. Run CVA_eeg_fex_alpha_gfp first.', alphaFile);
    return;
end
load(alphaFile, 'alpha_out');

if isempty(alpha_out) || height(alpha_out) == 0
    warning('alpha_out is empty. No EEG power spectrum summary plotted.');
    return;
end

fig = figure('Position', [0 0 1512 982], 'Name', 'CVA EEG Spectrum Summary');
tiledlayout(2,2);

nexttile;
histogram(alpha_out.IAF, 20, 'FaceColor', [0.12 0.47 0.71], 'EdgeColor', 'none');
xlabel('IAF (Hz)');
ylabel('Count');
title('IAF distribution');
grid on;

nexttile;
histogram(alpha_out.alpha_power, 20, 'FaceColor', [0.84 0.15 0.16], 'EdgeColor', 'none');
xlabel('Posterior alpha power (a.u.)');
ylabel('Count');
title('Posterior alpha power distribution');
grid on;

masterFile = fullfile(paths.master, 'CVA_master_matrix.mat');
if exist(masterFile, 'file')
    load(masterFile, 'master');
    if ~isempty(master) && all(ismember({'age_group','alpha_power'}, master.Properties.VariableNames))
        nexttile;
        boxchart(categorical(master.age_group), master.alpha_power);
        xlabel('Age group');
        ylabel('Posterior alpha power (a.u.)');
        title('Alpha power by age group');
        grid on;
    end
end

nexttile;
scatter(alpha_out.IAF, alpha_out.alpha_power, 30, 'filled');
xlabel('IAF (Hz)');
ylabel('Posterior alpha power (a.u.)');
title('IAF vs alpha power');
grid on;

exportgraphics(fig, fullfile(paths.figures, 'CVA_eeg_powspctrm.png'), 'Resolution', 300);
close(fig);
