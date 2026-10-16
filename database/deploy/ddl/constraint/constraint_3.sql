-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER TABLE table_2 ADD CONSTRAINT constraint_3 PRIMARY KEY (column_1, column_2);
