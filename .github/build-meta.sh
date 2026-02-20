#!/bin/bash

set -euxo pipefail

SCRIPT_DIR="$(dirname "$0")"
UPSTREAM_REPO_NAME="freifunk-rhein-neckar/site-ffrn"

# Get Git short hash for repo at $SCRIPT_DIR
GIT_SHORT_HASH="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD)"

# Get date of last Git commit for repo at $SCRIPT_DIR
GIT_COMMIT_DATE="$(git -C "$SCRIPT_DIR" log -1 --format=%cd --date=format:'%Y%m%d')"

# Build BROKEN by default. Disable for release builds.
BROKEN="1"

# Don't deploy by default. Enable for release and nightly builds.
DEPLOY="0"

# Don't release by default. Enable for tags.
CREATE_RELEASE="0"

# Create pre-releases by default. Disable for release builds.
PRE_RELEASE="1"

# Don't link release by default. Enable for nightly.
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
# Regex for nightly firmware tag
NIGHTLY_TAG_RE="^v[2-9].[0-9].x-[0-9]{8}$"
# Regex for custom nightly firmware tag
CUSTOM_NIGHTLY_TAG_RE="^v[2-9].[0-9].x-[0-9]{8}"
# Regex for release firmware tag
RELEASE_TAG_RE="^v[2-9].[0-9].[0-9]$"

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
CONTAINER_IMAGE="$(jq -r '.container?.image // ""' "$SCRIPT_DIR/build-info.json")"
CONTAINER_VERSION="$(jq -r -e .container.version "$SCRIPT_DIR/build-info.json")"

# Get Default Release version from site.mk
DEFAULT_RELEASE_VERSION="$(make --no-print-directory -C "$SCRIPT_DIR/.." -f ci-build.mk version)"
DEFAULT_RELEASE_VERSION="$DEFAULT_RELEASE_VERSION-$GIT_SHORT_HASH"

# Create site-version from site.mk
SITE_VERSION="$(make --no-print-directory -C "$SCRIPT_DIR/.." -f ci-build.mk site-version)"
SITE_VERSION="$SITE_VERSION-ffrn-$GIT_COMMIT_DATE-$GIT_SHORT_HASH"

# Enable Manifest generation conditionally
MANIFEST_STABLE="0"
MANIFEST_BETA="0"
MANIFEST_EXPERIMENTAL="0"
MANIFEST_NIGHTLY="0"

# Only Sign manifest on release builds
SIGN_MANIFEST="0"

echo "GitHub Event-Name: $GITHUB_EVENT_NAME"
echo "GitHub Ref-Type: $GITHUB_REF_TYPE"
echo "GitHub Ref-Name: $GITHUB_REF_NAME"

if [ "$GITHUB_EVENT_NAME" = "push"  ] && [ "$GITHUB_REF_TYPE" = "branch" ]; then
	if [ "$GITHUB_REF_NAME" = "main" ]; then
		# Push to main - autoupdater Branch is nightly and enabled
		AUTOUPDATER_ENABLED="1"
		AUTOUPDATER_BRANCH="nightly"

		MANIFEST_NIGHTLY="1"
	elif [[ "$GITHUB_REF_NAME" =~ $RELEASE_BRANCH_RE ]]; then
		# Push to release branch - autoupdater Branch is stable and enabled
		AUTOUPDATER_ENABLED="1"
		AUTOUPDATER_BRANCH="stable"

		MANIFEST_STABLE="1"
		MANIFEST_BETA="1"
		MANIFEST_EXPERIMENTAL="1"
	else
		# Push to unknown branch - Disable autoupdater
		AUTOUPDATER_ENABLED="0"
		AUTOUPDATER_BRANCH="nightly"
	fi
elif [ "$GITHUB_EVENT_NAME" = "push"  ] && [ "$GITHUB_REF_TYPE" = "tag" ]; then
	if [[ "$GITHUB_REF_NAME" =~ $NIGHTLY_TAG_RE ]]; then
		# Nightly release - autoupdater Branch is nightly and enabled
		AUTOUPDATER_ENABLED="1"
		AUTOUPDATER_BRANCH="nightly"

		MANIFEST_NIGHTLY="1"
		SIGN_MANIFEST="1"

		RELEASE_VERSION="$GITHUB_REF_NAME"
		# remove v prefix
		RELEASE_VERSION="${RELEASE_VERSION#"v"}"
		DEPLOY="1"
		LINK_RELEASE="1"
	elif [[ "$GITHUB_REF_NAME" =~ $RELEASE_TAG_RE ]]; then
		# Stable release - autoupdater Branch is stable and enabled
		AUTOUPDATER_ENABLED="1"
		AUTOUPDATER_BRANCH="stable"

		MANIFEST_STABLE="1"
		MANIFEST_BETA="1"
		MANIFEST_EXPERIMENTAL="1"
		SIGN_MANIFEST="1"

		RELEASE_VERSION="$GITHUB_REF_NAME"
		# remove v prefix
		RELEASE_VERSION="${RELEASE_VERSION#"v"}"
		BROKEN="0"
		DEPLOY="1"
		PRE_RELEASE="0"
	else
		# Unknown release - Disable autoupdater
		AUTOUPDATER_ENABLED="0"
		AUTOUPDATER_BRANCH="nightly"

		if [[ "$GITHUB_REF_NAME" =~ $CUSTOM_NIGHTLY_TAG_RE ]]; then
			# Custom nightly tag

			RELEASE_VERSION="$GITHUB_REF_NAME"
			# remove v prefix
			RELEASE_VERSION="${RELEASE_VERSION#"v"}"
		fi
	fi

	CREATE_RELEASE="1"
elif [ "$GITHUB_EVENT_NAME" = "workflow_dispatch" ] || [ "$GITHUB_EVENT_NAME" = "pull_request" ]; then
	# Workflow Dispatch - autoupdater Branch is nightly and disabled
	AUTOUPDATER_ENABLED="0"
	AUTOUPDATER_BRANCH="nightly"
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

# Signing should only happen when pushed to the upstream repository.
# Skip this step for the pipeline to succeed but inform the user.
if [ "${GITHUB_REPOSITORY,,}" != "${UPSTREAM_REPO_NAME,,}" ] && [ "$SIGN_MANIFEST" != "0" ]; then
	SIGN_MANIFEST="0"

	echo "::warning::Skip manifest signature due to action running in fork."
fi

# We should neither deploy in a fork, as the workflow is hard-coding our firmware-server
if [ "${GITHUB_REPOSITORY,,}" != "${UPSTREAM_REPO_NAME,,}" ] && [ "$DEPLOY" != "0" ]; then
	DEPLOY="0"

	echo "::warning::Skip deployment due to action running in fork."
fi

# Determine Version to use
RELEASE_VERSION="${RELEASE_VERSION:-$DEFAULT_RELEASE_VERSION}"

# Write build-meta to dedicated file before appending GITHUB_OUTPUT.
# This way, we can create an artifact for our build-meta to eventually upload to a release.
BUILD_META_TMP_DIR="$(mktemp -d)"
BUILD_META_OUTPUT="$BUILD_META_TMP_DIR/build-meta.txt"

write_output() {
  local key="$1"
  local value="$2"

  if [ -n "$value" ]; then
    echo "$key=$value" >> "$BUILD_META_OUTPUT"
  fi
}

write_output "build-meta-output" "$BUILD_META_TMP_DIR"
write_output "container-image" "$CONTAINER_IMAGE"
write_output "container-version" "$CONTAINER_VERSION"
write_output "gluon-repository" "$GLUON_REPOSITORY"
write_output "gluon-commit" "$GLUON_COMMIT"
write_output "site-version" "$SITE_VERSION"
write_output "release-version" "$RELEASE_VERSION"
write_output "autoupdater-enabled" "$AUTOUPDATER_ENABLED"
write_output "autoupdater-branch" "$AUTOUPDATER_BRANCH"
write_output "broken" "$BROKEN"
write_output "manifest-stable" "$MANIFEST_STABLE"
write_output "manifest-beta" "$MANIFEST_BETA"
write_output "manifest-experimental" "$MANIFEST_EXPERIMENTAL"
write_output "manifest-nightly" "$MANIFEST_NIGHTLY"
write_output "sign-manifest" "$SIGN_MANIFEST"
write_output "deploy" "$DEPLOY"
write_output "link-release" "$LINK_RELEASE"
write_output "create-release" "$CREATE_RELEASE"
write_output "pre-release" "$PRE_RELEASE"
write_output "target-whitelist" "$TARGET_WHITELIST"

# Copy over to GITHUB_OUTPUT
cat "$BUILD_META_OUTPUT" >> "$GITHUB_OUTPUT"

# Display Output so we can conveniently check it from CI log viewer
cat "$GITHUB_OUTPUT"

exit 0
