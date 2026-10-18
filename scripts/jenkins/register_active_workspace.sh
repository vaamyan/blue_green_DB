#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

user_name="${1:-}"
user_id="${2:-}"
[[ "$user_name" =~ ^[A-Za-z0-9._-]+$ && "$user_id" =~ ^[0-9]+$ ]] || {
  printf 'Usage: %s <registered_user_name> <user_id>\n' "$0" >&2
  exit 2
}

registered_id="$(psql -X -w -v ON_ERROR_STOP=1 -Atq \
  -v "requested_user=$user_name" -v "requested_id=$user_id" \
  -f database/jenkins/register_active_user.sql)"
[[ "$registered_id" == "$user_id" ]] || {
  printf 'Workspace was not registered in ACTIVE_USERS; check for registry changes.\n' >&2
  exit 1
}
