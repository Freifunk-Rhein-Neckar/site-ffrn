#!/usr/bin/env bash

set -euo pipefail

function split_manifest() {
    local manifest upper lower

    manifest="$1"
    upper="$2"
    lower="$3"

    awk 'BEGIN    {
        sep = 0
    }

    /^---$/ {
        sep = 1;
        next
    }

    {
        if(sep == 0) {
            print > "'"$upper"'"
        } else {
            print > "'"$lower"'"
        }
    }' "$manifest"
}

function create_signature() {
    local secret manifest upper lower

    manifest="$1"
    secret="$2"

    upper="$(mktemp)"
    lower="$(mktemp)"

    # Split manifest into upper and lower part
    split_manifest "$manifest" "$upper" "$lower"

    # Sign upper part of manifest
    ecdsasign "$upper" < "$secret"

    # Remove temporary files
    rm -f "$upper" "$lower"
}

function get_valid_signature() {
    local public_key manifest upper lower

    manifest="$1"
    public_key="$2"

    upper="$(mktemp)"
    lower="$(mktemp)"

    # Split manifest into upper and lower part
    split_manifest "$manifest" "$upper" "$lower"

    # Validate upper part of manifest
    while read -r line
    do
        if ecdsaverify -s "$line" -p "$public_key" "$upper"; then
            echo "$line"
            break
        fi
    done < "$lower"

    # Remove temporary files
    rm -f "$upper" "$lower"
}
