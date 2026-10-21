-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TABLE table_4 (
    column_1 bigint NOT NULL,
    column_2 name NOT NULL DEFAULT current_user,
    column_3 text NOT NULL
);
