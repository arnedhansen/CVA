%% CVA_lme_alpha
%
% Primary analysis: tests whether CSF volume predicts posterior alpha power.
%
% Model (H1):
%   alpha_power ~ CSF + skull_thickness + age_mid + sex
%
% Predictors are z-scored (mean-centered, scaled by 2SD) prior to fitting.
% Reports standardized beta, 95% CI, and p-value.

%% Setup
dirs = CVA_paths();
load(fullfile(dirs.fex, 'CVA_master_matrix.mat'), 'master');

%% Z-score continuous predictors (2SD scaling, Gelman 2008)
zsc = @(x) (x - mean(x)) ./ (2 * std(x));

master.CSF_z   = zsc(master.CSF);
master.skull_z = zsc(master.skull_thickness_mm);
master.age_z   = zsc(master.age_mid);
master.alpha_z = zsc(master.alpha_power);
master.sex_c   = master.sex - mean(master.sex);   % center binary predictor

%% Fit LME
% No random effects needed (one obs per subject), use fitlm
mdl = fitlm(master, 'alpha_z ~ CSF_z + skull_z + age_z + sex_c');

%% Report
fprintf('\n========== H1: CSF → Alpha Power ==========\n');
disp(mdl);
fprintf('R² = %.3f,  Adjusted R² = %.3f\n', mdl.Rsquared.Ordinary, mdl.Rsquared.Adjusted);

%% Save
outFile = fullfile(dirs.stats, 'CVA_lme_alpha.mat');
save(outFile, 'mdl');

%% Plot: CSF vs alpha (partial residuals)
figure('Position', [0 0 1512 982], 'Name','CSF vs Alpha Power');
plotAdded(mdl, 'CSF_z');
xlabel('CSF Volume (z-scored)');
ylabel('Alpha Power (z-scored, partial)');
title('Partial regression: CSF → Alpha Power');
saveas(gcf, fullfile(dirs.figures, 'CVA_lme_alpha_partial.png'));
