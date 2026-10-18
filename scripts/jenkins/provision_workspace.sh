#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

workspace="${1:-}"
[[ "$workspace" =~ ^[A-Za-z0-9._-]{1,63}$ ]] || {
  printf 'Usage: %s <workspace_name> (1-63 letters, digits, dots, underscores, or hyphens)\n' "$0" >&2
  exit 2
}

psql -X -w -v ON_ERROR_STOP=1 -d postgres \
  -v "workspace=$workspace" -f database/jenkins/create_workspace_role.sql
psql -X -w -v ON_ERROR_STOP=1 -d postgres \
  -v "workspace=$workspace" -f database/jenkins/create_workspace_database.sql
psql -X -w -v ON_ERROR_STOP=1 -d "$workspace" \
  -v "workspace=$workspace" -f database/jenkins/create_workspace_schema.sql
