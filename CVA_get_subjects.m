function subjects = CVA_get_subjects(subjectOverride)
% CVA_GET_SUBJECTS  Returns subject IDs available in EEG data dir.
%
%   subjects = CVA_get_subjects()
%   subjects = CVA_get_subjects(subjectOverride)
%
% Optional subjectOverride can be:
%   - char/string scalar: 'sub-032301' or '032301'
%   - cellstr/string array: {'sub-032301','sub-032302'}
%
% Without function input, environment variables are checked:
%   CVA_SUBJECTS  (comma/semicolon/space separated)
%   CVA_SUBJECT   (single subject)

if nargin < 1
    subjectOverride = [];
end

dirs     = CVA_paths();
listing  = dir(fullfile(dirs.eeg_raw, 'sub-*'));
subjects = {listing([listing.isdir]).name};

overrideSubjects = parse_subject_override(subjectOverride);
if ~isempty(overrideSubjects)
    % Keep requested order and drop missing IDs from the run list.
    foundMask = ismember(overrideSubjects, subjects);
    found     = overrideSubjects(foundMask);
    missing   = overrideSubjects(~foundMask);

    if ~isempty(missing)
        warning('Requested subjects not found and will be skipped: %s', ...
            strjoin(missing, ', '));
    end
    if isempty(found)
        error('CVA_get_subjects:NoMatchingSubject', ...
            'No requested subjects were found in %s.', dirs.eeg_raw);
    end
    subjects = found;
end

fprintf('Found %d subjects.\n', numel(subjects));
CVA_log_event('subjects', 'subject_discovery', struct( ...
    'source_dir', dirs.eeg_raw, ...
    'n_subjects', numel(subjects), ...
    'override_requested', ~isempty(overrideSubjects)));
end

function overrideSubjects = parse_subject_override(subjectOverride)
overrideSubjects = normalize_subject_list(subjectOverride);
if ~isempty(overrideSubjects)
    return;
end

envSubjects = strtrim(getenv('CVA_SUBJECTS'));
if ~isempty(envSubjects)
    tokens = regexp(envSubjects, '[,;\s]+', 'split');
    tokens = tokens(~cellfun(@isempty, tokens));
    overrideSubjects = normalize_subject_list(tokens);
    return;
end

envSubject = strtrim(getenv('CVA_SUBJECT'));
overrideSubjects = normalize_subject_list(envSubject);
end

function out = normalize_subject_list(in)
out = {};
if isempty(in)
    return;
end

if isstring(in)
    in = cellstr(in);
elseif ischar(in)
    in = {in};
elseif ~iscell(in)
    error('CVA_get_subjects:InvalidOverrideType', ...
        'subjectOverride must be char, string, cellstr, or string array.');
end

tmp = cell(1, numel(in));
for i = 1:numel(in)
    sid = strtrim(string(in{i}));
    if sid == ""
        continue;
    end
    if ~startsWith(sid, "sub-")
        sid = "sub-" + sid;
    end
    tmp{i} = char(sid);
end

tmp = tmp(~cellfun(@isempty, tmp));
if isempty(tmp)
    out = {};
else
    out = unique(tmp, 'stable');
end
end
