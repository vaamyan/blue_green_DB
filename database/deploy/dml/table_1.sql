-- Seed independent fixture rows in table_1; trigger_1 assigns column_1.
SET search_path TO :"workspace", pg_catalog;

INSERT INTO table_1 (column_2, column_3, column_4, column_5, column_6, column_7)
SELECT seed.column_2, seed.column_3, seed.column_4, seed.column_5,
       seed.column_6, seed.column_7
FROM (VALUES
    ('Avery Morgan'::text, 'Engineering'::text, 'active'::type_1, true,
     '2026-01-12 09:00:00+00'::timestamptz, '2026-01-12 09:00:00+00'::timestamptz),
    ('Jordan Lee'::text, 'Operations'::text, 'active'::type_1, true,
     '2026-01-15 09:00:00+00'::timestamptz, '2026-01-15 09:00:00+00'::timestamptz),
    ('Riley Patel'::text, 'Research'::text, 'leave'::type_1, true,
     '2026-02-03 09:00:00+00'::timestamptz, '2026-02-03 09:00:00+00'::timestamptz),
    ('Morgan Reyes'::text, 'Engineering'::text, 'inactive'::type_1, false,
     '2026-02-18 09:00:00+00'::timestamptz, '2026-02-18 09:00:00+00'::timestamptz),
    ('Taylor Kim'::text, 'Sales'::text, 'active'::type_1, true,
     '2026-03-02 09:00:00+00'::timestamptz, '2026-03-02 09:00:00+00'::timestamptz)
) AS seed(column_2, column_3, column_4, column_5, column_6, column_7)
WHERE NOT EXISTS (
    SELECT 1 FROM table_1 AS existing
    WHERE existing.column_2 = seed.column_2
      AND existing.column_3 = seed.column_3
);

ANALYZE table_1;
