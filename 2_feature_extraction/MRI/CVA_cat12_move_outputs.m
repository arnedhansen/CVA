function CVA_cat12_move_outputs(subjects, nii_files, dirs)
% CVA_CAT12_MOVE_OUTPUTS  Moves CAT12 output files into per-subject folders.
%
%   CVA_cat12_move_outputs(subjects, nii_files, dirs)
%
%   By default CAT12 writes all outputs into the same folder as the input
%   NIfTI. This function reorganises them into:
%
%   dirs.mri_proc/
%     sub-XXXXXX/
%       mri/        ← tissue segments (p0,p1,p2,p3,p4* images)
%       report/     ← cat_*.xml, cat_*.pdf (QC report)
%
%   *p4 = bone (tissue class 4), used for skull thickness.
%   CAT12 writes tissue classes 4-6 as part of the TPMC output if enabled.

for s = 1:numel(subjects)
    subID   = subjects{s};
    niiPath = strrep(nii_files{s}, ',1', '');
    srcDir  = fileparts(niiPath);
    [~, stem] = fileparts(niiPath);   % filename without .nii

    % Destination folders
    destMRI    = fullfile(dirs.mri_proc, subID, 'mri');
    destReport = fullfile(dirs.mri_proc, subID, 'report');
    if ~exist(destMRI,    'dir'), mkdir(destMRI);    end
    if ~exist(destReport, 'dir'), mkdir(destReport); end

    %% Move tissue maps: p0, p1, p2, p3, p4, p5, p6 + bias-corrected (m*)
    prefixes = {'p0','p1','p2','p3','p4','p5','p6','m'};
    for p = 1:numel(prefixes)
        pattern = fullfile(srcDir, [prefixes{p} stem '.nii']);
        if exist(pattern, 'file')
            movefile(pattern, fullfile(destMRI, [prefixes{p} stem '.nii']));
        end
    end

    %% Move report files: cat_*.xml, cat_*.pdf
    reportPatterns = {
        fullfile(srcDir, 'report', ['cat_' stem '.xml'])
        fullfile(srcDir, 'report', ['cat_' stem '.pdf'])
        };
    for r = 1:numel(reportPatterns)
        if exist(reportPatterns{r}, 'file')
            [~, fn, ext] = fileparts(reportPatterns{r});
            movefile(reportPatterns{r}, fullfile(destReport, [fn ext]));
        end
    end

    fprintf('[Moved outputs] %s\n', subID);
end

fprintf('Output reorganisation complete.\n');
end
