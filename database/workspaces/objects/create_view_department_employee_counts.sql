-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE VIEW department_employee_counts AS
    SELECT department, count(*) AS employee_count
    FROM employees
    GROUP BY department;
