-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE STATISTICS statistics_1 (dependencies, mcv)
    ON column_3, column_4 FROM table_1;
