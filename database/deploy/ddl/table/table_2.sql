-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TABLE table_2 (
    column_1 bigint NOT NULL DEFAULT nextval('sequence_2'),
    column_2 timestamptz NOT NULL,
    column_3 text NOT NULL,
    column_4 jsonb NOT NULL DEFAULT '{}'::jsonb
) PARTITION BY RANGE (column_2);
