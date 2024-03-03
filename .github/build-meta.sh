#!/bin/bash

set -euxo pipefail

SCRIPT_DIR="$(dirname "$0")"

# Get Git short hash for repo at $SCRIPT_DIR
GIT_SHORT_HASH="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD)"

# Get date of last Git commit for repo at $SCRIPT_DIR
GIT_COMMIT_DATE="$(git -C "$SCRIPT_DIR" log -1 --format=%cd --date=format:'%Y%m%d')"

# Build BROKEN by default. Disable for release builds.
BROKEN="1"

# Don't deploy by default. Enable for release and testing builds.
DEPLOY="0"

# Don't release by default. Enable for tags.
CREATE_RELEASE="0"

# Don't link release by default. Enable for testing.
LINK_RELEASE="0"

# Target whitelist
if [ -n "$WORKFLOW_DISPATCH_TARGETS" ]; then
	# Get targets from dispatch event
	TARGET_WHITELIST="$WORKFLOW_DISPATCH_TARGETS"
else
	# Get targets from build-info.json
	TARGET_WHITELIST="$(jq -r -e '.build.targets | join(" ")' "$SCRIPT_DIR/build-info.json")"
fi

# Release Branch regex
RELEASE_BRANCH_RE="^v20[0-9]{2}\.[0-9]\.x$"
# Regex for testing firmware tag
TESTING_TAG_RE="^[2-9].[0-9]-[0-9]{8}$"
# Regex for custom testing firmware tag
CUSTOM_TESTING_TAG_RE="^[2-9].[0-9]-[0-9]{8}"
# Regex for release firmware tag
RELEASE_TAG_RE="^[2-9].[0-9].[0-9]$"

# Get Gluon version information
if [ -n "$WORKFLOW_DISPATCH_REPOSITORY" ] && [ -n "$WORKFLOW_DISPATCH_REFERENCE" ]; then
	# Get Gluon version information from dispatch event
	GLUON_REPOSITORY="$WORKFLOW_DISPATCH_REPOSITORY"
	GLUON_COMMIT="$WORKFLOW_DISPATCH_REFERENCE"
else
	# Get Gluon version information from build-info.json
	GLUON_REPOSITORY="$(jq -r -e .gluon.repository "$SCRIPT_DIR/build-info.json")"
	GLUON_COMMIT="$(jq -r -e .gluon.commit "$SCRIPT_DIR/build-info.json")"
fi

# Get Container version information
CONTAINER_VERSION="$(jq -r -e .container.version "$SCRIPT_DIR/build-info.json")"

# Get Default Release version from site.mk
DEFAULT_RELEASE_VERSION="$(make --no-print-directory -C "$SCRIPT_DIR/.." -f ci-build.mk version)"
DEFAULT_RELEASE_VERSION="$DEFAULT_RELEASE_VERSION-$GIT_SHORT_HASH"

# Create site-version from site.mk
SITE_VERSION="$(make --no-print-directory -C "$SCRIPT_DIR/.." -f ci-build.mk site-version)"
SITE_VERSION="$SITE_VERSION-ffda-$GIT_COMMIT_DATE-$GIT_SHORT_HASH"

# Enable Manifest generation conditionally
MANIFEST_STABLE="0"
MANIFEST_BETA="0"
MANIFEST_TESTING="0"

# Only Sign manifest on release builds
SIGN_MANIFEST="0"

echo "GitHub Event-Name: $GITHUB_EVENT_NAME"
echo "GitHub Ref-Type: $GITHUB_REF_TYPE"
echo "GitHub Ref-Name: $GITHUB_REF_NAME"

if [ "$GITHUB_EVENT_NAME" = "push"  ] && [ "$GITHUB_REF_TYPE" = "branch" ]; then
	if [ "$GITHUB_REF_NAME" = "master" ]; then
		# Push to master - autoupdater Branch is testing and enabled
		AUTOUPDATER_ENABLED="1"
		AUTOUPDATER_BRANCH="testing"

		MANIFEST_TESTING="1"
	elif [[ "$GITHUB_REF_NAME" =~ $RELEASE_BRANCH_RE ]]; then
		# Push to release branch - autoupdater Branch is stable and enabled
		AUTOUPDATER_ENABLED="1"
		AUTOUPDATER_BRANCH="stable"

		MANIFEST_STABLE="1"
		MANIFEST_BETA="1"
	else
		# Push to unknown branch - Disable autoupdater
		AUTOUPDATER_ENABLED="0"
		AUTOUPDATER_BRANCH="testing"
	fi
elif [ "$GITHUB_EVENT_NAME" = "push"  ] && [ "$GITHUB_REF_TYPE" = "tag" ]; then
	if [[ "$GITHUB_REF_NAME" =~ $TESTING_TAG_RE ]]; then
		# Testing release - autoupdater Branch is testing and enabled
		AUTOUPDATER_ENABLED="1"
		AUTOUPDATER_BRANCH="testing"

		MANIFEST_TESTING="1"
		SIGN_MANIFEST="1"

		RELEASE_VERSION="$(echo "$GITHUB_REF_NAME" | tr '-' '~')"
		DEPLOY="1"
		LINK_RELEASE="1"
	elif [[ "$GITHUB_REF_NAME" =~ $RELEASE_TAG_RE ]]; then
		# Stable release - autoupdater Branch is stable and enabled
		AUTOUPDATER_ENABLED="1"
		AUTOUPDATER_BRANCH="stable"

		MANIFEST_STABLE="1"
		MANIFEST_BETA="1"
		SIGN_MANIFEST="1"

		RELEASE_VERSION="$GITHUB_REF_NAME"
		BROKEN="0"
		DEPLOY="1"
	else
		# Unknown release - Disable autoupdater
		AUTOUPDATER_ENABLED="0"
		AUTOUPDATER_BRANCH="testing"

		if [[ "$GITHUB_REF_NAME" =~ $CUSTOM_TESTING_TAG_RE ]]; then
			# Custom testing tag

			# Replace first occurence of - with ~ of GITHUB_REF_NAME for RELEASE_VERSION
			# shellcheck disable=SC2001
			RELEASE_VERSION="$(echo "$GITHUB_REF_NAME" | sed 's/-/~/')"
		fi
	fi

	CREATE_RELEASE="1"
elif [ "$GITHUB_EVENT_NAME" = "workflow_dispatch" ] || [ "$GITHUB_EVENT_NAME" = "pull_request" ]; then
	# Workflow Dispatch - autoupdater Branch is testing and disabled
	AUTOUPDATER_ENABLED="0"
	AUTOUPDATER_BRANCH="testing"
else
	echo "Unknown ref type $GITHUB_REF_TYPE"
	exit 1
fi

# Ensure we don't {sign,deploy,release} on pull requests
if [ "$GITHUB_EVENT_NAME" = "pull_request" ]; then
	DEPLOY="0"
	CREATE_RELEASE="0"
	SIGN_MANIFEST="0"
fi

# Determine Version to use
RELEASE_VERSION="${RELEASE_VERSION:-$DEFAULT_RELEASE_VERSION}"

# Write build-meta to dedicated file before appending GITHUB_OUTPUT.
# This way, we can create an artifact for our build-meta to eventually upload to a release.
BUILD_META_TMP_DIR="$(mktemp -d)"
BUILD_META_OUTPUT="$BUILD_META_TMP_DIR/build-meta.txt"

# shellcheck disable=SC2129
# Not the nicest way to do this, but it works.
echo "build-meta-output=$BUILD_META_TMP_DIR" >> "$BUILD_META_OUTPUT"
echo "container-version=$CONTAINER_VERSION" >> "$BUILD_META_OUTPUT"
echo "gluon-repository=$GLUON_REPOSITORY" >> "$BUILD_META_OUTPUT"
echo "gluon-commit=$GLUON_COMMIT" >> "$BUILD_META_OUTPUT"
echo "site-version=$SITE_VERSION" >> "$BUILD_META_OUTPUT"
echo "release-version=$RELEASE_VERSION" >> "$BUILD_META_OUTPUT"
echo "autoupdater-enabled=$AUTOUPDATER_ENABLED" >> "$BUILD_META_OUTPUT"
echo "autoupdater-branch=$AUTOUPDATER_BRANCH" >> "$BUILD_META_OUTPUT"
echo "broken=$BROKEN" >> "$BUILD_META_OUTPUT"
echo "manifest-stable=$MANIFEST_STABLE" >> "$BUILD_META_OUTPUT"
echo "manifest-beta=$MANIFEST_BETA" >> "$BUILD_META_OUTPUT"
echo "manifest-testing=$MANIFEST_TESTING" >> "$BUILD_META_OUTPUT"
echo "sign-manifest=$SIGN_MANIFEST" >> "$BUILD_META_OUTPUT"
echo "deploy=$DEPLOY" >> "$BUILD_META_OUTPUT"
echo "link-release=$LINK_RELEASE" >> "$BUILD_META_OUTPUT"
echo "create-release=$CREATE_RELEASE" >> "$BUILD_META_OUTPUT"
echo "target-whitelist=$TARGET_WHITELIST" >> "$BUILD_META_OUTPUT"

# Copy over to GITHUB_OUTPUT
cat "$BUILD_META_OUTPUT" >> "$GITHUB_OUTPUT"

# Display Output so we can conveniently check it from CI log viewer
cat "$GITHUB_OUTPUT"

exit 0
