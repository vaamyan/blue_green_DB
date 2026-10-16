-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE OPERATOR === (
    LEFTARG = integer,
    RIGHTARG = integer,
    FUNCTION = pg_catalog.int4eq
);
