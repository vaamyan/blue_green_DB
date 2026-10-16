-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER SEQUENCE private_note_id_seq OWNED BY private_notes.note_id;
