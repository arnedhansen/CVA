%% CVA_lme_gfp
%
% Stage 1 analysis (young cohort only):
% tests whether CSF volume predicts GFP.
%
% Model:
%   gfp_alpha ~ CSF + skull_thickness + sex

%% Setup
dirs = CVA_paths();
load(fullfile(dirs.fex, 'CVA_master_matrix.mat'), 'master');

%% Restrict to young participants for stage 1
master = master(strcmp(master.age_group, 'young'), :);
if isempty(master)
    error('No young participants found in CVA_master_matrix.');
end

%% Z-score
zsc = @(x) (x - mean(x)) ./ (2 * std(x));

master.CSF_z   = zsc(master.CSF);
master.skull_z = zsc(master.skull_thickness_mm);
master.gfp_z   = zsc(master.gfp_alpha);
master.sex_c   = master.sex - mean(master.sex);

%% Fit
mdl = fitlm(master, 'gfp_z ~ CSF_z + skull_z + sex_c');

%% Report
fprintf('\n========== Stage 1 (Young): CSF -> GFP ==========\n');
disp(mdl);
fprintf('R² = %.3f,  Adjusted R² = %.3f\n', mdl.Rsquared.Ordinary, mdl.Rsquared.Adjusted);

%% Save
outFile = fullfile(dirs.stats, 'CVA_lme_gfp_young.mat');
save(outFile, 'mdl');

figure('Position', [0 0 1512 982], 'Name','CSF vs GFP');
plotAdded(mdl, 'CSF_z');
xlabel('CSF Volume (z-scored)');
ylabel('GFP Alpha (z-scored, partial)');
title('Young-only partial regression: CSF -> GFP');
saveas(gcf, fullfile(dirs.figures, 'CVA_lme_gfp_young_partial.png'));
