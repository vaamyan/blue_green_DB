-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE RULE department_counts_insert AS
    ON INSERT TO department_employee_counts
    DO INSTEAD
    INSERT INTO employees (display_name, department)
    VALUES ('Inserted through view rule', NEW.department);
