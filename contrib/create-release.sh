#!/bin/bash

set -euo pipefail

function usage() {
    echo "Usage: $0 [RELEASE_NAME]"
    echo "  RELEASE_NAME: Name of the release tag to create. If not provided, the version from site.mk is used."
}

function check_input_y() {
    echo "$1"
    echo "Proceed? (y/n)"

    read -n 1 -r

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Proceeding"
    else
        echo "Aborting"
        exit 1
    fi
}

SCRIPT_DIR="$(dirname "$0")"

RELEASE_NAME="${1-}"

# Regex for testing firmware tag
TESTING_TAG_RE="^[2-9].[0-9]~[0-9]{8}$"
# Regex for release firmware tag
RELEASE_TAG_RE="^[2-9].[0-9].[0-9]$"

# Check if we have an argument provided.
if [ -n "$RELEASE_NAME" ]; then
    if [[ "$RELEASE_NAME" =~ $RELEASE_TAG_RE ]]; then
        # Release Tag
        echo "Provided Release Name '$RELEASE_NAME' is valid"
    elif [[ "$RELEASE_NAME" =~ $TESTING_TAG_RE ]]; then
        # Testing Tag
        echo "Provided Testing Name '$RELEASE_NAME' is valid"
    else
        # Custom Tag
        check_input_y "Provided release name is not a valid release or testing tag."
    fi
else
    RELEASE_NAME="$(make --no-print-directory -C "$SCRIPT_DIR/.." -f ci-build.mk version)"
fi

# Replace ~ with - in testing tags
TAG_NAME="${RELEASE_NAME//\~/\-}"

check_input_y "Proceed to tag firmware release for '$RELEASE_NAME' (Tag: '$TAG_NAME')?"

echo "Proceeding to tag firmware release with $RELEASE_NAME"

git tag "$TAG_NAME"

echo "Tag was created"
echo "Push with 'git push origin $TAG_NAME'"
