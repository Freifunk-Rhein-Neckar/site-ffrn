#!/usr/bin/env bash

set -e

repo_path="$1"
old_commit="$2"
new_commit="$3"

# Check if all arguments are set, print usage otherwise
if [ -z "$repo_path" ] || [ -z "$old_commit" ] || [ -z "$new_commit" ]; then
    echo "Usage: bump-gluon-commit-message.sh <repo-path> <old-commit> <new-commit>"
    exit 1
fi

# Get short-ref of commits
old_commit_short="$(git -C "$repo_path" rev-parse --short "$old_commit")"
new_commit_short="$(git -C "$repo_path" rev-parse --short "$new_commit")"

# Get commit date of new commit (YYYY-MM-DD)
new_commit_date="$(git -C "$repo_path" show -s --format=%cd --date=short "$new_commit")"

# Get Git log of commit delta
commit_log="$(git -C "$repo_path" log --oneline --no-decorate "$old_commit".."$new_commit")"

cat <<EOF
build-info: update Gluon to $new_commit_date

Update Gluon from $old_commit_short to $new_commit_short.

~~~
$commit_log
~~~
EOF
