-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER TABLE employees ADD CONSTRAINT display_name_not_blank CHECK (btrim(display_name) <> '');
