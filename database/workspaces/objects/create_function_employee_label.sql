-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE FUNCTION employee_label(p_employee_id bigint)
RETURNS text LANGUAGE sql STABLE AS $$
    SELECT display_name FROM employees WHERE employee_id = p_employee_id
$$;
