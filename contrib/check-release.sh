#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/functions-sign.sh"

declare -A SIGKEYS


SIGKEYS["Tom/herbetom"]="3a00002ecf1392e7ddbb8db395412cdcb5d9cd8e310b486c3ec1fc0bf161195b"
SIGKEYS["Kai/wusel42"]="cd2ed332a77bb71ade862d5b8521c59c7987ef418da6ecc69c19f32aa5ec5e66"
SIGKEYS["Jan/Jevermeister"]="6fbba7d2e081a0a2c3d6832d5440e8786f90acabfe462b602531b4665ce58590"
SIGKEYS["Michel/eriu"]="be5155bac7681fb4631bdab72c47b6e606e3f0ccfe50bb8f6cd6866c1c97c729"
SIGKEYS["github-actions-ci"]="ff49b7abc9d2caab57bc5c88fb8cc3b5c5b0eb5312b7cc326a18cc811305592a"
SIGKEYS["buildserver"]="e191158c837941158d827e5c6df971bfb01161d5d6f86a366d8a7897feedf9da"

function usage() {
	echo "Usage: $0 <release-version> <branch>"
	echo "Example: $0 2.0.0 stable"
	exit 1
}

function cleanup() {
	rm -rf "$TEMP_DIR"
}

RELEASE_VERSION="${1:-}"
BRANCH="${2:-}"

[ -z "$RELEASE_VERSION" ] && usage
[ -z "$BRANCH" ] && usage

# Create Temporary working directory
TEMP_DIR="$(mktemp -d)"

MANIFEST_PATH="${TEMP_DIR}/checking.manifest"

# Download released manifest archive
MANIFEST_URL="https://fw.ffrn.de/images/${RELEASE_VERSION}/images/sysupgrade/${BRANCH}.manifest"
echo "Download manifest from $MANIFEST_URL"
curl -s -L -o "${MANIFEST_PATH}" "${MANIFEST_URL}"

for name in "${!SIGKEYS[@]}"
do
	valid_ci_signature="$(get_valid_signature "${MANIFEST_PATH}" "${SIGKEYS[$name]}")"

	# Check if manifest is signed with the key under test
	if [ -n "$valid_ci_signature" ]; then
		echo "Manifest is signed with the \"${name}\" key"
		echo "Signature: $valid_ci_signature"
	fi
done

cleanup
