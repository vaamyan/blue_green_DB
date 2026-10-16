#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

workspace="${1:-}"
case "$workspace" in
  workspace1|workspace2) ;;
  *) printf 'Usage: %s workspace1|workspace2\n' "$0" >&2; exit 2 ;;
esac

command -v docker >/dev/null 2>&1 || { printf 'Error: Docker is not installed or is not on PATH.\n' >&2; exit 1; }

sentinels="$(docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U "$workspace" -d "$workspace" -Atqc \
  "SELECT (CASE WHEN to_regclass('table_1') IS NOT NULL THEN '1' ELSE '0' END) || (CASE WHEN to_regclass('table_5') IS NOT NULL THEN '1' ELSE '0' END);")"
if [[ "$sentinels" == 11 ]]; then
  printf '%s workspace objects already exist; skipping.\n' "$workspace"
  exit 0
elif [[ "$sentinels" != 00 ]]; then
  printf 'Error: %s has a partial object setup (table_1/table_5). Review it manually.\n' "$workspace" >&2
  exit 1
fi

# This manifest records DDL dependencies. table_5.column_2 stores data-copy order.
files=(
  create_type_1.sql
  create_domain_1.sql
  create_type_2.sql
  create_type_3.sql
  create_sequence_1.sql
  create_sequence_2.sql
  create_sequence_3.sql
  create_table_1.sql
  create_table_2.sql
  create_table_4.sql
  create_constraint_1.sql
  create_constraint_2.sql
  create_constraint_3.sql
  create_constraint_4.sql
  create_sequence_ownership_1.sql
  create_sequence_ownership_2.sql
  create_sequence_ownership_3.sql
  create_table_3.sql
  create_table_5.sql
  create_constraint_5.sql
  create_constraint_6.sql
  create_constraint_7.sql
  create_constraint_8.sql
  create_function_1.sql
  create_function_2.sql
  create_function_3.sql
  create_trigger_1.sql
  create_procedure_1.sql
  create_row_level_security_1.sql
  create_policy_1.sql
  create_index_1.sql
  create_index_2.sql
  create_view_1.sql
  create_materialized_view_1.sql
  create_view_2.sql
  create_rule_1.sql
  create_aggregate_1.sql
  create_operator_1.sql
  create_text_search_dictionary_1.sql
  create_text_search_configuration_1.sql
  create_text_search_mapping_1.sql
  create_statistics_1.sql
  create_publication_1.sql
)

for file in "${files[@]}"; do
  [[ -f "database/workspaces/objects/$file" ]] || {
    printf 'Error: missing DDL file: %s\n' "$file" >&2
    exit 1
  }
done

printf 'Creating workspace objects in %s...\n' "$workspace"
for file in "${files[@]}"; do
  docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 --single-transaction \
    -U "$workspace" -d "$workspace" -v "workspace=$workspace" -f /dev/stdin \
    < "database/workspaces/objects/$file"
done
