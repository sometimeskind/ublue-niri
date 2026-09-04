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
    zsh

### Bootstrap tools — the dotfiles flow is `git clone` + `make stow` before
### brew exists, so make and stow must come from the image.
dnf5 install -y make stow

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
