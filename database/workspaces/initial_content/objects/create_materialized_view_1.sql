-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE MATERIALIZED VIEW materialized_view_1 AS
    SELECT column_3 AS column_1, count(*) AS column_2
    FROM table_1
    GROUP BY column_3;
