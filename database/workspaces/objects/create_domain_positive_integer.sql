-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE DOMAIN positive_integer AS integer CHECK (VALUE > 0);
