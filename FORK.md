# Claude Desktop for Fedora, Flatpak and AppImage (celso-alexandre fork)

Anthropic's official Claude Desktop for Linux ships only as a `.deb`. This fork repacks
that `.deb` into three formats and publishes them from this repository only: packages on
GitHub Releases, the dnf and Flatpak repos on GitHub Pages. There is no third-party package
host, CDN or signing key.

Packages and repo metadata are signed with this fork's key
(`F4E3 86FF 1A06 E49B 2D02  FB72 B072 862E 877E B4A6`, also in [`fork/KEY.gpg`](fork/KEY.gpg)).

## What is verified

- **Anthropic's `.deb`**: [`fork/official-index.sh`](fork/official-index.sh) checks the signed
  `InRelease` of Anthropic's APT repo with `gpgv` against their release key
  ([`fork/anthropic-claude-desktop.asc`](fork/anthropic-claude-desktop.asc), fingerprint
  `31DD DE24 DDFA B679 F42D  7BD2 BAA9 29FF 1A7E CACE`, as published in their install docs),
  then the `Packages` index against the signed hash, then the `.deb` hash against the index.
  The weekly update only takes versions from that verified index, every build re-checks the
  pin against it, and the build itself refuses a `.deb` whose SHA-256 differs from the pin.
- **The app is Anthropic's, unmodified**: CI builds with `CLAUDE_OFFICIAL_ASAR=1`, so none of
  upstream's `app.asar` patches are applied and `app.asar` ships byte-identical; no npm
  package is installed at build time ([`fork/asar-read.js`](fork/asar-read.js) reads
  `package.json` instead). The RPM and AppImage add upstream's launcher (`claude-desktop-unofficial`,
  plus `--doctor`); the Flatpak adds only a two-line wrapper.
- **Checked on every build**: [`fork/verify-official-app.sh`](fork/verify-official-app.sh) compares
  the built RPM, AppImage and Flatpak against the pinned `.deb`: all of Anthropic's files must be
  byte-identical, and the only extra files allowed are the launcher's `launcher-common.sh` and
  `doctor.sh` (the Flatpak may only drop `chrome-sandbox`, which zypak replaces).
- **Build tools are pinned**: `appimagetool` 1.9.1 and the type2 runtime 20251108 by SHA-256;
  the Fedora build image by digest ([`fork/fedora-image`](fork/fedora-image), moved with each
  release); Node.js from Fedora's own signed package for the RPM; GitHub actions by commit.

## The launcher (RPM and AppImage)

Upstream's launcher was reviewed line by line, together with `--doctor` and the RPM scriptlets:
no network access at startup, no telemetry, the config file
(`~/.config/claude-desktop-debian/environment`) is parsed for allowlisted keys and never executed,
`--doctor` is read-only (one anonymous GET of Anthropic's public package index). The RPM's root
scriptlets only refresh the desktop database and add a firmware symlink for Cowork when none exists.

Behaviours to know:
- **Chromium sandbox**: on in the RPM (this fork launches it as `rpm`, so upstream's Ubuntu-only
  Wayland `--no-sandbox` workaround does not apply) and in the Flatpak (zypak). The AppImage always
  runs with `--no-sandbox`: it cannot carry the setuid helper.
- At each start the launcher kills leftover Claude helper processes of your user, matched by
  command-line substrings (`cowork-vm-service.js`, `cowork-linux-helper`,
  `~/.config/Claude/Claude Extensions/`, `/usr/lib/claude-desktop/…--type=`).
- It keeps up to 5 copies of `~/.config/Claude/claude_desktop_config.json` (which can hold MCP
  secrets) in `~/.cache/claude-desktop-debian/config-backups/`.

## Install

### Fedora / RHEL (dnf): updates with your other packages

```bash
sudo curl -fsSLo /etc/yum.repos.d/claude-desktop.repo https://celso-alexandre.github.io/claude-desktop/claude-desktop.repo
sudo dnf install claude-desktop-unofficial
```

The first install asks to import the key above; check the fingerprint. Updates then arrive
through `dnf upgrade` and Discover / GNOME Software like any other package.

Cowork (the agentic VM tab) also needs `sudo dnf install qemu-kvm edk2-ovmf virtiofsd`.

### Any distro (Flatpak): updates with your other Flatpaks

```bash
flatpak install --user https://celso-alexandre.github.io/claude-desktop/io.github.celso_alexandre.ClaudeDesktop.flatpakref
```

Chat works fully. The **Code** tab sees the Flatpak runtime, not your system's toolchain,
and **Cowork** is unavailable (no QEMU in the sandbox): use the RPM on dev machines.

### Any distro (AppImage)

Download `claude-desktop-unofficial-*-amd64.AppImage` from the
[latest release](https://github.com/celso-alexandre/claude-desktop/releases/latest).
It carries update information for this fork's releases, so Gear Lever or AppImageUpdate
keeps it current.

## How it stays current

- **Weekly** ([`fork-check-update.yml`](.github/workflows/fork-check-update.yml)): if
  Anthropic's APT repo has a newer `claude-desktop`, [`fork/check-update.sh`](fork/check-update.sh)
  bumps the pinned `.deb` (URL and SHA-256) for all three formats and opens a PR on
  `auto/update-claude`.
- **Build** ([`fork-build.yml`](.github/workflows/fork-build.yml)): builds the RPM (Fedora 44),
  AppImage and Flatpak; installs and launches each one headless. The update PR is merged
  when all pass; main then signs the packages, creates the release and publishes the repos
  ([`fork/site.sh`](fork/site.sh)).
- **Upstream** ([`fork-sync-upstream.yml`](.github/workflows/fork-sync-upstream.yml)): weekly
  PR with aaddrick/claude-desktop-debian's changes (launcher, patches, packaging). Tested,
  but **never merged automatically**: review it.

Upstream's own workflows (their triage bot, Cloudflare Worker, apt/AUR publishing) are
removed here, and the sync keeps them out.

Secrets: `PKG_GPG_PRIVATE_KEY` (armored secret key), `PKG_GPG_KEY_ID` (its fingerprint).
