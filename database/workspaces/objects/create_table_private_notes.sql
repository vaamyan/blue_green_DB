-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TABLE private_notes (
    note_id bigint NOT NULL DEFAULT nextval('private_note_id_seq'),
    owner_name name NOT NULL DEFAULT current_user,
    note_text text NOT NULL
);
