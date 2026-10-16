-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE INDEX index_2 ON table_1 (column_5, column_3);
