-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TYPE type_2 AS (column_1 bigint, column_2 text);
