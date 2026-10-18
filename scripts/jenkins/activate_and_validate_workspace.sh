#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

workspace="${1:-}"
[[ "$workspace" =~ ^workspace_[0-9]+$ ]] || {
  printf 'Usage: %s workspace_<number>\n' "$0" >&2
  exit 2
}

psql -X -w -v ON_ERROR_STOP=1 -d "$workspace" \
  -v "workspace=$workspace" \
  -c "SET ROLE $workspace" \
  -f database/jenkins/enable_runtime_objects.sql \
  -f database/jenkins/validate_workspace.sql
