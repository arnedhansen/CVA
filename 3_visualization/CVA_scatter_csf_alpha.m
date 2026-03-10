%% CVA_scatter_csf_alpha
%
% Scatter plot: CSF volume vs posterior alpha power.

dirs = CVA_paths();
masterFile = fullfile(dirs.fex, 'CVA_master_matrix.mat');
if ~exist(masterFile, 'file')
    warning('Missing file: %s. Run CVA_master_matrix first.', masterFile);
    return;
end
load(masterFile, 'master');

required = {'CSF','alpha_power','age_group'};
if isempty(master) || ~all(ismember(required, master.Properties.VariableNames))
    warning('Master matrix missing required columns: %s', strjoin(required, ', '));
    return;
end

fig = figure('Position', [0 0 1512 982], 'Name', 'CSF vs Alpha Power');
gscatter(master.CSF, master.alpha_power, categorical(master.age_group));
xlabel('CSF volume');
ylabel('Posterior alpha power');
title('CSF vs posterior alpha power');
grid on;
lsline;

exportgraphics(fig, fullfile(dirs.figures, 'CVA_scatter_csf_alpha.png'), 'Resolution', 300);
close(fig);
