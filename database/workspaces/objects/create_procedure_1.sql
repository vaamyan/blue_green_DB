-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE PROCEDURE procedure_1(parameter_1 bigint, parameter_2 boolean)
LANGUAGE sql AS $$
    UPDATE table_1 SET column_5 = parameter_2 WHERE column_1 = parameter_1
$$;
