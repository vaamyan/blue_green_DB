-- Install DDL files in dependency order.
-- Run with psql and provide the workspace variable, for example:
-- psql -v workspace=WORKSPACE01 -d WORKSPACE01 -f database/deploy/ddl/install_all_objects.sql

SET ROLE :"workspace";

\ir type/type_1.sql
\ir domain/domain_1.sql
\ir type/type_2.sql
\ir type/type_3.sql
\ir sequence/sequence_1.sql
\ir sequence/sequence_2.sql
\ir sequence/sequence_3.sql
\ir sequence/sequence_4.sql
\ir table/table_1.sql
\ir table/table_2.sql
\ir table/table_3.sql
\ir table/table_4.sql
\ir constraint/constraint_1.sql
\ir constraint/constraint_2.sql
\ir constraint/constraint_3.sql
\ir constraint/constraint_4.sql
\ir constraint/constraint_5.sql
\ir sequence/sequence_ownership_1.sql
\ir sequence/sequence_ownership_2.sql
\ir sequence/sequence_ownership_3.sql
\ir sequence/sequence_ownership_4.sql
\ir function/function_1.sql
\ir function/function_2.sql
\ir function/function_3.sql
\ir function/function_4.sql
\ir function/function_5.sql
\ir function/function_6.sql
\ir trigger/trigger_1.sql
\ir trigger/trigger_2.sql
\ir trigger/trigger_3.sql
\ir trigger/trigger_4.sql
\ir procedure/procedure_1.sql
\ir security/row_level_security_1.sql
\ir policy/policy_1.sql
\ir index/index_1.sql
\ir index/index_2.sql
\ir view/view_1.sql
\ir materialized_view/materialized_view_1.sql
\ir view/view_2.sql
\ir aggregate/aggregate_1.sql
\ir operator/operator_1.sql
\ir text_search/text_search_dictionary_1.sql
\ir text_search/text_search_configuration_1.sql
\ir text_search/text_search_mapping_1.sql
\ir statistics/statistics_1.sql
\ir publication/publication_1.sql
