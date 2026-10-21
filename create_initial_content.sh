#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

workspace="${1:-}"
[[ "$workspace" =~ ^workspace_[0-9]+$ ]] || {
  printf 'Usage: %s workspace_<number>\n' "$0" >&2
  exit 2
}
command -v docker >/dev/null 2>&1 || die "Docker is not installed or is not on PATH."

sentinels="$(docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
  -U bluegreen -d "$workspace" -v "workspace=$workspace" -Atqc \
  "SELECT (CASE WHEN to_regclass(format('%I.table_1', :'workspace')) IS NOT NULL THEN '1' ELSE '0' END) || (CASE WHEN to_regclass(format('%I.table_2', :'workspace')) IS NOT NULL THEN '1' ELSE '0' END) || (CASE WHEN to_regclass(format('%I.table_3', :'workspace')) IS NOT NULL THEN '1' ELSE '0' END) || (CASE WHEN to_regclass(format('%I.table_4', :'workspace')) IS NOT NULL THEN '1' ELSE '0' END);")"

if [[ "$sentinels" == 1111 ]]; then
  printf '%s initial tables already exist; skipping DDL.\n' "$workspace"
elif [[ "$sentinels" == 0000 ]]; then
  printf 'Applying initial DDL to %s...\n' "$workspace"
  docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
    -U bluegreen -d "$workspace" -v "workspace=$workspace" \
    -f database/deploy/ddl/install_all_objects.sql
else
  die "$workspace has a partial initial DDL setup (table_1 through table_4: $sentinels). Review it manually."
fi
