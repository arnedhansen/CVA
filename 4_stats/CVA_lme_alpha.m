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
inputN = height(master);

%% Restrict to young participants for stage 1
master = master(strcmp(master.age_group, 'young'), :);
if isempty(master)
    CVA_log_event('stats_alpha', 'model_failed', struct( ...
        'reason', 'no_young_participants', ...
        'input_n_master', inputN));
    error('No young participants found in CVA_master_matrix.');
end
nYoungBeforeFilter = height(master);

% Ensure complete model rows are explicitly accounted for in logs.
modelVars = {'alpha_power','CSF','skull_thickness_mm','sex'};
completeMask = all(~ismissing(master(:, modelVars)), 2);
nDroppedMissing = sum(~completeMask);
master = master(completeMask, :);
if isempty(master)
    CVA_log_event('stats_alpha', 'model_failed', struct( ...
        'reason', 'all_rows_missing_model_vars', ...
        'input_n_master', inputN, ...
        'n_young_before_filter', nYoungBeforeFilter, ...
        'n_dropped_missing', nDroppedMissing));
    error('No complete rows remain for alpha model after missing-data filtering.');
end

%% Z-score continuous predictors (2SD scaling, Gelman 2008)
zsc = @(x) (x - mean(x)) ./ (2 * std(x));

master.CSF_z   = zsc(master.CSF);
master.skull_z = zsc(master.skull_thickness_mm);
master.alpha_z = zsc(master.alpha_power);
master.sex_c   = master.sex - mean(master.sex);   % center binary predictor

%% Fit model
mdl = fitlm(master, 'alpha_z ~ CSF_z + skull_z + sex_c');
CVA_log_event('stats_alpha', 'model_fit', struct( ...
    'model_name', 'alpha_young_stage1', ...
    'formula', 'alpha_z ~ CSF_z + skull_z + sex_c', ...
    'input_n_master', inputN, ...
    'n_young_before_filter', nYoungBeforeFilter, ...
    'n_dropped_missing', nDroppedMissing, ...
    'n_used', height(master), ...
    'r2', mdl.Rsquared.Ordinary, ...
    'r2_adjusted', mdl.Rsquared.Adjusted, ...
    'rmse', mdl.RMSE));

%% Report
fprintf('\n========== Stage 1 (Young): CSF -> Alpha Power ==========\n');
disp(mdl);
fprintf('R² = %.3f,  Adjusted R² = %.3f\n', mdl.Rsquared.Ordinary, mdl.Rsquared.Adjusted);

%% Save
outFile = fullfile(dirs.stats, 'CVA_lme_alpha_young.mat');
save(outFile, 'mdl');
CVA_log_event('stats_alpha', 'model_saved', struct('path', outFile));

%% Plot: CSF vs alpha (partial residuals)
figure('Position', [0 0 1512 982], 'Name','CSF vs Alpha Power');
plotAdded(mdl, 'CSF_z');
xlabel('CSF Volume (z-scored)');
ylabel('Alpha Power (z-scored, partial)');
title('Young-only partial regression: CSF -> Alpha Power');
figPath = fullfile(dirs.figures, 'CVA_lme_alpha_young_partial.png');
saveas(gcf, figPath);
CVA_log_event('stats_alpha', 'figure_saved', struct('path', figPath));
