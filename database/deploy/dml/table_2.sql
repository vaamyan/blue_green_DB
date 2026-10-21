-- Seed independent event rows in table_2; trigger_2 assigns column_1.
SET search_path TO :"workspace", pg_catalog;

INSERT INTO table_2 (column_2, column_3, column_4)
SELECT seed.column_2, seed.column_3, seed.column_4
FROM (VALUES
    ('2026-01-12 09:05:00+00'::timestamptz, 'event_1'::text,
     '{"detail":"first independent event"}'::jsonb),
    ('2026-01-15 09:10:00+00'::timestamptz, 'event_1'::text,
     '{"detail":"second independent event"}'::jsonb),
    ('2026-02-18 10:30:00+00'::timestamptz, 'event_2'::text,
     '{"detail":"third independent event"}'::jsonb)
) AS seed(column_2, column_3, column_4)
WHERE NOT EXISTS (
    SELECT 1 FROM table_2 AS existing
    WHERE existing.column_2 = seed.column_2
      AND existing.column_3 = seed.column_3
);

ANALYZE table_2;
