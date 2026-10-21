#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

user_name="${1:-}"
workspace="${2:-}"
[[ -n "$user_name" ]] || die "Usage: $0 <registered_user_name> workspace_<number>"
[[ "$workspace" =~ ^workspace_[0-9]+$ ]] || die "Workspace must match workspace_<number>."
command -v docker >/dev/null 2>&1 || die "Docker is not installed or is not on PATH."

admin_psql() {
  docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U bluegreen "$@"
}

authorized="$(admin_psql -d bluegreen -v "requested_user=$user_name" -Atqc \
  "SELECT EXISTS (SELECT 1 FROM bluegreen_users WHERE user_name = :'requested_user');")"
[[ "$authorized" == t ]] || die "User '$user_name' is not registered in bluegreen_users."
already_active="$(admin_psql -d bluegreen -v "requested_user=$user_name" -Atqc \
  "SELECT EXISTS (SELECT 1 FROM active_users WHERE user_name = :'requested_user');")"
[[ "$already_active" == f ]] || die "User '$user_name' already has an active workspace."

role_exists="$(admin_psql -d postgres -v "workspace=$workspace" -Atqc \
  "SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'workspace');")"
database_exists="$(admin_psql -d postgres -v "workspace=$workspace" -Atqc \
  "SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'workspace');")"
[[ "$role_exists" == f && "$database_exists" == f ]] || \
  die "Workspace '$workspace' already exists or is partially created; inspect its role and database before retrying."

printf 'Creating workspace role and database for registered user %s...\n' "$user_name"
admin_psql -d postgres -c "CREATE ROLE \"$workspace\" LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;"
admin_psql -d postgres -c "CREATE DATABASE \"$workspace\" OWNER \"$workspace\";"
admin_psql -d postgres -c "REVOKE CONNECT ON DATABASE postgres FROM \"$workspace\";"
admin_psql -d postgres -c "REVOKE CONNECT ON DATABASE template1 FROM \"$workspace\";"
admin_psql -d postgres -c "REVOKE CONNECT ON DATABASE bluegreen FROM \"$workspace\";"
admin_psql -d postgres -c "REVOKE CONNECT ON DATABASE \"$workspace\" FROM PUBLIC;"
admin_psql -d postgres -c "GRANT CONNECT ON DATABASE \"$workspace\" TO \"$workspace\";"
admin_psql -d "$workspace" -c "CREATE SCHEMA \"$workspace\" AUTHORIZATION \"$workspace\";"
admin_psql -d "$workspace" -c "REVOKE ALL ON SCHEMA public FROM PUBLIC;"

printf 'Deploying DDL to %s...\n' "$workspace"
./create_initial_content.sh "$workspace"

dml_files=(
  table_1.sql
  table_2.sql
  table_3.sql
  table_4.sql
  materialized_view_1.sql
)
for file in "${dml_files[@]}"; do
  [[ -f "database/deploy/dml/$file" ]] || die "Missing DML file: database/deploy/dml/$file"
done
for file in "${dml_files[@]}"; do
  printf 'Applying %s to %s...\n' "$file" "$workspace"
  admin_psql -d "$workspace" -v "workspace=$workspace" \
    -c "SET ROLE \"$workspace\"" -f /dev/stdin \
    < "database/deploy/dml/$file"
done

admin_psql -d bluegreen -v "requested_user=$user_name" -c \
  "INSERT INTO active_users (user_id, user_name) SELECT user_id, user_name FROM bluegreen_users WHERE user_name = :'requested_user';"

printf 'Workspace %s created and populated from database/deploy/.\n' "$workspace"
