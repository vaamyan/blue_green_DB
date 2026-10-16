-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

-- Logical replication also needs wal_level = logical and a subscriber.
CREATE PUBLICATION publication_1 FOR TABLE table_1;
