# Claude Desktop for Fedora, Flatpak and AppImage (celso-alexandre fork)

Anthropic's official Claude Desktop for Linux ships only as a `.deb`. This fork repacks
that `.deb`, checked against the SHA-256 in Anthropic's own APT index, into three formats
and publishes them from this repository only: packages on GitHub Releases, the dnf and
Flatpak repos on GitHub Pages. There is no third-party package host, CDN or signing key.

Packages and repo metadata are signed with this fork's key
(`F4E3 86FF 1A06 E49B 2D02  FB72 B072 862E 877E B4A6`, also in [`fork/KEY.gpg`](fork/KEY.gpg)).

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
