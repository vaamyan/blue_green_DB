-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE DOMAIN domain_1 AS integer CHECK (VALUE > 0);
