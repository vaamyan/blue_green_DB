-- Seed synthetic audit events; the partitioned table routes them to a partition.
SET search_path TO :"workspace", pg_catalog;

INSERT INTO audit_log (occurred_at, event_name, details)
SELECT seed.occurred_at, seed.event_name, seed.details
FROM (VALUES
    ('2026-01-12 09:05:00+00'::timestamptz, 'employee.created'::text,
     '{"employee_id":1001,"department":"Engineering"}'::jsonb),
    ('2026-01-15 09:10:00+00'::timestamptz, 'employee.created'::text,
     '{"employee_id":1002,"department":"Operations"}'::jsonb),
    ('2026-02-18 10:30:00+00'::timestamptz, 'employee.deactivated'::text,
     '{"employee_id":1004}'::jsonb)
) AS seed(occurred_at, event_name, details)
WHERE NOT EXISTS (
    SELECT 1
    FROM audit_log AS existing
    WHERE existing.occurred_at = seed.occurred_at
      AND existing.event_name = seed.event_name
);

ANALYZE audit_log;
