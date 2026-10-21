-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TABLE table_3 (
    column_1 bigint NOT NULL,
    column_2 text NOT NULL,
    column_3 timestamptz NOT NULL DEFAULT current_timestamp
);
