-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TYPE employee_status AS ENUM ('active', 'inactive', 'leave');
