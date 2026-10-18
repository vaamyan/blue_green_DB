#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

validate_manifest() {
  local manifest="$1"
  local base_dir="$2"
  local pattern="$3"
  local file
  local count=0

  [[ -f "$manifest" ]] || { printf 'Missing manifest: %s\n' "$manifest" >&2; return 1; }
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    [[ "$file" =~ $pattern ]] || { printf 'Invalid manifest entry: %s\n' "$file" >&2; return 1; }
    [[ -f "$base_dir/$file" ]] || { printf 'Missing file: %s/%s\n' "$base_dir" "$file" >&2; return 1; }
    ((count += 1))
  done < <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$manifest")

  ((count > 0)) || { printf 'Manifest is empty: %s\n' "$manifest" >&2; return 1; }
  printf '%s: validated %s files\n' "$manifest" "$count"
}

validate_manifest database/deploy/ddl/manifest.txt database/deploy/ddl '^[a-z_]+/[a-z_0-9]+\.sql$'
validate_manifest database/deploy/dml/manifest.txt database/deploy/dml '^[a-z_0-9]+\.sql$'
