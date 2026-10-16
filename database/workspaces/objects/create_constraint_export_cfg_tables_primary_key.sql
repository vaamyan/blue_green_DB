SET search_path TO :"workspace", pg_catalog;
ALTER TABLE export_cfg_tables
    ADD CONSTRAINT export_cfg_tables_pkey PRIMARY KEY (table_name);
