-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TABLE employees (
    employee_id bigint NOT NULL DEFAULT nextval('employee_id_seq'),
    display_name text NOT NULL,
    department text NOT NULL,
    status employee_status NOT NULL DEFAULT 'active',
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp
);
