#!/bin/sh
set -e

workspace_name="$1"
project_root="$WORKSPACE"
ddl_root="$project_root/database/deploy/ddl"
temporary_directory="$(mktemp -d)"

trap 'rm -rf "$temporary_directory"' EXIT

pg_dump \
    --schema-only \
    --schema "$workspace_name" \
    --no-owner \
    --no-privileges \
    --no-comments \
    --quote-all-identifiers \
    --dbname "$workspace_name" \
    > "$temporary_directory/workspace.sql"

awk \
    -v requested_schema="$workspace_name" \
    -v output_directory="$temporary_directory/ddl" \
    -v include_file="$temporary_directory/includes.txt" \
    -f "$project_root/scripts/jenkins/split_pg_dump.awk" \
    "$temporary_directory/workspace.sql"

{
    printf '%s\n' '-- Install exported objects in PostgreSQL dependency order.'
    printf '%s\n' '-- Run with psql and provide the workspace variable.'
    printf '%s\n' '-- psql -v workspace=WORKSPACE01 -d WORKSPACE01 -f database/deploy/ddl/install_all_objects.sql'
    printf '\n%s\n\n' 'SET ROLE :"workspace";'
    while IFS= read -r include_path; do
        printf '\\ir %s\n' "$include_path"
    done < "$temporary_directory/includes.txt"
} > "$temporary_directory/install_all_objects.sql"

find "$ddl_root" -type f -name '*.sql' -delete
cp -R "$temporary_directory/ddl/." "$ddl_root/"
cp "$temporary_directory/install_all_objects.sql" "$ddl_root/install_all_objects.sql"
