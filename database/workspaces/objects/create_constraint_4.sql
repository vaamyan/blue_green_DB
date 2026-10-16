-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER TABLE table_4 ADD CONSTRAINT constraint_4 PRIMARY KEY (column_1);
