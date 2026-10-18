#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

workspace="${1:-}"
[[ "$workspace" =~ ^workspace_[0-9]+$ ]] || {
  printf 'Usage: %s workspace_<number>\n' "$0" >&2
  exit 2
}

status="$(psql -X -w -v ON_ERROR_STOP=1 -Atq -d "$workspace" \
  -v "workspace=$workspace" -f database/jenkins/verify_side_effects_disabled.sql)"
[[ "$status" == ok ]] || {
  printf 'The trigger and rule must both be disabled before fixture loading.\n' >&2
  exit 1
}
