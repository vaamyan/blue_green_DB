-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TRIGGER employees_touch_updated_at
BEFORE UPDATE ON employees
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
