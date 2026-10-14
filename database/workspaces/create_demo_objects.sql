-- Run as the owner of the target workspace database.
-- Supply -v workspace=workspace1 or -v workspace=workspace2 to psql.
SET search_path TO :"workspace", pg_catalog;

-- User-defined types
CREATE TYPE demo_employee_status AS ENUM ('active', 'inactive', 'leave');
CREATE DOMAIN demo_positive_integer AS integer CHECK (VALUE > 0);
CREATE TYPE demo_employee_key AS (employee_id bigint, display_name text);
CREATE TYPE demo_integer_range AS RANGE (SUBTYPE = integer);

-- Sequence, ordinary table, constraints, and indexes
CREATE SEQUENCE demo_employee_id_seq START WITH 1000;

CREATE TABLE demo_employees (
    employee_id bigint PRIMARY KEY DEFAULT nextval('demo_employee_id_seq'),
    display_name text NOT NULL,
    department text NOT NULL,
    status demo_employee_status NOT NULL DEFAULT 'active',
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT demo_display_name_not_blank CHECK (btrim(display_name) <> '')
);

ALTER SEQUENCE demo_employee_id_seq OWNED BY demo_employees.employee_id;
CREATE INDEX demo_employees_department_idx ON demo_employees (department);
CREATE INDEX demo_employees_active_department_idx
    ON demo_employees (active, department);

-- Partitioned table and a concrete partition
CREATE TABLE demo_audit_log (
    event_id bigint GENERATED ALWAYS AS IDENTITY,
    occurred_at timestamptz NOT NULL,
    event_name text NOT NULL,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY (event_id, occurred_at)
) PARTITION BY RANGE (occurred_at);

CREATE TABLE demo_audit_log_2020_2030
    PARTITION OF demo_audit_log
    FOR VALUES FROM ('2020-01-01 00:00:00+00') TO ('2030-01-01 00:00:00+00');

-- View and materialized view
CREATE VIEW demo_active_employees AS
    SELECT employee_id, display_name, department
    FROM demo_employees
    WHERE active;

CREATE MATERIALIZED VIEW demo_department_summary AS
    SELECT department, count(*) AS employee_count
    FROM demo_employees
    GROUP BY department;

-- Functions, a procedure, and a trigger
CREATE FUNCTION demo_employee_label(p_employee_id bigint)
RETURNS text
LANGUAGE sql
STABLE
AS $$
    SELECT display_name
    FROM demo_employees
    WHERE employee_id = p_employee_id
$$;

CREATE FUNCTION demo_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := clock_timestamp();
    RETURN NEW;
END;
$$;

CREATE TRIGGER demo_employees_touch_updated_at
BEFORE UPDATE ON demo_employees
FOR EACH ROW
EXECUTE FUNCTION demo_touch_updated_at();

CREATE PROCEDURE demo_set_employee_active(p_employee_id bigint, p_active boolean)
LANGUAGE sql
AS $$
    UPDATE demo_employees
    SET active = p_active
    WHERE employee_id = p_employee_id
$$;

-- Row-level security policy (table owners normally bypass RLS)
CREATE TABLE demo_private_notes (
    note_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_name name NOT NULL DEFAULT current_user,
    note_text text NOT NULL
);

ALTER TABLE demo_private_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY demo_private_notes_owner_policy
    ON demo_private_notes
    USING (owner_name = current_user)
    WITH CHECK (owner_name = current_user);

-- A rewrite rule on a grouped, non-updatable view
CREATE VIEW demo_department_employee_counts AS
    SELECT department, count(*) AS employee_count
    FROM demo_employees
    GROUP BY department;

CREATE RULE demo_department_counts_insert AS
    ON INSERT TO demo_department_employee_counts
    DO INSTEAD
    INSERT INTO demo_employees (display_name, department)
    VALUES ('Inserted through view rule', NEW.department);

-- User-defined aggregate and operator
CREATE FUNCTION demo_sum_state(bigint, bigint)
RETURNS bigint
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS 'SELECT $1 + $2';

CREATE AGGREGATE demo_sum(bigint) (
    SFUNC = demo_sum_state,
    STYPE = bigint,
    INITCOND = '0'
);

CREATE OPERATOR === (
    LEFTARG = integer,
    RIGHTARG = integer,
    FUNCTION = pg_catalog.int4eq
);

-- Text-search objects and extended statistics
CREATE TEXT SEARCH DICTIONARY demo_simple_dictionary (
    TEMPLATE = pg_catalog.simple
);

CREATE TEXT SEARCH CONFIGURATION demo_simple_search (
    PARSER = pg_catalog.default
);

ALTER TEXT SEARCH CONFIGURATION demo_simple_search
    ADD MAPPING FOR asciiword WITH demo_simple_dictionary;

CREATE STATISTICS demo_employees_department_status_stats (dependencies, mcv)
    ON department, status
    FROM demo_employees;

-- Database-level logical replication object; replication itself also
-- requires wal_level = logical and subscriber configuration.
CREATE PUBLICATION demo_employee_publication FOR TABLE demo_employees;

ANALYZE demo_employees;
