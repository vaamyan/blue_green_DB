-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE VIEW view_1 AS
    SELECT column_1, column_2, column_3
    FROM table_1
    WHERE column_5;
