#!/usr/bin/env bash
# Sign the packages and assemble the GitHub Pages site that serves both repos:
#   rpm/                        dnf metadata; the .rpm itself stays on the GitHub release (xml:base)
#   repo/                       Flatpak (OSTree) repo, imported from the bundle
#   claude-desktop.repo         drop into /etc/yum.repos.d/
#   claude-desktop.flatpakrepo  / <app-id>.flatpakref
#   KEY.gpg                     the signing key, for dnf and for checking by hand
# The .rpm in <dist> is signed in place, so upload it to the release after this runs.
# Usage: fork/site.sh <dist-dir> <release-tag> <gpg-key-id> <out-dir>
# Needs: gpg with the secret key imported, rpm-sign, createrepo_c, flatpak; GITHUB_REPOSITORY.
set -euo pipefail

DIST=$(realpath "$1") TAG=$2 KEY=$3 OUT=$(realpath -m "$4")
APP_ID=io.github.celso_alexandre.ClaudeDesktop
OWNER=${GITHUB_REPOSITORY%%/*} NAME=${GITHUB_REPOSITORY#*/}
SITE="https://$OWNER.github.io/$NAME"
RELEASE="https://github.com/$GITHUB_REPOSITORY/releases/download/$TAG/"

rm -rf "$OUT" && mkdir -p "$OUT/rpm"
gpg --batch --armor --export "$KEY" >"$OUT/KEY.gpg"
KEY_B64=$(gpg --batch --export "$KEY" | base64 -w0)

# --- RPM ---
rpmsign --define "_gpg_name $KEY" --addsign "$DIST"/*.rpm
rpm --import "$OUT/KEY.gpg"
rpm -K "$DIST"/*.rpm
createrepo_c --baseurl "$RELEASE" --outputdir "$OUT/rpm" "$DIST"
gpg --batch --yes --armor --detach-sign -u "$KEY" "$OUT/rpm/repodata/repomd.xml"
cat >"$OUT/claude-desktop.repo" <<EOF
[claude-desktop]
name=Claude Desktop ($GITHUB_REPOSITORY, repacked from Anthropic's official build)
baseurl=$SITE/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$SITE/KEY.gpg
metadata_expire=6h
EOF

# --- Flatpak ---
ostree init --mode=archive-z2 --repo="$OUT/repo"
flatpak build-import-bundle --gpg-sign="$KEY" "$OUT/repo" "$DIST"/*.flatpak
flatpak build-update-repo --gpg-sign="$KEY" --generate-static-deltas --prune "$OUT/repo"
cat >"$OUT/claude-desktop.flatpakrepo" <<EOF
[Flatpak Repo]
Title=Claude Desktop (unofficial repack)
Url=$SITE/repo/
Homepage=https://github.com/$GITHUB_REPOSITORY
Comment=Anthropic's official Claude Desktop Linux build, repacked as a Flatpak
GPGKey=$KEY_B64
EOF
cat >"$OUT/$APP_ID.flatpakref" <<EOF
[Flatpak Ref]
Name=$APP_ID
Branch=stable
Title=Claude Desktop (unofficial repack)
Url=$SITE/repo/
SuggestRemoteName=claude-desktop
RuntimeRepo=https://flathub.org/repo/flathub.flatpakrepo
IsRuntime=false
GPGKey=$KEY_B64
EOF

du -sh "$OUT"/*
