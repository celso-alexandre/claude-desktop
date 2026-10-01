#!/usr/bin/env bash
# Prove an installed/extracted package ships Anthropic's app unmodified: every file of the
# official .deb's usr/lib/claude-desktop must be present in <app-dir> byte for byte, and
# <app-dir> may hold nothing else beyond the files named with --extra.
# The .deb is the pinned one (scripts/setup/official-deb.sh), refused unless its SHA-256
# matches the pin.
# Usage: fork/verify-official-app.sh <app-dir> [--extra <relpath>]... [--missing <relpath>]...
#   --extra    a file this fork's packaging adds (e.g. the launcher's helpers)
#   --missing  an official file the package deliberately drops (e.g. chrome-sandbox in Flatpak)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PINS="$ROOT/scripts/setup/official-deb.sh"
BASE=https://downloads.claude.ai/claude-desktop/apt/stable

app=$(realpath "$1")
shift
declare -A extra=() missing=()
while (($#)); do
	case $1 in
	--extra) extra[./$2]=1 ;;
	--missing) missing[./$2]=1 ;;
	*) echo "unknown option $1" >&2; exit 2 ;;
	esac
	shift 2
done

pool=$(grep -oP "^OFFICIAL_DEB_POOL_AMD64='\K[^']+" "$PINS")
sha=$(grep -oP "^OFFICIAL_DEB_SHA256_AMD64='\K[^']+" "$PINS")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL --retry 3 -o "$TMP/official.deb" "$BASE/$pool"
echo "$sha  $TMP/official.deb" | sha256sum -c --quiet
(cd "$TMP" && ar x official.deb && mkdir d && tar xf data.tar.* -C d ./usr/lib/claude-desktop)
official="$TMP/d/usr/lib/claude-desktop"

sums() { (cd "$1" && find . \( -type f -o -type l \) -print0 | sort -z | xargs -0 sha256sum); }
sums "$official" >"$TMP/official.sum"
sums "$app" >"$TMP/app.sum"

bad=0
while read -r hash path; do
	[[ ${missing[$path]:-} ]] && continue
	got=$(awk -v p="$path" '$2 == p {print $1}' "$TMP/app.sum")
	if [[ -z $got ]]; then
		echo "MISSING  $path"; bad=1
	elif [[ $got != "$hash" ]]; then
		echo "CHANGED  $path"; bad=1
	fi
done <"$TMP/official.sum"
while read -r _ path; do
	grep -qF "  $path" "$TMP/official.sum" && continue
	[[ ${extra[$path]:-} ]] && continue
	echo "ADDED    $path"; bad=1
done <"$TMP/app.sum"

n=$(wc -l <"$TMP/official.sum")
if ((bad)); then
	echo "FAIL: $app differs from Anthropic's $pool" >&2
	exit 1
fi
added=${!extra[*]}
echo "PASS: all $n official files byte-identical in $app; extra files: ${added:-none}"
