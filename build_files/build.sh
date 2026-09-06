#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### niri desktop stack — everything from Fedora repos
# base-main ships no desktop environment: niri is the only session, greetd +
# tuigreet is the login path, Ptyxis the terminal. xwayland-satellite is
# auto-spawned by niri for X11 clients. grim/slurp/swappy/zbar back the
# capture keybinds in dotfiles; ddcutil gives DMS external-monitor
# brightness over DDC/CI (i2c-dev loaded via /etc/modules-load.d).
dnf5 install -y \
    niri \
    xwayland-satellite \
    greetd \
    tuigreet \
    ptyxis \
    cliphist \
    wl-clipboard \
    grim \
    slurp \
    swappy \
    zbar \
    ddcutil \
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

### Bootstrap tools — the dotfiles flow is `git clone` + `make stow` before
### brew exists, so make and stow must come from the image.
dnf5 install -y make stow

### Disaster-recovery tooling — homelab's scripts/op-vault-export.sh (and the
### restore path in its docs/1password-recovery.md) must work on a fresh
### machine BEFORE brew/dotfiles exist — that is exactly the scenario the
### export exists for — so its dependencies are baked rather than left to the
### Brewfile. age + jq come from Fedora; the op CLI from 1Password's RPM repo,
### disabled after the build like the vscode repo below (updates ride image
### rebuilds). kubectl stays in the Brewfile: the script's cluster-marker
### refresh degrades to a warning without it.
dnf5 install -y age jq
rpm --import https://downloads.1password.com/linux/keys/1password.asc
cat >/etc/yum.repos.d/1password.repo <<'REPO'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
REPO
dnf5 install -y 1password-cli
dnf5 config-manager setopt 1password.enabled=0

### DMS first-run system check extras: tuned-ppd provides the
### power-profiles D-Bus API (battery/performance switching in the shell),
### cups-pk-helper lets the GUI manage printers (cups is already in the
### base), kf6-kimageformats gives Qt/quickshell extra wallpaper formats.
dnf5 install -y tuned-ppd cups-pk-helper kf6-kimageformats
systemctl enable tuned.service tuned-ppd.service

### DankMaterialShell — quickshell-based desktop shell (bar, launcher, lock,
### notifications). COPRs enabled for the build only, disabled in the image
### so machines don't track them outside image rebuilds.
dnf5 -y copr enable avengemedia/dms
dnf5 -y copr enable errornointernet/quickshell
dnf5 -y install dms quickshell
dnf5 -y copr disable avengemedia/dms
dnf5 -y copr disable errornointernet/quickshell

### VS Code — Microsoft repo RPM, baked in so devcontainers (podman) and
### terminal tooling run unsandboxed; extensions come from the dotfiles
### Brewfile. Repo disabled in the image: updates ride image rebuilds.
rpm --import https://packages.microsoft.com/keys/microsoft.asc
cat >/etc/yum.repos.d/vscode.repo <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
dnf5 install -y code
dnf5 config-manager setopt code.enabled=0

### Services
# greetd config in system_files/etc/greetd/config.toml starts tuigreet on vt1.
systemctl enable greetd.service
systemctl enable podman.socket
# DMS runs as a systemd user service (unit shipped by the dms rpm):
# restart-on-crash + journal logs. niri-session activates
# graphical-session.target, which pulls it in.
systemctl --global enable dms.service
