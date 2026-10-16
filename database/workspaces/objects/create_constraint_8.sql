SET search_path TO :"workspace", pg_catalog;
ALTER TABLE table_5
    ADD CONSTRAINT constraint_8
    CHECK (column_3 = 'BLUEGREEN_SOURCE' OR column_4 IS NULL);
