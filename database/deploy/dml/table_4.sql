-- Seed role-scoped fixture rows in table_4; trigger_4 assigns column_1.
SET search_path TO :"workspace", pg_catalog;

INSERT INTO table_4 (column_3)
SELECT seed.column_3
FROM (VALUES
    ('Quarterly planning notes for the engineering team.'::text),
    ('Synthetic note: review the next release checklist.'::text)
) AS seed(column_3)
WHERE NOT EXISTS (
    SELECT 1
    FROM table_4 AS existing
    WHERE existing.column_2 = current_user
      AND existing.column_3 = seed.column_3
);

ANALYZE table_4;
