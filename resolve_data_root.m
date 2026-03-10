function dataRoot = resolve_data_root()
envRoot = getenv('CVA_DATA_ROOT');
if ~isempty(envRoot) && exist(envRoot, 'dir')
    dataRoot = envRoot;
    return;
end

if ispc
    candidates = {
        'W:\Students\Arne\CVA\data'
        'W:\Students\Arne\CVA\data\'
        fullfile(getenv('USERPROFILE'), 'Documents', 'GitHub', 'CVA', 'data')
    };
else
    candidates = {
        '/Volumes/g_psyplafor_methlab$/Students/Arne/CVA/data'
        fullfile(char(java.lang.System.getProperty('user.home')), 'Documents', 'GitHub', 'CVA', 'data')
    };
end

for i = 1:numel(candidates)
    if exist(candidates{i}, 'dir')
        dataRoot = candidates{i};
        return;
    end
end

error(['CVA data root not found. Set CVA_DATA_ROOT or create one of: ', ...
       strjoin(candidates, ' | ')]);
end
