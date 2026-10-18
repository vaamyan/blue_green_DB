#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

workspace="${1:-}"
[[ "$workspace" =~ ^workspace_[0-9]+$ ]] || {
  printf 'Usage: %s workspace_<number>\n' "$0" >&2
  exit 2
}

while IFS= read -r file; do
  printf 'Applying database/deploy/ddl/%s\n' "$file"
  psql -X -w -v ON_ERROR_STOP=1 -d "$workspace" \
    -v "workspace=$workspace" \
    -c "SET ROLE $workspace" \
    -f "database/deploy/ddl/$file"

  case "$file" in
    trigger/trigger_1.sql)
      psql -X -w -v ON_ERROR_STOP=1 -d "$workspace" \
        -v "workspace=$workspace" -f database/jenkins/disable_trigger_1.sql
      ;;
    rule/rule_1.sql)
      psql -X -w -v ON_ERROR_STOP=1 -d "$workspace" \
        -v "workspace=$workspace" -f database/jenkins/disable_rule_1.sql
      ;;
  esac
done < <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' database/deploy/ddl/manifest.txt)
