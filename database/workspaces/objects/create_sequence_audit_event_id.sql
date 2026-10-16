-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE SEQUENCE audit_event_id_seq START WITH 1;
