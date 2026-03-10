%% CVA_lme_alpha
%
% Stage 1 analysis (young cohort only):
% tests whether CSF volume predicts posterior alpha power.
%
% Model:
%   alpha_power ~ CSF + skull_thickness + sex
%
% Predictors are z-scored (mean-centered, scaled by 2SD) within the
% young cohort prior to fitting.

%% Setup
dirs = CVA_paths();
load(fullfile(dirs.fex, 'CVA_master_matrix.mat'), 'master');

%% Restrict to young participants for stage 1
master = master(strcmp(master.age_group, 'young'), :);
if isempty(master)
    error('No young participants found in CVA_master_matrix.');
end

%% Z-score continuous predictors (2SD scaling, Gelman 2008)
zsc = @(x) (x - mean(x)) ./ (2 * std(x));

master.CSF_z   = zsc(master.CSF);
master.skull_z = zsc(master.skull_thickness_mm);
master.alpha_z = zsc(master.alpha_power);
master.sex_c   = master.sex - mean(master.sex);   % center binary predictor

%% Fit model
mdl = fitlm(master, 'alpha_z ~ CSF_z + skull_z + sex_c');

%% Report
fprintf('\n========== Stage 1 (Young): CSF -> Alpha Power ==========\n');
disp(mdl);
fprintf('R² = %.3f,  Adjusted R² = %.3f\n', mdl.Rsquared.Ordinary, mdl.Rsquared.Adjusted);

%% Save
outFile = fullfile(dirs.stats, 'CVA_lme_alpha_young.mat');
save(outFile, 'mdl');

%% Plot: CSF vs alpha (partial residuals)
figure('Position', [0 0 1512 982], 'Name','CSF vs Alpha Power');
plotAdded(mdl, 'CSF_z');
xlabel('CSF Volume (z-scored)');
ylabel('Alpha Power (z-scored, partial)');
title('Young-only partial regression: CSF -> Alpha Power');
saveas(gcf, fullfile(dirs.figures, 'CVA_lme_alpha_young_partial.png'));
