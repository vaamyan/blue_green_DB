-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TEXT SEARCH CONFIGURATION text_search_configuration_1 (
    PARSER = pg_catalog.default
);
