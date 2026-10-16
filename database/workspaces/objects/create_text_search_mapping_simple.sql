-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

ALTER TEXT SEARCH CONFIGURATION simple_search
    ADD MAPPING FOR asciiword WITH simple_dictionary;
