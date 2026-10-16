-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE AGGREGATE aggregate_1(bigint) (
    SFUNC = function_3,
    STYPE = bigint,
    INITCOND = '0'
);
