#!/usr/bin/env bash
# Bring every package source up to the newest claude-desktop in Anthropic's APT repo:
#   - the pinned official .deb in scripts/setup/official-deb.sh (RPM and AppImage builds),
#   - the .deb URL/checksum in the Flatpak manifest, and the release in its metainfo.
# amd64 decides; arm64 pins move only when arm64 has published the same version.
# Prints a one-line summary and exits 0, or exits 3 if already up to date.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PINS="$ROOT/scripts/setup/official-deb.sh"
MANIFEST="$ROOT/fork/flatpak/io.github.celso_alexandre.ClaudeDesktop.yml"
METAINFO="$ROOT/fork/flatpak/io.github.celso_alexandre.ClaudeDesktop.metainfo.xml"

# shellcheck source=/dev/null
source "$ROOT/scripts/_common.sh"
# shellcheck source=/dev/null
source "$PINS"

current=$(grep -oP "^OFFICIAL_DEB_VERSION='\K[^']+" "$PINS")
resolve_official_deb amd64 >&2
version=$resolved_official_version
amd64_file=$resolved_official_filename
amd64_sha=$resolved_official_sha256

newest=$(printf '%s\n%s\n' "$current" "$version" | sort -V | tail -1)
if [[ $version == "$current" || $newest == "$current" ]] &&
	grep -qF "sha256: $amd64_sha" "$MANIFEST"; then
	echo "up to date: $current" >&2
	exit 3
fi
# The index can list a file before the CDN serves it
official_deb_pool_ready "$amd64_file" || { echo "$amd64_file not fetchable yet" >&2; exit 3; }

sed -i -E \
	-e "s|^OFFICIAL_DEB_VERSION=.*|OFFICIAL_DEB_VERSION='$version'|" \
	-e "s|^OFFICIAL_DEB_POOL_AMD64=.*|OFFICIAL_DEB_POOL_AMD64='$amd64_file'|" \
	-e "s|^OFFICIAL_DEB_SHA256_AMD64=.*|OFFICIAL_DEB_SHA256_AMD64='$amd64_sha'|" "$PINS"
if resolve_official_deb arm64 >&2 && [[ $resolved_official_version == "$version" ]] &&
	official_deb_pool_ready "$resolved_official_filename"; then
	sed -i -E \
		-e "s|^OFFICIAL_DEB_POOL_ARM64=.*|OFFICIAL_DEB_POOL_ARM64='$resolved_official_filename'|" \
		-e "s|^OFFICIAL_DEB_SHA256_ARM64=.*|OFFICIAL_DEB_SHA256_ARM64='$resolved_official_sha256'|" "$PINS"
fi

sed -i -E \
	-e "s|(^\s*url: ).*/claude-desktop_[^/]*\.deb$|\1$OFFICIAL_APT_BASE/$amd64_file|" \
	-e "s|(^\s*sha256: )[0-9a-f]{64}$|\1$amd64_sha|" "$MANIFEST"
sed -i -E "s|<release version=\"[^\"]*\" date=\"[^\"]*\"/>|<release version=\"$version\" date=\"$(date -u +%F)\"/>|" "$METAINFO"

echo "Claude Desktop $version"
