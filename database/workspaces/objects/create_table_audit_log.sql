-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TABLE audit_log (
    event_id bigint NOT NULL DEFAULT nextval('audit_event_id_seq'),
    occurred_at timestamptz NOT NULL,
    event_name text NOT NULL,
    details jsonb NOT NULL DEFAULT '{}'::jsonb
) PARTITION BY RANGE (occurred_at);
