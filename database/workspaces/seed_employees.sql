-- Seed synthetic employees and align the employee ID sequence.
-- Supply -v workspace=workspace1 or -v workspace=workspace2 to psql.
SET search_path TO :"workspace", pg_catalog;

INSERT INTO employees
    (employee_id, display_name, department, status, active, created_at, updated_at)
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
ON CONFLICT (employee_id) DO NOTHING;

SELECT setval(
    'employee_id_seq'::regclass,
    GREATEST(
        (SELECT last_value FROM employee_id_seq),
        COALESCE((SELECT max(employee_id) FROM employees), 1000)
    ),
    true
);

ANALYZE employees;
