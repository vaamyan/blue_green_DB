-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER SEQUENCE audit_event_id_seq OWNED BY audit_log.event_id;
