-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE PROCEDURE set_employee_active(p_employee_id bigint, p_active boolean)
LANGUAGE sql AS $$
    UPDATE employees SET active = p_active WHERE employee_id = p_employee_id
$$;
