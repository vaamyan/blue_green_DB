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
  "SELECT (CASE WHEN to_regclass('table_1') IS NOT NULL THEN '1' ELSE '0' END) || (CASE WHEN to_regclass('table_2') IS NOT NULL THEN '1' ELSE '0' END) || (CASE WHEN to_regclass('table_3') IS NOT NULL THEN '1' ELSE '0' END) || (CASE WHEN to_regclass('table_4') IS NOT NULL THEN '1' ELSE '0' END) || (CASE WHEN to_regclass('table_5') IS NOT NULL THEN '1' ELSE '0' END);")"
if [[ "$sentinels" == 11111 ]]; then
  printf '%s initial tables already exist; skipping DDL.\n' "$workspace"
elif [[ "$sentinels" == 11011 ]]; then
  printf 'Recreating missing partition table_3 in %s...\n' "$workspace"
  docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 --single-transaction \
    -U "$workspace" -d "$workspace" -v "workspace=$workspace" -f /dev/stdin \
    < database/deploy/ddl/table/table_3.sql
elif [[ "$sentinels" == 00000 ]]; then
  # This manifest records DDL dependencies; table_5.column_2 stores data-copy order.
  files=(
    type/type_1.sql
    domain/domain_1.sql
    type/type_2.sql
    type/type_3.sql
    sequence/sequence_1.sql
    sequence/sequence_2.sql
    sequence/sequence_3.sql
    table/table_1.sql
    table/table_2.sql
    table/table_4.sql
    constraint/constraint_1.sql
    constraint/constraint_2.sql
    constraint/constraint_3.sql
    constraint/constraint_4.sql
    sequence/sequence_ownership_1.sql
    sequence/sequence_ownership_2.sql
    sequence/sequence_ownership_3.sql
    table/table_3.sql
    table/table_5.sql
    constraint/constraint_5.sql
    constraint/constraint_6.sql
    constraint/constraint_7.sql
    constraint/constraint_8.sql
    function/function_1.sql
    function/function_2.sql
    function/function_3.sql
    trigger/trigger_1.sql
    procedure/procedure_1.sql
    security/row_level_security_1.sql
    policy/policy_1.sql
    index/index_1.sql
    index/index_2.sql
    view/view_1.sql
    materialized_view/materialized_view_1.sql
    view/view_2.sql
    rule/rule_1.sql
    aggregate/aggregate_1.sql
    operator/operator_1.sql
    text_search/text_search_dictionary_1.sql
    text_search/text_search_configuration_1.sql
    text_search/text_search_mapping_1.sql
    statistics/statistics_1.sql
    publication/publication_1.sql
  )

  for file in "${files[@]}"; do
    [[ -f "database/deploy/ddl/$file" ]] || {
      printf 'Error: missing DDL file: %s\n' "$file" >&2
      exit 1
    }
  done

  printf 'Creating initial database content in %s...\n' "$workspace"
  for file in "${files[@]}"; do
    docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 --single-transaction \
      -U "$workspace" -d "$workspace" -v "workspace=$workspace" -f /dev/stdin \
      < "database/deploy/ddl/$file"
  done
else
  printf 'Error: %s has a partial initial table setup (table_1 through table_5: %s). Review it manually.\n' "$workspace" "$sentinels" >&2
  exit 1
fi
