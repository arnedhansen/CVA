%% CVA_scatter_csf_gfp
%
% Scatter plot: CSF volume vs global field power (temporal GFP).

%% Setup
startup
[~, paths, ~, ~] = setup('CVA');

masterFile = fullfile(paths.fex, 'CVA_master_matrix.mat');
if ~exist(masterFile, 'file')
    warning('Missing file: %s. Run CVA_master_matrix first.', masterFile);
    return;
end
load(masterFile, 'master');

required = {'CSF','gfp_mean','age_group'};
if isempty(master) || ~all(ismember(required, master.Properties.VariableNames))
    warning('Master matrix missing required columns: %s', strjoin(required, ', '));
    return;
end

fig = figure('Position', [0 0 1512 982], 'Name', 'CSF vs GFP');
gscatter(master.CSF, master.gfp_mean, categorical(master.age_group));
xlabel('CSF volume');
ylabel('Global field power (mean)');
title('CSF vs GFP');
grid on;
lsline;

exportgraphics(fig, fullfile(paths.figures, 'CVA_scatter_csf_gfp.png'), 'Resolution', 300);
close(fig);
