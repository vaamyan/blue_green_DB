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

printf 'Starting the Blue-Green PostgreSQL service...\n'
docker compose up -d postgres

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

printf 'Creating Blue-Green control objects if they do not exist...\n'
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
  -U bluegreen -d bluegreen -f /dev/stdin \
  < database/admin/create_bluegreen_objects.sql

printf '\nBlue-Green database bootstrap is complete. No workspace or workspace data was created.\n'
