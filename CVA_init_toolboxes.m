function CVA_init_toolboxes(runSetup)
% CVA_INIT_TOOLBOXES Safely initialize external MATLAB toolboxes.
%
% Adds required toolbox roots explicitly and avoids brittle side effects from
% startup/setup scripts unless explicitly requested.
%
% Usage:
%   CVA_init_toolboxes()          % default: explicit path bootstrap only
%   CVA_init_toolboxes(true)      % bootstrap + startup/setup

persistent isInitialized;
if nargin < 1
    runSetup = false;
end

if isInitialized
    return;
end

projectRoot = fileparts(mfilename('fullpath'));

if exist(projectRoot, 'dir')
    addpath(genpath(projectRoot));
end

toolboxCandidates = {
    getenv('CVA_TOOLBOX_DIR')
    getenv('TOOLBOX_DIR')
};
if ispc
    toolboxCandidates = [toolboxCandidates(:); {
        'W:\Students\Arne\toolboxes'
        fullfile(getenv('USERPROFILE'), 'Documents', 'MATLAB', 'toolboxes')
    }];
else
    toolboxCandidates = [toolboxCandidates(:); {
        '/Volumes/g_psyplafor_methlab$/Students/Arne/toolboxes'
        fullfile(char(java.lang.System.getProperty('user.home')), 'toolboxes')
    }];
end
toolboxRoot = first_existing_dir(toolboxCandidates);

if ~isempty(toolboxRoot)
    ftRoot = first_existing_dir({
        fullfile(toolboxRoot, 'fieldtrip-20250928')
        fullfile(toolboxRoot, 'fieldtrip')
    });
    if ~isempty(ftRoot)
        addpath(ftRoot);
        if exist('ft_defaults', 'file') == 2
            ft_defaults;
        end
    end

    spmRoot = first_existing_dir({
        fullfile(toolboxRoot, 'spm12')
        fullfile(toolboxRoot, 'SPM12')
    });
    if ~isempty(spmRoot)
        addpath(spmRoot);
        cat12Root = first_existing_dir({
            fullfile(spmRoot, 'toolbox', 'cat12')
            fullfile(spmRoot, 'toolbox', 'CAT12')
        });
        if ~isempty(cat12Root)
            addpath(cat12Root);
        end
    end
end

if runSetup && exist('startup', 'file') == 2
    try
        evalin('base', 'startup;');
    catch ME
        warning('startup() failed and was skipped: %s', ME.message);
    end
end

if runSetup && exist('setup', 'file') == 2
    try
        evalin('base', 'setup;');
    catch ME
        warning('setup() failed and was skipped: %s', ME.message);
    end
end

isInitialized = true;

end

function d = first_existing_dir(candidates)
d = '';
for i = 1:numel(candidates)
    c = candidates{i};
    if isempty(c)
        continue;
    end
    if exist(c, 'dir')
        d = c;
        return;
    end
end
end
