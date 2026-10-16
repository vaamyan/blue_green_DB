SET search_path TO :"workspace", pg_catalog;
ALTER TABLE table_5
    ADD CONSTRAINT constraint_7
    CHECK (column_3 IN ('CONFIG', 'BLUEGREEN_SOURCE', 'NONE'));
