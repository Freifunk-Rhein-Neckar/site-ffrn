#!/bin/bash

set -euxo pipefail

# Generate space-separated list of targets to combine
TARGET_LIST=""
if [ -n "$ACTION_TARGETS" ]; then
    TARGET_LIST=$(echo "$ACTION_TARGETS" | jq -r '.[]' | paste -sd ' ')
fi

# Read target names to list
ARTIFACT_NAMES=""
for filename in $ACTION_ARTIFACT_DIR/*/ ; do
	artifact_folder_name="$(basename $filename)"
	echo "Target artifact: ${artifact_folder_name} (Full: ${filename})"

	ARTIFACT_NAMES="${ARTIFACT_NAMES} $artifact_folder_name"
done

# Combine artifacts
ARTIFACT_OUT_DIR="$RUNNER_TEMP/output"
EXTRACT_TEMP_DIR="$RUNNER_TEMP/extract"

mkdir -p "$ARTIFACT_OUT_DIR"
for artifact_target in $ARTIFACT_NAMES ; do
	# Check if artifact in list. Only delete otherwise.
	if [ -n "$TARGET_LIST" ] && [[ "$TARGET_LIST" =~ "$artifact_target" ]]; then
		echo "Combining ${artifact_target}"

		EXTRACT_TEMP_DIR_TARGET="${EXTRACT_TEMP_DIR}/${artifact_target}"
		ARTIFACT_SRC_DIR_TARGET="${ACTION_ARTIFACT_DIR}/${artifact_target}"

		if [[ "$ACTION_KEEP_PACKED" != "1" ]]; then
			# Create Temporary extraction directory
			mkdir -p "${EXTRACT_TEMP_DIR_TARGET}"

			# Unpack archive
			tar xf "${ARTIFACT_SRC_DIR_TARGET}/output.tar.xz" -C "${EXTRACT_TEMP_DIR_TARGET}"

			# Combine targets
			rsync -a ${EXTRACT_TEMP_DIR_TARGET}/* "$ARTIFACT_OUT_DIR"

			# Remove temporary extraction directory
			rm -rf "${EXTRACT_TEMP_DIR_TARGET}"
		else
			# Copy and rename archive
			cp "${ARTIFACT_SRC_DIR_TARGET}/output.tar.xz" "${ARTIFACT_OUT_DIR}/${artifact_target}.tar.xz"
		fi

		# Delete artifacts if enabled
		if [ "${ACTION_DELETE_COMBINED}" -eq "1" ]; then
			rm -rf "${ARTIFACT_SRC_DIR_TARGET}"
		fi
	else
		echo "Skipping ${artifact_target}"
	fi
done

tree "$ARTIFACT_OUT_DIR"

# Move combined artifacts to artifact directory
mkdir -p "$ACTION_OUTPUT_DIR"
mv $ARTIFACT_OUT_DIR/* "$ACTION_OUTPUT_DIR"

tree "$ACTION_OUTPUT_DIR"

# Remove temporary directory
rm -rf "$EXTRACT_TEMP_DIR"
