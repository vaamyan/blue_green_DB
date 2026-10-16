-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TYPE type_1 AS ENUM ('active', 'inactive', 'leave');
