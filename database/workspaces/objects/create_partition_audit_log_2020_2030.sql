-- Run as the workspace owner with -v workspace=<workspace_name>.
SET search_path TO :"workspace", pg_catalog;

CREATE TABLE audit_log_2020_2030
    PARTITION OF audit_log
    FOR VALUES FROM ('2020-01-01 00:00:00+00') TO ('2030-01-01 00:00:00+00');
