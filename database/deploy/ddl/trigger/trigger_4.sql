-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TRIGGER trigger_4
BEFORE INSERT ON table_4
FOR EACH ROW EXECUTE FUNCTION function_6();
