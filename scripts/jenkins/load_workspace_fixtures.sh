#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

workspace="${1:-}"
[[ "$workspace" =~ ^workspace_[0-9]+$ ]] || {
  printf 'Usage: %s workspace_<number>\n' "$0" >&2
  exit 2
}

dml_args=()
while IFS= read -r file; do
  [[ "$file" =~ ^[a-z_0-9]+\.sql$ ]] || {
    printf 'Invalid DML manifest entry: %s\n' "$file" >&2
    exit 1
  }
  [[ -f "database/deploy/dml/$file" ]] || {
    printf 'Missing DML file: database/deploy/dml/%s\n' "$file" >&2
    exit 1
  }
  printf 'Queued database/deploy/dml/%s\n' "$file"
  dml_args+=(-f "database/deploy/dml/$file")
done < <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' database/deploy/dml/manifest.txt)

((${#dml_args[@]} > 0)) || { printf 'DML manifest is empty.\n' >&2; exit 1; }
psql -X -w --single-transaction -v ON_ERROR_STOP=1 -d "$workspace" \
  -v "workspace=$workspace" -c "SET ROLE $workspace" "${dml_args[@]}"
