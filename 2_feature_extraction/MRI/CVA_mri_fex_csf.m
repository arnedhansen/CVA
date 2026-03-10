%% CVA_mri_fex_csf
%
% Extracts tissue volumes from CAT12 segmentation output per subject:
%   - TBV  (total brain volume = GM + WM)
%   - GM   (gray matter volume)
%   - WM   (white matter volume)
%   - CSF  (cerebrospinal fluid volume)
%
% Reads from CAT12 XML report files (cat_*.xml) or alternatively the
% catROI_*.mat files in the CAT12 derivatives folder.
%
% Output: dirs.fex/CVA_mri_volumes.mat
%   vol_out: table with columns [subID, TBV, GM, WM, CSF]

%% Setup
dirs     = CVA_paths();
subjects = CVA_get_subjects();

vol_out = table();

for s = 1:numel(subjects)
    subID = subjects{s};
    fprintf('[MRI CSF FEX] %s (%d/%d)\n', subID, s, numel(subjects));

    % CAT12 report XML location (adjust subfolder name if needed)
    xmlFile = fullfile(dirs.mri_proc, subID, 'report', ...
                       ['cat_' subID '_ses-01_acq-mp2rage_brain.xml']);

    if ~exist(xmlFile, 'file')
        warning('CAT12 XML not found for %s', subID);
        continue;
    end

    try
        %% Parse CAT12 XML
        S = cat_io_xml(xmlFile);   % CAT12 helper function

        gm  = S.subjectmeasures.vol_abs_CGW(3);   % gray matter
        wm  = S.subjectmeasures.vol_abs_CGW(2);   % white matter
        csf = S.subjectmeasures.vol_abs_CGW(1);   % CSF
        tbv = gm + wm;

        %% Append
        row     = table({subID}, tbv, gm, wm, csf, ...
                        'VariableNames', {'subID','TBV','GM','WM','CSF'});
        vol_out = [vol_out; row]; %#ok<AGROW>

    catch ME
        warning('Failed for %s: %s', subID, ME.message);
    end
end

%% Save
outFile = fullfile(dirs.fex, 'CVA_mri_volumes.mat');
save(outFile, 'vol_out');
fprintf('Saved MRI volumes for %d subjects to %s\n', height(vol_out), outFile);
