#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### niri desktop stack — everything from Fedora repos
# base-main ships no desktop environment: niri is the only session, greetd +
# tuigreet is the login path, Ptyxis the terminal. xwayland-satellite is
# auto-spawned by niri for X11 clients.
dnf5 install -y \
    niri \
    xwayland-satellite \
    greetd \
    tuigreet \
    ptyxis \
    cliphist \
    wl-clipboard \
    matugen \
    cascadia-code-nf-fonts \
    rsms-inter-fonts \
    zsh \
    mosh

### moshi-hook — Moshi phone-app bridge (agent approvals, SSH/Mosh hosting).
# Single static Go binary, no Fedora package. Fetched from the vendor CDN with
# checksum verification; the daily image rebuild tracks releases, so the
# self-updater (which couldn't write /usr anyway) is not needed. mosh above is
# baked as an RPM rather than left to the dotfiles Brewfile so inbound mosh
# finds /usr/bin/mosh-server on the default PATH of a non-interactive SSH exec.
# Per-user setup (config, pairing, daemon) stays a first-login step — see README.
MOSHI_VERSION="$(curl -fsSL https://cdn.getmoshi.app/hook/latest/version.txt | tr -d '[:space:]')"
MOSHI_BASE="https://cdn.getmoshi.app/hook/${MOSHI_VERSION}"
curl -fsSL "${MOSHI_BASE}/moshi-hook_Linux_x86_64.tar.gz" -o /tmp/moshi-hook.tgz
expected="$(curl -fsSL "${MOSHI_BASE}/checksums.txt" | grep 'moshi-hook_Linux_x86_64.tar.gz$' | awk '{print $1}')"
echo "${expected}  /tmp/moshi-hook.tgz" | sha256sum -c -
tar -xzf /tmp/moshi-hook.tgz -C /tmp moshi-hook
install -m 755 /tmp/moshi-hook /usr/bin/moshi-hook
# the installer normally creates both names; moshi = web client / tmux attach mode
ln -sf moshi-hook /usr/bin/moshi
rm -f /tmp/moshi-hook.tgz /tmp/moshi-hook

### DankMaterialShell — quickshell-based desktop shell (bar, launcher, lock,
### notifications). COPRs enabled for the build only, disabled in the image
### so machines don't track them outside image rebuilds.
dnf5 -y copr enable avengemedia/dms
dnf5 -y copr enable errornointernet/quickshell
dnf5 -y install dms quickshell
dnf5 -y copr disable avengemedia/dms
dnf5 -y copr disable errornointernet/quickshell

### Services
# greetd config in system_files/etc/greetd/config.toml starts tuigreet on vt1.
systemctl enable greetd.service
systemctl enable podman.socket
