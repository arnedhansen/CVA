%% CVA_lme_interaction
%
% Exploratory: tests whether the CSF→EEG relationship is moderated by age group.
%
% Model (H3):
%   [alpha_z / gfp_z] ~ CSF_z * age_group + skull_z + sex_c

%% Setup
dirs = CVA_paths();
load(fullfile(dirs.fex, 'CVA_master_matrix.mat'), 'master');

%% Z-score
zsc = @(x) (x - mean(x)) ./ (2 * std(x));

master.CSF_z      = zsc(master.CSF);
master.skull_z    = zsc(master.skull_thickness_mm);
master.alpha_z    = zsc(master.alpha_power);
master.gfp_z      = zsc(master.gfp_alpha);
master.sex_c      = master.sex - mean(master.sex);
master.age_group  = categorical(master.age_group);

%% Fit interaction models
mdl_alpha = fitlm(master, 'alpha_z ~ CSF_z * age_group + skull_z + sex_c');
mdl_gfp   = fitlm(master, 'gfp_z   ~ CSF_z * age_group + skull_z + sex_c');

%% Report
fprintf('\n========== H3: CSF × Age → Alpha ==========\n');
disp(mdl_alpha);
fprintf('\n========== H3: CSF × Age → GFP ==========\n');
disp(mdl_gfp);

%% Save
save(fullfile(dirs.stats, 'CVA_lme_interaction.mat'), 'mdl_alpha', 'mdl_gfp');

%% Plot interaction
figure('Position', [0 0 1512 982], 'Name', 'CSF x Age Interaction - Alpha');
groups = {'young','old'};
colors = {[0.2 0.5 0.8], [0.9 0.4 0.2]};
hold on;
for g = 1:2
    idx = strcmp(cellstr(master.age_group), groups{g});
    scatter(master.CSF_z(idx), master.alpha_z(idx), 30, colors{g}, 'filled', ...
            'DisplayName', groups{g});
    p = polyfit(master.CSF_z(idx), master.alpha_z(idx), 1);
    xr = linspace(min(master.CSF_z), max(master.CSF_z), 100);
    plot(xr, polyval(p, xr), 'Color', colors{g}, 'LineWidth', 2);
end
legend; xlabel('CSF Volume (z)'); ylabel('Alpha Power (z)');
title('CSF × Age Group Interaction');
saveas(gcf, fullfile(dirs.figures, 'CVA_interaction_alpha.png'));
