-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER SEQUENCE sequence_4 OWNED BY table_4.column_1;
