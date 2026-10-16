-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE FUNCTION function_1(parameter_1 bigint)
RETURNS text LANGUAGE sql STABLE AS $$
    SELECT column_2 FROM table_1 WHERE column_1 = parameter_1
$$;
