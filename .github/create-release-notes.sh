#!/bin/bash

set -euxo pipefail

MANIFEST_PATH="$1"
OUTPUT_PATH="$2"

echo "## build-meta" > "$OUTPUT_PATH"

# shellcheck disable=SC2129
echo "\`\`\`" >> "$OUTPUT_PATH"
cat "$MANIFEST_PATH" >> "$OUTPUT_PATH"
echo "\`\`\`" >> "$OUTPUT_PATH"
