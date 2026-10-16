-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TRIGGER trigger_1
BEFORE UPDATE ON table_1
FOR EACH ROW EXECUTE FUNCTION function_2();
