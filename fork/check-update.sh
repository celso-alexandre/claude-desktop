#!/usr/bin/env bash
# Bring every package source up to the newest claude-desktop in Anthropic's signed APT index
# (fork/official-index.sh: InRelease signature → Packages hash → .deb hash):
#   - the pinned official .deb in scripts/setup/official-deb.sh (RPM and AppImage builds),
#   - the .deb URL/checksum in the Flatpak manifest, and the release in its metainfo.
# amd64 decides; arm64 pins move only when arm64 has published the same version.
# Prints a one-line summary and exits 0, or exits 3 if already up to date.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PINS="$ROOT/scripts/setup/official-deb.sh"
MANIFEST="$ROOT/fork/flatpak/io.github.celso_alexandre.ClaudeDesktop.yml"
METAINFO="$ROOT/fork/flatpak/io.github.celso_alexandre.ClaudeDesktop.metainfo.xml"
BASE=https://downloads.claude.ai/claude-desktop/apt/stable

current=$(grep -oP "^OFFICIAL_DEB_VERSION='\K[^']+" "$PINS")
IFS=$'\t' read -r version amd64_file amd64_sha < <("$ROOT/fork/official-index.sh" newest amd64)
echo "newest in Anthropic's signed index: $version" >&2

newest=$(printf '%s\n%s\n' "$current" "$version" | sort -V | tail -1)
if [[ $newest == "$current" ]] && grep -qF "sha256: $amd64_sha" "$MANIFEST"; then
	echo "up to date: $current" >&2
	exit 3
fi
# The index can list a file before the CDN serves it
curl -fsSI --max-time 30 -o /dev/null "$BASE/$amd64_file" ||
	{ echo "$amd64_file not fetchable yet" >&2; exit 3; }

sed -i -E \
	-e "s|^OFFICIAL_DEB_VERSION=.*|OFFICIAL_DEB_VERSION='$version'|" \
	-e "s|^OFFICIAL_DEB_POOL_AMD64=.*|OFFICIAL_DEB_POOL_AMD64='$amd64_file'|" \
	-e "s|^OFFICIAL_DEB_SHA256_AMD64=.*|OFFICIAL_DEB_SHA256_AMD64='$amd64_sha'|" "$PINS"
if IFS=$'\t' read -r arm64_version arm64_file arm64_sha < <("$ROOT/fork/official-index.sh" newest arm64) &&
	[[ $arm64_version == "$version" ]]; then
	sed -i -E \
		-e "s|^OFFICIAL_DEB_POOL_ARM64=.*|OFFICIAL_DEB_POOL_ARM64='$arm64_file'|" \
		-e "s|^OFFICIAL_DEB_SHA256_ARM64=.*|OFFICIAL_DEB_SHA256_ARM64='$arm64_sha'|" "$PINS"
fi

sed -i -E \
	-e "s|(^\s*url: ).*/claude-desktop_[^/]*\.deb$|\1$BASE/$amd64_file|" \
	-e "s|(^\s*sha256: )[0-9a-f]{64}$|\1$amd64_sha|" "$MANIFEST"
sed -i -E "s|<release version=\"[^\"]*\" date=\"[^\"]*\"/>|<release version=\"$version\" date=\"$(date -u +%F)\"/>|" "$METAINFO"

# The newest fedora:44 build image, riding along so each image move is tested with a release
image=$(cut -d@ -f1 "$ROOT/fork/fedora-image")
token=$(curl -fsS "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/fedora:pull" |
	grep -oP '"token":"\K[^"]+')
digest=$(curl -fsSI -H "Authorization: Bearer $token" \
	-H 'Accept: application/vnd.oci.image.index.v1+json' \
	-H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' \
	"https://registry-1.docker.io/v2/library/fedora/manifests/${image#*:}" |
	tr -d '\r' | grep -ioP '^docker-content-digest: \Ksha256:[0-9a-f]{64}$')
echo "$image@$digest" >"$ROOT/fork/fedora-image"

echo "Claude Desktop $version"
