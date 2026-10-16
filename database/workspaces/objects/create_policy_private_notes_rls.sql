-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER TABLE private_notes ENABLE ROW LEVEL SECURITY;
