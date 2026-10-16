SET search_path TO :"workspace", pg_catalog;
ALTER TABLE export_cfg_tables
    ADD CONSTRAINT export_cfg_tables_copy_mode_check
    CHECK (copy_mode IN ('CONFIG', 'BLUEGREEN_SOURCE', 'NONE'));
