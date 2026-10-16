-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TEXT SEARCH DICTIONARY text_search_dictionary_1 (
    TEMPLATE = pg_catalog.simple
);
