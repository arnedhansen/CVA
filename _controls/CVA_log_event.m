function CVA_log_event(stage, eventType, payload)
% CVA_LOG_EVENT  Appends a structured event to the CVA JSONL log.
%
%   CVA_log_event(stage, eventType)
%   CVA_log_event(stage, eventType, payloadStruct)
%
% The log file is written to:
%   <data_root>/logs/CVA_pipeline_events.jsonl

if nargin < 3 || isempty(payload)
    payload = struct();
end
if ~isstruct(payload)
    error('CVA_log_event:InvalidPayload', 'payload must be a struct.');
end

[logFile, runID] = resolve_log_target();

event = struct();
event.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS'));
event.run_id = runID;
event.stage = char(string(stage));
event.event_type = char(string(eventType));
event.payload = payload;

line = jsonencode(event);
fid = fopen(logFile, 'a');
if fid < 0
    warning('CVA_log_event:OpenFailed', 'Could not open log file: %s', logFile);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', line);
end

function [logFile, runID] = resolve_log_target()
% Keep one run id per MATLAB session for cross-script traceability.
persistent sessionRunID
if isempty(sessionRunID)
    sessionRunID = char(string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
end
runID = sessionRunID;

logDir = resolve_log_dir();
if ~exist(logDir, 'dir')
    mkdir(logDir);
end
logFile = fullfile(logDir, 'CVA_pipeline_events.jsonl');
end

function logDir = resolve_log_dir()
% Primary location requested for manuscript-ready audit logs.
preferred = '/Volumes/g_psyplafor_methlab$/Students/Arne/CVA/data/logs';
if exist(fileparts(preferred), 'dir')
    logDir = preferred;
    return;
end

% Fallback: stay inside the resolved data root (via functions repo).
logDir = fullfile(get_cva_data_root(), 'logs');
end
