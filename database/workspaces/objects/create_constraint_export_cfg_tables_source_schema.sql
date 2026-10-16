SET search_path TO :"workspace", pg_catalog;
ALTER TABLE export_cfg_tables
    ADD CONSTRAINT export_cfg_tables_source_schema_check
    CHECK (copy_mode = 'BLUEGREEN_SOURCE' OR source_schema IS NULL);
