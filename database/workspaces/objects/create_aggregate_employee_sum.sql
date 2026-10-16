-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE AGGREGATE employee_sum(bigint) (
    SFUNC = employee_sum_state,
    STYPE = bigint,
    INITCOND = '0'
);
