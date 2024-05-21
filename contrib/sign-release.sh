#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/functions-sign.sh"

function usage() {
    echo "Usage: $0 <release-version> <private-key-path>"
    echo "Example: $0 2.0.0 /path/to/private-key.ecdsakey"
    exit 1
}

function cleanup() {
    rm -rf "$TEMP_DIR"
}

# This Script is used to sign a Firmware Release using
# a private ECDSA key.

DEFAULT_GITHUB_REPOSITORY_URL="Freifunk-Rhein-Neckar/site-ffrn"
CI_PUBLIC_KEY="ff49b7abc9d2caab57bc5c88fb8cc3b5c5b0eb5312b7cc326a18cc811305592a"

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
