-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TYPE employee_key AS (employee_id bigint, display_name text);
