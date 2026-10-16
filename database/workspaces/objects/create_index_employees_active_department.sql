-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE INDEX employees_active_department_idx ON employees (active, department);
