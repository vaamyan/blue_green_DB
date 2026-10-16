-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER TABLE audit_log ADD CONSTRAINT audit_log_pkey PRIMARY KEY (event_id, occurred_at);
