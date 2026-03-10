%% CVA_demographics
%
% Loads participant demographics from LEMON CSV and aligns to subject list.
% Age bins are converted to numeric midpoints. Sex coded as 1=female, 2=male.
%
% Output: dirs.fex/CVA_demographics.mat
%   demo_out: table with columns [subID, age_mid, sex, age_group]

%% Setup
dirs = CVA_paths();

%% Load CSV
demoFile = resolve_demo_file(dirs);
demo = readtable(demoFile, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
rawNames = demo.Properties.VariableNames;
normNames = lower(regexprep(rawNames, '[^a-zA-Z0-9]', ''));

% Resolve required columns by name pattern (robust against extra columns).
idIdx  = find(ismember(normNames, {'id','participantid','subid','subjectid'}), 1);
sexIdx = find(contains(normNames, 'gender') | strcmp(normNames, 'sex'), 1);
ageIdx = find(startsWith(normNames, 'age'), 1);

if isempty(idIdx) || isempty(sexIdx) || isempty(ageIdx)
    error(['Could not identify required demographics columns in CSV. ' ...
           'Expected columns containing ID, sex/gender, and age bin.']);
end

demo = table( ...
    string(demo{:, idIdx}), ...
    demo{:, sexIdx}, ...
    string(demo{:, ageIdx}), ...
    'VariableNames', {'subID','sex','age_bin'});

% Normalize ID format to sub-XXXXXX for joins with feature tables.
for i = 1:height(demo)
    sid = strtrim(demo.subID(i));
    if startsWith(sid, "sub-")
        demo.subID(i) = sid;
    else
        demo.subID(i) = "sub-" + sid;
    end
end

%% Convert age bin to numeric midpoint
% Bins observed: '20-25','25-30','30-35','60-65','65-70' etc.
ageMid = zeros(height(demo), 1);
for i = 1:height(demo)
    ageBin = char(demo.age_bin(i));
    nums = regexp(ageBin, '\d+', 'match');
    if numel(nums) >= 2
        ageMid(i) = mean([str2double(nums{1}), str2double(nums{2})]);
    else
        ageMid(i) = NaN;
    end
end
demo.age_mid = ageMid;

%% Assign age group
demo.age_group = repmat({'young'}, height(demo), 1);
demo.age_group(demo.age_mid >= 55) = {'old'};

%% Save
demo_out = demo;
demo_out = demo_out(~isnan(demo_out.age_mid), :);
outFile  = fullfile(dirs.fex, 'CVA_demographics.mat');
save(outFile, 'demo_out');
fprintf('Saved demographics for %d subjects.\n', height(demo_out));
CVA_log_event('demographics', 'summary', struct( ...
    'n_rows_raw', height(demo), ...
    'n_rows_saved', height(demo_out), ...
    'n_rows_dropped_missing_age', height(demo) - height(demo_out), ...
    'source_file', demoFile));

function demoFile = resolve_demo_file(dirs)
candidates = {
    dirs.demo
    fullfile(fileparts(fileparts(fileparts(dirs.eeg_raw))), 'Participants_MPILMBB_LEMON.csv')
    'W:\Students\Arne\CVA\data\Participants_MPILMBB_LEMON.csv'
    'W:\Students\Arne\CVA\Participants_MPILMBB_LEMON.csv'
    '/Volumes/g_psyplafor_methlab$/Students/Arne/Participants_MPILMBB_LEMON.csv'
    '/Volumes/g_psyplafor_methlab$/Students/Arne/CVA/Participants_MPILMBB_LEMON.csv'
};

for i = 1:numel(candidates)
    if exist(candidates{i}, 'file')
        demoFile = candidates{i};
        return;
    end
end

error(['Demographics CSV not found. Checked: ', strjoin(candidates, ' | ')]);
end
