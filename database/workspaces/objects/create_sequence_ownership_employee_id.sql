-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER SEQUENCE employee_id_seq OWNED BY employees.employee_id;
