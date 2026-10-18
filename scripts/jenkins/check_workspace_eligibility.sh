#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

user_name="${1:-}"
[[ "$user_name" =~ ^[A-Za-z0-9._-]+$ ]] || {
  printf 'Usage: %s <registered_user_name>\n' "$0" >&2
  exit 2
}

user_id="$(psql -X -w -v ON_ERROR_STOP=1 -Atq \
  -v "requested_user=$user_name" \
  -f database/jenkins/select_registered_user.sql)"
[[ "$user_id" =~ ^[0-9]+$ ]] || {
  printf 'User is not registered exactly once in BLUEGREEN_USERS: %s\n' "$user_name" >&2
  exit 1
}

active="$(psql -X -w -v ON_ERROR_STOP=1 -Atq \
  -v "requested_user=$user_name" -v "requested_id=$user_id" \
  -f database/jenkins/check_active_user.sql)"
[[ "$active" == 0 ]] || {
  printf 'User already has an active workspace: %s\n' "$user_name" >&2
  exit 1
}

workspace="workspace_${user_id}"
object_status="$(psql -X -w -v ON_ERROR_STOP=1 -Atq -d postgres \
  -v "workspace=$workspace" \
  -f database/jenkins/check_workspace_objects.sql)"
[[ "$object_status" == '0|0' ]] || {
  printf 'Workspace role/database already exists or is partially provisioned: %s\n' "$workspace" >&2
  exit 1
}

printf '%s\n' "$user_id"
