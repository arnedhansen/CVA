%% CVA_check_iaf
%
% Plots IAF distribution and flags subjects with boundary or missing IAF.
% Run after CVA_eeg_fex_alpha.

%% Setup
dirs = CVA_paths();
load(fullfile(dirs.fex, 'CVA_alpha_power.mat'), 'alpha_out');

%% IAF distribution
figure('Position', [0 0 1512 982], 'Name','IAF Distribution');
histogram(alpha_out.IAF, 20, 'FaceColor', [0.2 0.5 0.8]);
xlabel('Individual Alpha Frequency (Hz)');
ylabel('N subjects');
title(sprintf('IAF Distribution (N=%d)', height(alpha_out)));
xline(8,  '--r', '8 Hz boundary');
xline(14, '--r', '14 Hz boundary');

fprintf('IAF: M=%.2f, SD=%.2f, range=[%.1f, %.1f]\n', ...
    mean(alpha_out.IAF), std(alpha_out.IAF), ...
    min(alpha_out.IAF),  max(alpha_out.IAF));

%% Save figure
saveas(gcf, fullfile(dirs.figures, 'CVA_iaf_distribution.png'));
