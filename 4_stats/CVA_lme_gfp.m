%% CVA_lme_gfp
%
% Stage 1 analysis (young cohort only):
% tests whether CSF volume predicts GFP.
%
% Model:
%   gfp_alpha ~ CSF + skull_thickness + sex

%% Setup
startup
[~, paths, ~, ~] = setup('CVA');

load(fullfile(paths.master, 'CVA_master_matrix.mat'), 'master');
inputN = height(master);

%% Restrict to young participants for stage 1
master = master(strcmp(master.age_group, 'young'), :);
if isempty(master)
    CVA_log_event('stats_gfp', 'model_failed', struct( ...
        'reason', 'no_young_participants', ...
        'input_n_master', inputN));
    error('No young participants found in CVA_master_matrix.');
end
nYoungBeforeFilter = height(master);

% Ensure complete model rows are explicitly accounted for in logs.
modelVars = {'gfp_alpha','CSF','skull_thickness_mm','sex'};
completeMask = all(~ismissing(master(:, modelVars)), 2);
nDroppedMissing = sum(~completeMask);
master = master(completeMask, :);
if isempty(master)
    CVA_log_event('stats_gfp', 'model_failed', struct( ...
        'reason', 'all_rows_missing_model_vars', ...
        'input_n_master', inputN, ...
        'n_young_before_filter', nYoungBeforeFilter, ...
        'n_dropped_missing', nDroppedMissing));
    error('No complete rows remain for GFP model after missing-data filtering.');
end

%% Z-score
zsc = @(x) (x - mean(x)) ./ (2 * std(x));

master.CSF_z   = zsc(master.CSF);
master.skull_z = zsc(master.skull_thickness_mm);
master.gfp_z   = zsc(master.gfp_alpha);
master.sex_c   = master.sex - mean(master.sex);

%% Fit
mdl = fitlm(master, 'gfp_z ~ CSF_z + skull_z + sex_c');
CVA_log_event('stats_gfp', 'model_fit', struct( ...
    'model_name', 'gfp_young_stage1', ...
    'formula', 'gfp_z ~ CSF_z + skull_z + sex_c', ...
    'input_n_master', inputN, ...
    'n_young_before_filter', nYoungBeforeFilter, ...
    'n_dropped_missing', nDroppedMissing, ...
    'n_used', height(master), ...
    'r2', mdl.Rsquared.Ordinary, ...
    'r2_adjusted', mdl.Rsquared.Adjusted, ...
    'rmse', mdl.RMSE));

%% Report
fprintf('\n========== Stage 1 (Young): CSF -> GFP ==========\n');
disp(mdl);
fprintf('R² = %.3f,  Adjusted R² = %.3f\n', mdl.Rsquared.Ordinary, mdl.Rsquared.Adjusted);

%% Save
outFile = fullfile(paths.stats, 'CVA_lme_gfp_young.mat');
save(outFile, 'mdl');
CVA_log_event('stats_gfp', 'model_saved', struct('path', outFile));

figure('Position', [0 0 1512 982], 'Name','CSF vs GFP');
plotAdded(mdl, 'CSF_z');
xlabel('CSF Volume (z-scored)');
ylabel('GFP Alpha (z-scored, partial)');
title('Young-only partial regression: CSF -> GFP');
figPath = fullfile(paths.figures, 'CVA_lme_gfp_young_partial.png');
saveas(gcf, figPath);
CVA_log_event('stats_gfp', 'figure_saved', struct('path', figPath));
