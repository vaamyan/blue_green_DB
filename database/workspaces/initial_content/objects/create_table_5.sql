-- Per-table policy for a future Blue-Green schema/data export process.
SET search_path TO :"workspace", pg_catalog;

CREATE TABLE table_5 (
    column_1 name NOT NULL,
    column_2 integer NOT NULL,
    column_3 text NOT NULL,
    column_4 name,
    column_5 name[] NOT NULL DEFAULT ARRAY[]::name[],
    column_6 name[] NOT NULL DEFAULT ARRAY[]::name[],
    column_7 boolean NOT NULL DEFAULT true,
    column_8 text
);
