-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER TABLE private_notes ADD CONSTRAINT private_notes_pkey PRIMARY KEY (note_id);
