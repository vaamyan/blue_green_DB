-- Per-table policy for a future Blue-Green schema/data export process.
SET search_path TO :"workspace", pg_catalog;

CREATE TABLE export_cfg_tables (
    table_name name NOT NULL,
    export_order integer NOT NULL,
    copy_mode text NOT NULL,
    source_schema name,
    trigger_names name[] NOT NULL DEFAULT ARRAY[]::name[],
    sequence_names name[] NOT NULL DEFAULT ARRAY[]::name[],
    enabled boolean NOT NULL DEFAULT true,
    notes text
);
