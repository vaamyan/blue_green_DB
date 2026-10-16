-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE POLICY private_notes_owner_policy
    ON private_notes
    USING (owner_name = current_user)
    WITH CHECK (owner_name = current_user);
