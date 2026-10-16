-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TYPE integer_range AS RANGE (SUBTYPE = integer);
