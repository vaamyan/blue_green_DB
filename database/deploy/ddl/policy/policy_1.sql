-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE POLICY policy_1
    ON table_4
    USING (column_2 = current_user)
    WITH CHECK (column_2 = current_user);
