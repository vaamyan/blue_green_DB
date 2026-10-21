-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TRIGGER trigger_3
BEFORE INSERT ON table_3
FOR EACH ROW EXECUTE FUNCTION function_5();
