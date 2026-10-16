-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER TABLE table_1 ADD CONSTRAINT constraint_1 PRIMARY KEY (column_1);
