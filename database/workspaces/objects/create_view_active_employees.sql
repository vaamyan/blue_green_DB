-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE VIEW active_employees AS
    SELECT employee_id, display_name, department
    FROM employees
    WHERE active;
