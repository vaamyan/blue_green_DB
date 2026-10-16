-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE RULE rule_1 AS
    ON INSERT TO view_2
    DO INSTEAD
    INSERT INTO table_1 (column_2, column_3)
    VALUES ('Inserted through view rule', NEW.column_1);
