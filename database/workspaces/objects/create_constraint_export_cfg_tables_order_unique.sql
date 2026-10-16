SET search_path TO :"workspace", pg_catalog;
ALTER TABLE export_cfg_tables
    ADD CONSTRAINT export_cfg_tables_export_order_key UNIQUE (export_order);
