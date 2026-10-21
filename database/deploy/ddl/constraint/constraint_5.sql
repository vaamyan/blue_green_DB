-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER TABLE table_3 ADD CONSTRAINT constraint_5 PRIMARY KEY (column_1);
