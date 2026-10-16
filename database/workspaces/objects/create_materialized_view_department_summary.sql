-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE MATERIALIZED VIEW department_summary AS
    SELECT department, count(*) AS employee_count
    FROM employees
    GROUP BY department;
