-- Seed per-table export policy. The exporter will provide the source schema at runtime.
SET search_path TO :"workspace", pg_catalog;

INSERT INTO export_cfg_tables
    (table_name, export_order, copy_mode, source_schema, trigger_names, sequence_names, notes)
VALUES
    ('export_cfg_tables', 10, 'CONFIG', NULL, ARRAY[]::name[], ARRAY[]::name[],
     'Copy configuration before applying table-specific export policy.'),
    ('employees', 20, 'BLUEGREEN_SOURCE', NULL,
     ARRAY['employees_touch_updated_at']::name[], ARRAY['employee_id_seq']::name[],
     'Copy data from the source schema selected by Blue-Green.'),
    ('audit_log', 30, 'BLUEGREEN_SOURCE', NULL,
     ARRAY[]::name[], ARRAY['audit_event_id_seq']::name[],
     'Partitioned table; preserve occurred_at values for partition routing.'),
    ('private_notes', 40, 'BLUEGREEN_SOURCE', NULL,
     ARRAY[]::name[], ARRAY['private_note_id_seq']::name[],
     'Copy data from the source schema selected by Blue-Green.')
ON CONFLICT (table_name) DO UPDATE SET
    export_order = EXCLUDED.export_order,
    copy_mode = EXCLUDED.copy_mode,
    source_schema = EXCLUDED.source_schema,
    trigger_names = EXCLUDED.trigger_names,
    sequence_names = EXCLUDED.sequence_names,
    notes = EXCLUDED.notes;

ANALYZE export_cfg_tables;
