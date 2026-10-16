-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE FUNCTION function_2()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.column_7 := clock_timestamp();
    RETURN NEW;
END;
$$;
