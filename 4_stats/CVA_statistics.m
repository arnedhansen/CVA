%% CVA_statistics
%
% Primary and exploratory statistical analyses for the CVA project.
%
% Design: cross-sectional, one observation per subject.
% Model:  ordinary linear regression (fitlm) with fixed effects only.
%
% NOTE on random effects: the paper's original formula included (1|Subject),
% but in a cross-sectional design where each subject contributes exactly
% one observation, a subject-level random intercept is not identified —
% it is mathematically equivalent to residual error and will produce a
% singular fit. Standard OLS (fitlm) is the correct choice here.
%
% All continuous predictors are mean-centred and scaled by 2 SD before
% fitting (Gelman, 2008). This places regression coefficients on a
% comparable scale (a 1-unit change = a 2-SD change in the predictor)
% and allows direct comparison of effect sizes across predictors.
%
% Models:
%   H1: [alpha_power] ~ CSF_TIV + skull_thickness_mm + age_group + sex
%   H2: [gfp_mean]    ~ CSF_TIV + skull_thickness_mm + age_group + sex
%   H2b:[gfp_alpha]   ~ CSF_TIV + skull_thickness_mm + age_group + sex
%
%   Exploratory H3 (Age x CSF interaction):
%       [alpha_power] ~ CSF_TIV * age_group + skull_thickness_mm + sex
%       [gfp_mean]    ~ CSF_TIV * age_group + skull_thickness_mm + sex
%
% Outputs written to paths.master/:
%   CVA_stats_results.mat  — all mdl objects + coefficient tables
%   CVA_stats_results.csv  — flattened coefficient table for all models

%% Setup
startup
[~, paths, ~, ~] = setup('CVA');

%% Load master matrix
load(fullfile(paths.master, 'CVA_master_matrix.mat'), 'master');
fprintf('Loaded master matrix: N = %d\n', height(master));

%% Prepare predictors
% Continuous predictors: mean-centre and scale by 2 SD (Gelman 2008)
contVars = {'CSF_TIV', 'skull_thickness_mm'};
masterZ  = master;   % working copy with scaled variables

for i = 1:numel(contVars)
    v       = contVars{i};
    mu      = mean(master.(v));
    sd2     = 2 * std(master.(v));
    scaledV = [v '_z'];
    masterZ.(scaledV) = (master.(v) - mu) / sd2;
    fprintf('Scaled %s: M=%.3f, 2SD=%.3f\n', v, mu, sd2);
end

% Categorical predictors: ensure correct datatypes
% age_group: 'young' (reference) vs 'old'
masterZ.age_group = categorical(masterZ.age_group, {'young','old'});

% sex: coded as numeric in demographics (1=female, 2=male)
% Convert to categorical with female as reference
masterZ.sex = categorical(masterZ.sex, [1 2], {'female','male'});

%% Fit primary models (H1, H2, H2b)
fprintf('\n--- Primary Models ---\n');

models = struct();

% H1: Posterior alpha power
models.alpha = fitlm(masterZ, ...
    'alpha_power ~ CSF_TIV_z + skull_thickness_mm_z + age_group + sex');
print_model(models.alpha, 'H1: Alpha power ~ CSF_TIV + Skull + Age + Sex');

% H2: Broadband GFP
models.gfp = fitlm(masterZ, ...
    'gfp_mean ~ CSF_TIV_z + skull_thickness_mm_z + age_group + sex');
print_model(models.gfp, 'H2: GFP mean ~ CSF_TIV + Skull + Age + Sex');

% H2b: Alpha-band GFP
models.gfp_alpha = fitlm(masterZ, ...
    'gfp_alpha ~ CSF_TIV_z + skull_thickness_mm_z + age_group + sex');
print_model(models.gfp_alpha, 'H2b: GFP alpha ~ CSF_TIV + Skull + Age + Sex');

%% Exploratory models (H3: Age × CSF interaction)
fprintf('\n--- Exploratory Models (Age x CSF interaction) ---\n');

models.alpha_int = fitlm(masterZ, ...
    'alpha_power ~ CSF_TIV_z * age_group + skull_thickness_mm_z + sex');
print_model(models.alpha_int, 'H3a: Alpha power ~ CSF_TIV * Age + Skull + Sex');

models.gfp_int = fitlm(masterZ, ...
    'gfp_mean ~ CSF_TIV_z * age_group + skull_thickness_mm_z + sex');
print_model(models.gfp_int, 'H3b: GFP mean ~ CSF_TIV * Age + Skull + Sex');

%% Likelihood-ratio tests: interaction models vs main-effect models
% Tests whether adding the Age x CSF interaction significantly improves fit.
fprintf('\n--- Likelihood-Ratio Tests (interaction vs. main effects) ---\n');

lrt_alpha = compare(models.alpha, models.alpha_int);
lrt_gfp   = compare(models.gfp,  models.gfp_int);

fprintf('Alpha: chi2(1) = %.3f, p = %.4f\n', ...
    lrt_alpha.Chi2Stat(2), lrt_alpha.pValue(2));
fprintf('GFP:   chi2(1) = %.3f, p = %.4f\n', ...
    lrt_gfp.Chi2Stat(2),   lrt_gfp.pValue(2));

%% Multicollinearity check (VIF)
fprintf('\n--- Variance Inflation Factors ---\n');
check_vif(masterZ, {'CSF_TIV_z','skull_thickness_mm_z','age_group','sex'});

%% Collate coefficient tables
allCoefTables = collate_coef_tables(models);

%% Save
outMat = fullfile(paths.master, 'CVA_stats_results.mat');
outCSV = fullfile(paths.master, 'CVA_stats_results.csv');
save(outMat, 'models', 'allCoefTables');
writetable(allCoefTables, outCSV);
fprintf('\nResults saved to %s\n', outCSV);

CVA_log_event('statistics', 'run_complete', struct( ...
    'n', height(master), ...
    'output_csv', outCSV));

% =========================================================================
function print_model(mdl, title)
fprintf('\n=== %s ===\n', title);
fprintf('R² = %.3f  (adj. R² = %.3f)  N = %d\n', ...
    mdl.Rsquared.Ordinary, mdl.Rsquared.Adjusted, mdl.NumObservations);
disp(mdl.Coefficients);
end

% =========================================================================
function check_vif(T, predVars)
% Compute VIF for each predictor via auxiliary regressions.
% VIF(j) = 1 / (1 - R²_j), where R²_j is the R² of regressing predictor j
% on all other predictors.
for i = 1:numel(predVars)
    others = predVars(~strcmp(predVars, predVars{i}));
    formula = [predVars{i}, ' ~ ', strjoin(others, ' + ')];
    try
        aux = fitlm(T, formula);
        vif = 1 / (1 - aux.Rsquared.Ordinary);
        flag = '';
        if vif > 5, flag = ' <<< HIGH'; end
        fprintf('VIF(%s) = %.2f%s\n', predVars{i}, vif, flag);
    catch
        fprintf('VIF(%s) = could not compute\n', predVars{i});
    end
end
end

% =========================================================================
function T = collate_coef_tables(models)
% Flatten all model coefficient tables into one table with a Model column.
fnames = fieldnames(models);
T = table();
for i = 1:numel(fnames)
    ct          = models.(fnames{i}).Coefficients;
    ct.Model    = repmat({fnames{i}}, height(ct), 1);
    ct.Term     = ct.Properties.RowNames;
    ct          = movevars(ct, {'Model','Term'}, 'Before', 1);
    ct.Properties.RowNames = {};
    T = [T; ct]; %#ok<AGROW>
end
end
