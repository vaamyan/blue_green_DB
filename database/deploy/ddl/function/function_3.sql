-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE FUNCTION function_3(bigint, bigint)
RETURNS bigint LANGUAGE sql IMMUTABLE PARALLEL SAFE AS 'SELECT $1 + $2';
