-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER TEXT SEARCH CONFIGURATION text_search_configuration_1
    ADD MAPPING FOR asciiword WITH text_search_dictionary_1;
