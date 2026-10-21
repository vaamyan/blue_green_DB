-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE FUNCTION function_6()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.column_1 IS NULL THEN
        NEW.column_1 := nextval(format('%I.sequence_4', TG_TABLE_SCHEMA)::regclass);
    END IF;
    RETURN NEW;
END;
$$;
