%% CVA_demographics
%
% Loads participant demographics from the LEMON CSV and aligns to the
% subject list.
%
% Age is retained as the original 5-year bin string (e.g. '20-25') rather
% than being converted to a numeric midpoint. The LEMON dataset provides
% only binned age for privacy reasons; converting bins to midpoints implies
% a precision that does not exist in the data and introduces arbitrary
% rounding error. Age group (young / old) is derived directly from the bin.
%
% Sex is coded as numeric: 1 = female, 2 = male.
%
% Output: paths.demo_fex/CVA_demographics.mat
%   demo_out: table with columns [subID, age_bin, sex, age_group]

%% Setup
startup
[~, paths, ~, ~] = setup('CVA');

%% Load CSV
demoFile = '/Volumes/g_psyplafor_methlab$/Students/Arne/CVA/data/LEMON/demographics/Participants_MPILMBB_LEMON.csv';
demo     = readtable(demoFile, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
rawNames  = demo.Properties.VariableNames;
normNames = lower(regexprep(rawNames, '[^a-zA-Z0-9]', ''));

% Identify required columns by name pattern
idIdx  = find(ismember(normNames, {'id','participantid','subid','subjectid'}), 1);
sexIdx = find(contains(normNames, 'gender') | strcmp(normNames, 'sex'), 1);
ageIdx = find(startsWith(normNames, 'age'), 1);

if isempty(idIdx) || isempty(sexIdx) || isempty(ageIdx)
    error(['Could not identify required columns in CSV. ', ...
           'Expected columns for ID, sex/gender, and age bin.']);
end

demo = table( ...
    string(demo{:, idIdx}), ...
    demo{:, sexIdx}, ...
    string(demo{:, ageIdx}), ...
    'VariableNames', {'subID','sex','age_bin'});

%% Normalize subject ID format to sub-XXXXXX
for i = 1:height(demo)
    sid = strtrim(demo.subID(i));
    if ~startsWith(sid, "sub-")
        demo.subID(i) = "sub-" + sid;
    else
        demo.subID(i) = sid;
    end
end

%% Derive age group directly from bin string
%
% LEMON age bins: young cohort = 20-25, 25-30, 30-35
%                 old cohort   = 59-65, 60-65, 65-70, 70-75, 75-80
%
% Strategy: extract the lower bound of the bin and threshold at 55.
% This is unambiguous for the LEMON sample (gap between 35 and 59).
% Bins that cannot be parsed are flagged as missing.
ageLo    = nan(height(demo), 1);
hasValid = true(height(demo), 1);

for i = 1:height(demo)
    nums = regexp(char(demo.age_bin(i)), '\d+', 'match');
    if ~isempty(nums)
        ageLo(i) = str2double(nums{1});
    else
        hasValid(i) = false;
        warning('Could not parse age bin "%s" for subject %s — excluding.', ...
            char(demo.age_bin(i)), char(demo.subID(i)));
    end
end

demo.age_group = repmat({'young'}, height(demo), 1);
demo.age_group(ageLo >= 55) = {'old'};

%% Remove rows with unparseable age bins
nRaw     = height(demo);
demo_out = demo(hasValid, :);
nDropped = nRaw - height(demo_out);

if nDropped > 0
    fprintf('Dropped %d subjects with unparseable age bins.\n', nDropped);
end

%% Report
nYoung = sum(strcmp(demo_out.age_group, 'young'));
nOld   = sum(strcmp(demo_out.age_group, 'old'));
fprintf('Demographics loaded: N=%d  (young=%d, old=%d)\n', ...
    height(demo_out), nYoung, nOld);

% Show observed age bins for sanity check
fprintf('Age bins (young): %s\n', ...
    strjoin(unique(demo_out.age_bin(strcmp(demo_out.age_group,'young'))), ', '));
fprintf('Age bins (old):   %s\n', ...
    strjoin(unique(demo_out.age_bin(strcmp(demo_out.age_group,'old'))), ', '));

%% Save
outFile = fullfile(paths.demo_fex, 'CVA_demographics.mat');
save(outFile, 'demo_out');
fprintf('Saved demographics to %s\n', outFile);

CVA_log_event('demographics', 'summary', struct( ...
    'n_rows_raw',          nRaw, ...
    'n_rows_saved',        height(demo_out), ...
    'n_rows_dropped',      nDropped, ...
    'n_young',             nYoung, ...
    'n_old',               nOld, ...
    'source_file',         demoFile));
