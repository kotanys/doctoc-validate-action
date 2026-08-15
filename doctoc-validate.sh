#!/usr/bin/env bash

cd "$GITHUB_WORKSPACE/repo" || exit 3

shopt -s globstar nullglob extglob globskipdots
shopt -u dotglob failglob nocaseglob

readonly DOCTOC=$GITHUB_WORKSPACE/node_modules/.bin/doctoc
command -v "$DOCTOC" >/dev/null || {
    echo "Doctoc not found under $DOCTOC!"
    exit 1
} >&2

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

run-doctoc() {
    # shellcheck disable=SC2086
    "$DOCTOC" $INPUT_ARGS "$@"
}

check-file() {
    local file=$1
    local workfile
    workfile=$(mktemp -p "$TEMP_DIR")
    cat "$file" >"$workfile" || return 1
    run-doctoc "$workfile" >/dev/null || return 1

    declare -g REPLY
    REPLY=$(diff --old-line-format='  -%3dn %L' --new-line-format='  +%3dn %L' --unchanged-line-format='' "$file" "$workfile" 2>&1)
}

validate-file-name() {
    local file=$1
    if [[ $file == /* ]]; then
        echo "Path '$file' is absolute. This is disallowed."
        return 4
    fi
    if [[ ! -r "$file" ]]; then
        echo "File '$file' doesn't exist or isn't readable."
        return 4
    fi
} >&2

print-bad-files() {
    if (( ${#bad_files} != 0 )); then
        echo '---'
        echo 'Files to fix:'
        for file in "${bad_files[@]}"; do
            echo "  $file"
        done
    fi
}

main() {
    local file
    local -a patterns bad_files
    IFS=: read -r -a patterns <<<"$INPUT_FILES"

    for pattern in "${patterns[@]}"; do
        for file in $pattern; do
            validate-file-name "$file" || exit

            echo -n "checking $file... "
            if [[ -d "$file" ]]; then
                echo "is a directory, skipping"
                continue
            fi
            if check-file "$file"; then
                echo "ok"
            else
                echo "fail! Please update the TOC: \`doctoc $INPUT_ARGS $file\`"
                [[ $INPUT_PRINT_DIFF == true ]] && echo "$REPLY"
                bad_files+=("$file")
            fi
        done
    done

    print-bad-files
    (( ${#bad_files} == 0 ))
}

main
