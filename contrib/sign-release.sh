#!/bin/bash

set -euo pipefail

function usage() {
    echo "Usage: $0 <release-version> <private-key-path>"
    echo "Example: $0 2.0.0 /path/to/private-key.ecdsakey"
    exit 1
}

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

function cleanup() {
    rm -rf "$TEMP_DIR"
}

# This Script is used to sign a Firmware Release using
# a private ECDSA key.

DEFAULT_GITHUB_REPOSITORY_URL="freifunk-darmstadt/site-ffda"
CI_PUBLIC_KEY="cea1e84bf157d7362287fcd21d13de14634341e3d1ea7038000062743554dc88"

GITHUB_REPOSITORY_URL="${GITHUB_REPOSITORY_URL:-$DEFAULT_GITHUB_REPOSITORY_URL}"

RELEASE_VERSION="${1:-}"
PRIVATE_KEY_PATH="${2:-}"

[ -z "$RELEASE_VERSION" ] && usage
[ -z "$PRIVATE_KEY_PATH" ] && usage

# Create Temporary working directory
TEMP_DIR="$(mktemp -d)"

# Download released manifest archive
MANIFEST_ARCHIVE_URL="https://github.com/${GITHUB_REPOSITORY_URL}/releases/download/${RELEASE_VERSION}/manifest.tar.xz"
echo "Download manifest archvie from $MANIFEST_ARCHIVE_URL"
curl -s -L -o "${TEMP_DIR}/manifest.tar.xz" "${MANIFEST_ARCHIVE_URL}"

# Extract manifest archive
echo "Extracting manifest archive to $TEMP_DIR"
tar xf "${TEMP_DIR}/manifest.tar.xz" -C "${TEMP_DIR}"

# Sign manifest
for manifest_path in "${TEMP_DIR}/"*.manifest; do
    valid_ci_signature="$(get_valid_signature "$manifest_path" "$CI_PUBLIC_KEY")"

    # Check if manifest is signed with CI key first
    if [ -n "$valid_ci_signature" ]; then
        echo "Manifest $manifest_path is signed with CI key"
        echo "Signature: $valid_ci_signature"
    else
        echo "Manifest $manifest_path is not signed with CI key"
        cleanup
        exit 1
    fi

    # Get filename without extension
    manifest_branch_name="$(basename "$manifest_path" .manifest)"

    # Get Signature
    echo "-- Signature for $manifest_branch_name --"
    create_signature "$manifest_path" "$PRIVATE_KEY_PATH"
done

# Remove Temporary working directory
cleanup
