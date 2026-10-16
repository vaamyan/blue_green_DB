#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || die "Docker is not installed or is not on PATH."
docker compose version >/dev/null 2>&1 || die "Docker Compose is not available."
[[ -f .env ]] || die "Missing .env. Copy .env.example to .env and set strong passwords first."

admin_psql() {
  docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
    -U bluegreen "$@"
}

initial_dml_files=(
  table_5.sql
  table_1.sql
  table_2.sql
  table_4.sql
  materialized_view_1.sql
)

apply_initial_dml() {
  local workspace="$1"
  local file

  for file in "${initial_dml_files[@]}"; do
    [[ -f "database/deploy/dml/$file" ]] || die "Missing DML file: database/deploy/dml/$file"
  done

  for file in "${initial_dml_files[@]}"; do
    printf 'Applying %s to %s...\n' "$file" "$workspace"
    docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 --single-transaction \
      -U "$workspace" -d "$workspace" -v "workspace=$workspace" -f /dev/stdin \
      < "database/deploy/dml/$file"
  done
}

printf 'Starting PostgreSQL and pgAdmin...\n'
docker compose up -d

printf 'Waiting for PostgreSQL to become ready'
ready=false
for _ in {1..60}; do
  if docker compose exec -T postgres pg_isready -U bluegreen -d bluegreen >/dev/null 2>&1; then
    ready=true
    break
  fi
  printf '.'
  sleep 1
done
printf '\n'
[[ "$ready" == true ]] || die "PostgreSQL did not become ready within 60 seconds. Check: docker compose logs postgres"

ensure_workspace() {
  local workspace="$1"
  local role_exists db_exists

  role_exists="$(admin_psql -d postgres -Atqc \
    "SELECT EXISTS (SELECT FROM pg_roles WHERE rolname = '${workspace}');")"
  db_exists="$(admin_psql -d postgres -Atqc \
    "SELECT EXISTS (SELECT FROM pg_database WHERE datname = '${workspace}');")"

  if [[ "$role_exists" == t && "$db_exists" == t ]]; then
    printf '%s role and database already exist; skipping creation.\n' "$workspace"
  elif [[ "$role_exists" == f && "$db_exists" == f ]]; then
    printf 'Creating %s role, database, and schema...\n' "$workspace"
    admin_psql -d postgres -f /dev/stdin \
      < "database/admin/create_${workspace}.sql"
  else
    die "$workspace is only partially created (role exists: $role_exists, database exists: $db_exists). Review it manually before continuing."
  fi
}

ensure_workspace workspace1
ensure_workspace workspace2

password_sql="$(mktemp "${TMPDIR:-/tmp}/bluegreen-role-passwords.XXXXXX")"
chmod 600 "$password_sql"
trap 'rm -f "$password_sql"' EXIT

set_password_if_missing() {
  local workspace="$1"
  local password_missing password confirmation escaped

  password_missing="$(admin_psql -d postgres -Atqc \
    "SELECT rolpassword IS NULL FROM pg_authid WHERE rolname = '${workspace}';")"
  if [[ "$password_missing" == f ]]; then
    printf '%s already has a password; leaving it unchanged.\n' "$workspace"
    return
  fi

  [[ -t 0 ]] || die "A terminal is required to set the password for ${workspace}. Run this script interactively."
  while true; do
    IFS= read -r -s -p "Set a password for ${workspace}: " password
    printf '\n'
    IFS= read -r -s -p "Confirm the password for ${workspace}: " confirmation
    printf '\n'
    [[ -n "$password" ]] || { printf 'Password cannot be empty.\n' >&2; continue; }
    [[ "$password" == "$confirmation" ]] && break
    printf 'Passwords did not match. Try again.\n' >&2
  done

  escaped="${password//\'/\'\'}"
  printf "ALTER ROLE %s PASSWORD '%s';\n" "$workspace" "$escaped" >> "$password_sql"
  unset password confirmation escaped
}

set_password_if_missing workspace1
set_password_if_missing workspace2

if [[ -s "$password_sql" ]]; then
  printf 'Setting passwords for roles that did not have one...\n'
  admin_psql -d postgres -f /dev/stdin < "$password_sql"
fi

for workspace in workspace1 workspace2; do
  printf '\nApplying initial DDL to %s...\n' "$workspace"
  ./create_initial_content.sh "$workspace"
  apply_initial_dml "$workspace"
done

printf '\nWorkspace setup is complete. Current services:\n'
docker compose ps
