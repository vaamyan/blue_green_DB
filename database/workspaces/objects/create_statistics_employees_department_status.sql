-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE STATISTICS employees_department_status_stats (dependencies, mcv)
    ON department, status FROM employees;
