-- Seed independent fixture rows in table_3; trigger_3 assigns column_1.
SET search_path TO :"workspace", pg_catalog;

INSERT INTO table_3 (column_2, column_3)
SELECT seed.column_2, seed.column_3
FROM (VALUES
    ('First independent table_3 row'::text, '2026-01-20 10:00:00+00'::timestamptz),
    ('Second independent table_3 row'::text, '2026-02-20 10:00:00+00'::timestamptz)
) AS seed(column_2, column_3)
WHERE NOT EXISTS (
    SELECT 1 FROM table_3 AS existing
    WHERE existing.column_2 = seed.column_2
);

ANALYZE table_3;
