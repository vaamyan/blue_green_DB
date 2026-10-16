-- Seed per-table export policy. The exporter will provide the source schema at runtime.
SET search_path TO :"workspace", pg_catalog;

INSERT INTO table_5
    (column_1, column_2, column_3, column_4, column_5, column_6, column_8)
VALUES
    ('table_5', 10, 'CONFIG', NULL, ARRAY[]::name[], ARRAY[]::name[],
     'Copy configuration before applying table-specific export policy.'),
    ('table_1', 20, 'BLUEGREEN_SOURCE', NULL,
     ARRAY['trigger_1']::name[], ARRAY['sequence_1']::name[],
     'Copy data from the source schema selected by Blue-Green.'),
    ('table_2', 30, 'BLUEGREEN_SOURCE', NULL,
     ARRAY[]::name[], ARRAY['sequence_2']::name[],
     'Partitioned table; preserve partition-key values for routing.'),
    ('table_4', 40, 'BLUEGREEN_SOURCE', NULL,
     ARRAY[]::name[], ARRAY['sequence_3']::name[],
     'Copy data from the source schema selected by Blue-Green.')
ON CONFLICT (column_1) DO UPDATE SET
    column_2 = EXCLUDED.column_2,
    column_3 = EXCLUDED.column_3,
    column_4 = EXCLUDED.column_4,
    column_5 = EXCLUDED.column_5,
    column_6 = EXCLUDED.column_6,
    column_8 = EXCLUDED.column_8;

ANALYZE table_5;
