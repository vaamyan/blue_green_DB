#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

workspace="${1:-}"
[[ "$workspace" =~ ^[A-Za-z0-9._-]{1,63}$ ]] || {
  printf 'Usage: %s <workspace_name> (1-63 letters, digits, dots, underscores, or hyphens)\n' "$0" >&2
  exit 2
}

status="$(psql -X -w -v ON_ERROR_STOP=1 -Atq -d "$workspace" \
  -v "workspace=$workspace" -f database/jenkins/verify_side_effects_disabled.sql)"
[[ "$status" == ok ]] || {
  printf 'The trigger must be disabled before fixture loading. The view rule is deferred until afterward.\n' >&2
  exit 1
}
