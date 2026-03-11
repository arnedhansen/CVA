s_cloud = 1;
 
if s_cloud == 1
    prefix = fullfile(filesep, 'mnt', 'methlab-drive','methlab');
    jobfile = fullfile(prefix, 'Students','Katharina_Bremer','Scripts','Matlab', ...
                       'SPM','VBM','Cat12OneSubjectServer.mat');
else
    prefix = fullfile(filesep, 'Volumes','G_PSYPLAFOR_methlab$');
    jobfile = fullfile(prefix, 'Students','Katharina_Bremer','Scripts','Matlab', ...
                       'SPM','VBM','Cat12OneSubject_jobFinal.mat');
end

load(jobfile, 'matlabbatch');

addpath(fullfile(prefix, 'Students', 'Katharina_Bremer', 'Scripts', 'Matlab', 'matlab_installation', 'spm'));
spm('defaults','fmri');
spm_jobman('initcfg');
addpath(fullfile(prefix, 'Students', 'Katharina_Bremer', 'Scripts', 'Matlab', 'matlab_installation', 'spm','toolbox','cat12'));

T = dir(fullfile(prefix,'Students/Katharina_Bremer/Input/ABIDE_II_UPSM/*/anat.nii'));
T1_files = fullfile({T.folder}, {T.name});
T1_files = strcat(T1_files, ',1');

for i = 1:numel(T1_files)
    batch = matlabbatch;
    batch{1}.spm.tools.cat.estwrite.data = {T1_files{i}};
    spm_jobman('run', batch);
end;
