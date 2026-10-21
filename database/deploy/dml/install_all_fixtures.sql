-- Load fixture data in dependency order.
-- Run with psql --single-transaction and provide the workspace variable.
-- psql -v workspace=WORKSPACE01 -d WORKSPACE01 -f database/deploy/dml/install_all_fixtures.sql

SET ROLE :"workspace";

\ir table_1.sql
\ir table_2.sql
\ir table_3.sql
\ir table_4.sql
\ir materialized_view_1.sql
