function safe_name(value) {
    gsub(/"/, "", value)
    gsub(/[^A-Za-z0-9_.-]/, "_", value)
    gsub(/^[_ .-]+|[_ .-]+$/, "", value)
    return value == "" ? "unnamed_object" : value
}

function object_directory(type) {
    if (type == "MATERIALIZED VIEW") return "materialized_view"
    if (type == "ROW SECURITY") return "security"
    if (type ~ /^TEXT SEARCH /) return "text_search"
    if (type == "SEQUENCE OWNED BY") return "sequence"
    if (type == "TABLE ATTACH") return "table"
    value = tolower(type)
    gsub(/[^a-z0-9]+/, "_", value)
    gsub(/^_+|_+$/, "", value)
    return value
}

function start_object(line,    rest, name, type, schema, suffix, filename, relative_path) {
    active = 0
    rest = line
    sub(/^-- Name: /, "", rest)

    name = rest
    sub(/; Type: .*/, "", name)

    type = rest
    sub(/^.*; Type: /, "", type)
    sub(/; Schema: .*/, "", type)

    schema = rest
    sub(/^.*; Schema: /, "", schema)
    sub(/; Owner: .*/, "", schema)

    if (schema != requested_schema || type == "SCHEMA") return

    suffix = ""
    if (type == "SEQUENCE OWNED BY") suffix = "_ownership"
    if (type == "FUNCTION" || type == "PROCEDURE" || type == "AGGREGATE") {
        if (name ~ /\(/) {
            suffix = name
            sub(/^[^(]*\(/, "__", suffix)
            sub(/\).*$/, "", suffix)
            gsub(/[ ,()]/, "_", suffix)
            name = substr(name, 1, index(name, "(") - 1)
        }
    }

    directory = object_directory(type)
    current_type = type
    current_name = name
    filename = safe_name(name suffix) ".sql"
    relative_path = directory "/" filename
    output_path = output_directory "/" relative_path
    system("mkdir -p \"" output_directory "/" directory "\"")

    print relative_path >> include_file
    print "SET search_path TO :\"workspace\", pg_catalog;" > output_path
    print "" >> output_path
    active = 1
    object_count++
}

/^-- Name: / {
    start_object($0)
    next
}

/^-- PostgreSQL database dump complete/ {
    active = 0
    next
}

active {
    line = $0
    if (current_type == "TEXT SEARCH CONFIGURATION" &&
        line ~ /^ALTER TEXT SEARCH CONFIGURATION .* ADD MAPPING FOR /) {
        mapping_name = line
        sub(/^.* ADD MAPPING FOR /, "", mapping_name)
        sub(/ WITH .*$/, "", mapping_name)
        mapping_path = "text_search/" safe_name(current_name) "_mapping_" safe_name(mapping_name) ".sql"
        mapping_output = output_directory "/" mapping_path
        print mapping_path >> include_file
        print "SET search_path TO :\"workspace\", pg_catalog;" > mapping_output
        print "" >> mapping_output
        gsub("\"" requested_schema "\"\\.", ":\"workspace\".", line)
        gsub(requested_schema "\\.", ":\"workspace\".", line)
        print line >> mapping_output
        object_count++
        next
    }
    gsub("\"" requested_schema "\"\\.", ":\"workspace\".", line)
    gsub(requested_schema "\\.", ":\"workspace\".", line)
    print line >> output_path
}

END {
    if (object_count == 0) {
        print "No schema objects found for workspace " requested_schema > "/dev/stderr"
        exit 1
    }
    print "Exported " object_count " PostgreSQL objects from " requested_schema "."
}
