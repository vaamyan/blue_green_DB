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
  "SELECT (CASE WHEN to_regclass('employees') IS NOT NULL THEN '1' ELSE '0' END) || (CASE WHEN to_regclass('export_cfg_tables') IS NOT NULL THEN '1' ELSE '0' END);")"
if [[ "$sentinels" == 11 ]]; then
  printf '%s workspace objects already exist; skipping.\n' "$workspace"
  exit 0
elif [[ "$sentinels" != 00 ]]; then
  printf 'Error: %s has a partial object setup (employees/export_cfg_tables). Review it manually.\n' "$workspace" >&2
  exit 1
fi

# This manifest records DDL dependencies. EXPORT_CFG_TABLES records runtime data-copy order.
files=(
  create_type_employee_status.sql
  create_domain_positive_integer.sql
  create_type_employee_key.sql
  create_type_integer_range.sql
  create_sequence_employee_id.sql
  create_sequence_audit_event_id.sql
  create_sequence_private_note_id.sql
  create_table_employees.sql
  create_table_audit_log.sql
  create_table_private_notes.sql
  create_table_export_cfg_tables.sql
  create_constraint_employees_primary_key.sql
  create_constraint_employees_name_check.sql
  create_constraint_audit_log_primary_key.sql
  create_constraint_private_notes_primary_key.sql
  create_constraint_export_cfg_tables_primary_key.sql
  create_constraint_export_cfg_tables_order_unique.sql
  create_constraint_export_cfg_tables_copy_mode.sql
  create_constraint_export_cfg_tables_source_schema.sql
  create_sequence_ownership_employee_id.sql
  create_sequence_ownership_audit_event_id.sql
  create_sequence_ownership_private_note_id.sql
  create_partition_audit_log_2020_2030.sql
  create_function_employee_label.sql
  create_function_touch_updated_at.sql
  create_function_employee_sum_state.sql
  create_trigger_employees_touch_updated_at.sql
  create_procedure_set_employee_active.sql
  create_policy_private_notes_rls.sql
  create_policy_private_notes_owner.sql
  create_view_active_employees.sql
  create_materialized_view_department_summary.sql
  create_view_department_employee_counts.sql
  create_rule_department_counts_insert.sql
  create_aggregate_employee_sum.sql
  create_operator_integer_equality.sql
  create_text_search_dictionary_simple.sql
  create_text_search_configuration_simple.sql
  create_text_search_mapping_simple.sql
  create_statistics_employees_department_status.sql
  create_publication_employee.sql
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
