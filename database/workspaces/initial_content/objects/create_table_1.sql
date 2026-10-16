-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TABLE table_1 (
    column_1 bigint NOT NULL DEFAULT nextval('sequence_1'),
    column_2 text NOT NULL,
    column_3 text NOT NULL,
    column_4 type_1 NOT NULL DEFAULT 'active',
    column_5 boolean NOT NULL DEFAULT true,
    column_6 timestamptz NOT NULL DEFAULT current_timestamp,
    column_7 timestamptz NOT NULL DEFAULT current_timestamp
);
