#!/usr/bin/env bash
# Stage upstream (aaddrick/claude-desktop-debian) main onto the current branch as one
# squashed change, for a reviewed PR:
#   - .github/workflows stays exactly as in this fork (the upstream ones publish to their
#     Cloudflare/apt/AUR infra and run their triage bot; GITHUB_TOKEN may not push them anyway),
#   - the official .deb pins go to whichever is newer, via fork/check-update.sh.
# Any other conflict fails. Prints a one-line summary and exits 0, or exits 3 if nothing new.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
UPSTREAM=https://github.com/aaddrick/claude-desktop-debian.git
PINS=scripts/setup/official-deb.sh

git fetch -q "$UPSTREAM" main
head=$(git rev-parse --short FETCH_HEAD)
subject=$(git log -1 --format=%s FETCH_HEAD)

git merge --squash --no-commit FETCH_HEAD >/dev/null 2>&1 || true

git rm -rfq --ignore-unmatch .github/workflows
git checkout HEAD -- .github/workflows
if git diff --name-only --diff-filter=U | grep -qxF "$PINS"; then
	git checkout --theirs -- "$PINS"
	git add "$PINS"
fi

conflicts=$(git diff --name-only --diff-filter=U)
if [[ -n $conflicts ]]; then
	echo "upstream $head conflicts with this fork in:" >&2
	echo "$conflicts" >&2
	exit 1
fi

rc=0
fork/check-update.sh >/dev/null || rc=$?
[[ $rc == 0 || $rc == 3 ]] || exit "$rc"
git add -A "$PINS" fork/flatpak fork/fedora-image

if git diff --cached --quiet; then
	echo "already in sync with upstream $head" >&2
	exit 3
fi
echo "upstream $head: $subject"
