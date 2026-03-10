%% CVA_lme_gfp
%
% Primary analysis: tests whether CSF volume predicts GFP.
%
% Model (H2):
%   gfp_alpha ~ CSF + skull_thickness + age_mid + sex

%% Setup
dirs = CVA_paths();
load(fullfile(dirs.fex, 'CVA_master_matrix.mat'), 'master');

%% Z-score
zsc = @(x) (x - mean(x)) ./ (2 * std(x));

master.CSF_z   = zsc(master.CSF);
master.skull_z = zsc(master.skull_thickness_mm);
master.age_z   = zsc(master.age_mid);
master.gfp_z   = zsc(master.gfp_alpha);
master.sex_c   = master.sex - mean(master.sex);

%% Fit
mdl = fitlm(master, 'gfp_z ~ CSF_z + skull_z + age_z + sex_c');

%% Report
fprintf('\n========== H2: CSF → GFP ==========\n');
disp(mdl);
fprintf('R² = %.3f,  Adjusted R² = %.3f\n', mdl.Rsquared.Ordinary, mdl.Rsquared.Adjusted);

%% Save
outFile = fullfile(dirs.stats, 'CVA_lme_gfp.mat');
save(outFile, 'mdl');

figure('Position', [0 0 1512 982], 'Name','CSF vs GFP');
plotAdded(mdl, 'CSF_z');
xlabel('CSF Volume (z-scored)');
ylabel('GFP Alpha (z-scored, partial)');
title('Partial regression: CSF → GFP');
saveas(gcf, fullfile(dirs.figures, 'CVA_lme_gfp_partial.png'));
