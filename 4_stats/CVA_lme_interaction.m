%% CVA_lme_interaction
%
% Stage 2 analysis (aging idea):
% tests whether the CSF->EEG relationship is moderated by age group.
%
% Model (H3):
%   [alpha_z / gfp_z] ~ CSF_z * age_group + skull_z + sex_c

%% Setup
dirs = CVA_paths();
load(fullfile(dirs.fex, 'CVA_master_matrix.mat'), 'master');
inputN = height(master);

if isempty(master)
    CVA_log_event('stats_interaction', 'model_failed', struct( ...
        'reason', 'empty_master_matrix', ...
        'input_n_master', inputN));
    error('Master matrix is empty. Cannot fit age interaction models.');
end

%% Z-score
zsc = @(x) (x - mean(x)) ./ (2 * std(x));

master.CSF_z      = zsc(master.CSF);
master.skull_z    = zsc(master.skull_thickness_mm);
master.alpha_z    = zsc(master.alpha_power);
master.gfp_z      = zsc(master.gfp_alpha);
master.sex_c      = master.sex - mean(master.sex);
master.age_group  = categorical(master.age_group);

%% Fit interaction models
alphaVars = {'alpha_z','CSF_z','age_group','skull_z','sex_c'};
gfpVars   = {'gfp_z','CSF_z','age_group','skull_z','sex_c'};

alphaMask = all(~ismissing(master(:, alphaVars)), 2);
gfpMask   = all(~ismissing(master(:, gfpVars)), 2);
alphaData = master(alphaMask, :);
gfpData   = master(gfpMask, :);

if isempty(alphaData)
    CVA_log_event('stats_interaction', 'model_failed', struct( ...
        'reason', 'no_complete_rows_alpha_interaction', ...
        'input_n_master', inputN));
    error('No complete rows remain for alpha interaction model.');
end
if isempty(gfpData)
    CVA_log_event('stats_interaction', 'model_failed', struct( ...
        'reason', 'no_complete_rows_gfp_interaction', ...
        'input_n_master', inputN));
    error('No complete rows remain for GFP interaction model.');
end

mdl_alpha = fitlm(alphaData, 'alpha_z ~ CSF_z * age_group + skull_z + sex_c');
mdl_gfp   = fitlm(gfpData,   'gfp_z   ~ CSF_z * age_group + skull_z + sex_c');

alphaInteraction = extract_interaction_row(mdl_alpha);
gfpInteraction   = extract_interaction_row(mdl_gfp);
CVA_log_event('stats_interaction', 'models_fit', struct( ...
    'input_n_master', inputN, ...
    'n_alpha_used', height(alphaData), ...
    'n_alpha_dropped_missing', sum(~alphaMask), ...
    'n_gfp_used', height(gfpData), ...
    'n_gfp_dropped_missing', sum(~gfpMask), ...
    'alpha_model_formula', 'alpha_z ~ CSF_z * age_group + skull_z + sex_c', ...
    'alpha_r2', mdl_alpha.Rsquared.Ordinary, ...
    'alpha_r2_adjusted', mdl_alpha.Rsquared.Adjusted, ...
    'alpha_rmse', mdl_alpha.RMSE, ...
    'alpha_interaction', alphaInteraction, ...
    'gfp_model_formula', 'gfp_z ~ CSF_z * age_group + skull_z + sex_c', ...
    'gfp_r2', mdl_gfp.Rsquared.Ordinary, ...
    'gfp_r2_adjusted', mdl_gfp.Rsquared.Adjusted, ...
    'gfp_rmse', mdl_gfp.RMSE, ...
    'gfp_interaction', gfpInteraction));

%% Report
fprintf('\n========== Stage 2: CSF x Age Group -> Alpha ==========\n');
disp(mdl_alpha);
fprintf('\n========== Stage 2: CSF x Age Group -> GFP ==========\n');
disp(mdl_gfp);

%% Save
outFile = fullfile(dirs.stats, 'CVA_lme_interaction.mat');
save(outFile, 'mdl_alpha', 'mdl_gfp');
CVA_log_event('stats_interaction', 'models_saved', struct('path', outFile));

%% Plot interaction
figure('Position', [0 0 1512 982], 'Name', 'CSF x Age Interaction - Alpha');
groups = {'young','old'};
colors = {[0.2 0.5 0.8], [0.9 0.4 0.2]};
hold on;
for g = 1:2
    idx = strcmp(cellstr(alphaData.age_group), groups{g});
    scatter(alphaData.CSF_z(idx), alphaData.alpha_z(idx), 30, colors{g}, 'filled', ...
            'DisplayName', groups{g});
    p = polyfit(alphaData.CSF_z(idx), alphaData.alpha_z(idx), 1);
    xr = linspace(min(alphaData.CSF_z), max(alphaData.CSF_z), 100);
    plot(xr, polyval(p, xr), 'Color', colors{g}, 'LineWidth', 2);
end
legend; xlabel('CSF Volume (z)'); ylabel('Alpha Power (z)');
title('CSF × Age Group Interaction');
figPath = fullfile(dirs.figures, 'CVA_interaction_alpha.png');
saveas(gcf, figPath);
CVA_log_event('stats_interaction', 'figure_saved', struct('path', figPath));

function out = extract_interaction_row(mdl)
names = mdl.CoefficientNames;
idx = find(contains(names, 'CSF_z:age_group_'), 1, 'first');
if isempty(idx)
    out = struct('term', '', 'estimate', NaN, 'se', NaN, 't', NaN, 'p', NaN);
    return;
end
coef = mdl.Coefficients;
out = struct();
out.term = names{idx};
out.estimate = coef.Estimate(idx);
out.se = coef.SE(idx);
out.t = coef.tStat(idx);
out.p = coef.pValue(idx);
end
