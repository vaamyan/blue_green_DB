-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TEXT SEARCH CONFIGURATION simple_search (
    PARSER = pg_catalog.default
);
