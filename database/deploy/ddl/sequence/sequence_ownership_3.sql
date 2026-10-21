-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER SEQUENCE sequence_3 OWNED BY table_3.column_1;
