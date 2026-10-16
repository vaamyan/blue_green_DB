-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TYPE type_3 AS RANGE (SUBTYPE = integer);
