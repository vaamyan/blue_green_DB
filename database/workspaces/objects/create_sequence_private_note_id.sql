-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE SEQUENCE private_note_id_seq START WITH 1;
