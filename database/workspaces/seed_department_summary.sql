-- Refresh the materialized view after employee seed data is loaded.
SET search_path TO :"workspace", pg_catalog;
REFRESH MATERIALIZED VIEW department_summary;
