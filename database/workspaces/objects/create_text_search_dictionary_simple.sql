-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TEXT SEARCH DICTIONARY simple_dictionary (
    TEMPLATE = pg_catalog.simple
);
