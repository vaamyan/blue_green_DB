-- Refresh the materialized view after table_1 seed data is loaded.
SET search_path TO :"workspace", pg_catalog;
REFRESH MATERIALIZED VIEW materialized_view_1;
