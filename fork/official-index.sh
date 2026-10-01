#!/usr/bin/env bash
# Anthropic's APT index, trusted only through their release signature:
#   InRelease  — clearsigned; gpgv against fork/anthropic-claude-desktop.asc, whose
#                fingerprint must be ANTHROPIC_FPR (the one Anthropic's install docs publish)
#   Packages   — SHA-256 must match the one listed in the verified InRelease
#   .deb       — SHA-256 must match the one listed in the verified Packages
#
# Usage:
#   fork/official-index.sh newest [arch]  print "version<TAB>pool-path<TAB>sha256" of the newest claude-desktop
#   fork/official-index.sh verify-pins    fail unless the pinned .deb (official-deb.sh and the
#                                         Flatpak manifest) is listed in the signed index
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BASE=https://downloads.claude.ai/claude-desktop/apt/stable
ANTHROPIC_FPR=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
KEY="$ROOT/fork/anthropic-claude-desktop.asc"
PINS="$ROOT/scripts/setup/official-deb.sh"
MANIFEST="$ROOT/fork/flatpak/io.github.celso_alexandre.ClaudeDesktop.yml"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

die() { echo "official-index: $*" >&2; exit 1; }

# Writes the verified Packages index for $1 to $TMP/Packages-$1
verified_packages() {
	local arch=$1 fpr listed actual
	fpr=$(gpg --batch --show-keys --with-colons "$KEY" 2>/dev/null | awk -F: '/^fpr/ {print $10; exit}')
	[[ $fpr == "$ANTHROPIC_FPR" ]] || die "$KEY is not Anthropic's key ($fpr)"
	gpg --batch --dearmor <"$KEY" >"$TMP/anthropic.gpg"

	curl -fsSL --retry 3 -o "$TMP/InRelease" "$BASE/dists/stable/InRelease"
	gpgv --keyring "$TMP/anthropic.gpg" --output "$TMP/Release" "$TMP/InRelease" 2>"$TMP/gpgv.log" ||
		{ cat "$TMP/gpgv.log" >&2; die "InRelease signature does not verify"; }

	listed=$(awk -v f="main/binary-$arch/Packages" '
		/^SHA256:/ {in_sha = 1; next}
		/^[^ ]/ {in_sha = 0}
		in_sha && $3 == f {print $1}' "$TMP/Release")
	[[ $listed =~ ^[0-9a-f]{64}$ ]] || die "no SHA256 for main/binary-$arch/Packages in InRelease"

	curl -fsSL --retry 3 -o "$TMP/Packages-$arch" "$BASE/dists/stable/main/binary-$arch/Packages"
	actual=$(sha256sum "$TMP/Packages-$arch" | cut -d' ' -f1)
	[[ $actual == "$listed" ]] || die "Packages ($arch) is $actual, signed index says $listed"
}

# version<TAB>filename<TAB>sha256 for every claude-desktop entry
entries() {
	awk -v RS='' '$2 == "claude-desktop" {
		v = f = s = ""
		n = split($0, l, "\n")
		for (i = 1; i <= n; i++) {
			if (l[i] ~ /^Version: /) v = substr(l[i], 10)
			else if (l[i] ~ /^Filename: /) f = substr(l[i], 11)
			else if (l[i] ~ /^SHA256: /) s = substr(l[i], 9)
		}
		if (v != "" && f != "" && s != "") printf "%s\t%s\t%s\n", v, f, s
	}' "$1"
}

case ${1:-} in
newest)
	arch=${2:-amd64}
	verified_packages "$arch"
	entries "$TMP/Packages-$arch" | sort -V -k1,1 | tail -1
	;;
verify-pins)
	verified_packages amd64
	pool=$(grep -oP "^OFFICIAL_DEB_POOL_AMD64='\K[^']+" "$PINS")
	sha=$(grep -oP "^OFFICIAL_DEB_SHA256_AMD64='\K[^']+" "$PINS")
	entries "$TMP/Packages-amd64" | awk -F'\t' -v f="$pool" -v s="$sha" '$2 == f && $3 == s {ok = 1} END {exit !ok}' ||
		die "pinned $pool ($sha) is not in Anthropic's signed index"
	grep -qF "url: $BASE/$pool" "$MANIFEST" && grep -qF "sha256: $sha" "$MANIFEST" ||
		die "the Flatpak manifest does not pin the same .deb as official-deb.sh"
	echo "pinned $pool is in Anthropic's signed index ($sha)"
	;;
*)
	sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2
	exit 2
	;;
esac
