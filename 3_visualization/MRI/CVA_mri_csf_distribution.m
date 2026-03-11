%% CVA_mri_csf_distribution
%
% Visualizes distribution of MRI-derived volumetric measures.

%% Setup
startup
[~, paths, ~, ~] = setup('CVA');

inFile = fullfile(paths.mri_fex, 'CVA_mri_volumes.mat');
if ~exist(inFile, 'file')
    warning('Missing file: %s. Run CVA_mri_fex_csf first.', inFile);
    return;
end
load(inFile, 'vol_out');

if isempty(vol_out) || height(vol_out) == 0
    warning('vol_out is empty. No MRI distributions plotted.');
    return;
end

fig = figure('Position', [0 0 1512 982], 'Name', 'CVA MRI Volume Distributions');
tiledlayout(2,2);

nexttile;
histogram(vol_out.CSF, 25, 'FaceColor', [0.12 0.47 0.71], 'EdgeColor', 'none');
xlabel('CSF volume');
ylabel('Count');
title('CSF');
grid on;

nexttile;
histogram(vol_out.GM, 25, 'FaceColor', [0.17 0.63 0.17], 'EdgeColor', 'none');
xlabel('GM volume');
ylabel('Count');
title('GM');
grid on;

nexttile;
histogram(vol_out.WM, 25, 'FaceColor', [0.84 0.15 0.16], 'EdgeColor', 'none');
xlabel('WM volume');
ylabel('Count');
title('WM');
grid on;

nexttile;
histogram(vol_out.TBV, 25, 'FaceColor', [0.58 0.40 0.74], 'EdgeColor', 'none');
xlabel('TBV');
ylabel('Count');
title('TBV');
grid on;

exportgraphics(fig, fullfile(paths.figures, 'CVA_mri_csf_distribution.png'), 'Resolution', 300);
close(fig);
