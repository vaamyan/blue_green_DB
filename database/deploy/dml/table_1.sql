-- Seed synthetic rows in table_1 and align sequence_1.
-- Supply -v workspace=workspace1 or -v workspace=workspace2 to psql.
SET search_path TO :"workspace", pg_catalog;

INSERT INTO table_1
    (column_1, column_2, column_3, column_4, column_5, column_6, column_7)
VALUES
    (1001, 'Avery Morgan', 'Engineering', 'active', true,
     '2026-01-12 09:00:00+00', '2026-01-12 09:00:00+00'),
    (1002, 'Jordan Lee', 'Operations', 'active', true,
     '2026-01-15 09:00:00+00', '2026-01-15 09:00:00+00'),
    (1003, 'Riley Patel', 'Research', 'leave', true,
     '2026-02-03 09:00:00+00', '2026-02-03 09:00:00+00'),
    (1004, 'Morgan Reyes', 'Engineering', 'inactive', false,
     '2026-02-18 09:00:00+00', '2026-02-18 09:00:00+00'),
    (1005, 'Taylor Kim', 'Sales', 'active', true,
     '2026-03-02 09:00:00+00', '2026-03-02 09:00:00+00')
ON CONFLICT (column_1) DO NOTHING;

SELECT setval(
    'sequence_1'::regclass,
    GREATEST(
        (SELECT last_value FROM sequence_1),
        COALESCE((SELECT max(column_1) FROM table_1), 1000)
    ),
    true
);

ANALYZE table_1;
