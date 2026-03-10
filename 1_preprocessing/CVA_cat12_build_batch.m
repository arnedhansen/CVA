function matlabbatch = CVA_cat12_build_batch(nii_files, dirs) %#ok<INUSD>
% CVA_CAT12_BUILD_BATCH  Build a CAT12 batch that is robust across versions.
%
% The previous implementation hard-coded many version-specific CAT12 fields.
% On systems with a different CAT12 release this can produce unresolved
% dependencies ("No executable modules"). This builder keeps only fields
% that are broadly stable and lets CAT12 defaults handle the rest.

matlabbatch = {};
matlabbatch{1}.spm.tools.cat.estwrite.data = nii_files(:);

% Use all available cores when supported.
matlabbatch{1}.spm.tools.cat.estwrite.nproc = 0;

% Keep canonical SPM TPM location; this field is stable across CAT12 builds.
matlabbatch{1}.spm.tools.cat.estwrite.opts.tpm = ...
    {fullfile(spm('dir'), 'tpm', 'TPM.nii')};

end
