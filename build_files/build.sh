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
# Nautilus is the one GUI app baked as an RPM: it is not on Flathub and needs
# host gvfs (trash, mounts; gvfs-mtp for phones) rather than a sandbox. The
# other GNOME core apps (Loupe, Papers, Showtime, Decibels) are Flatpaks from
# the dotfiles Brewfile.
dnf5 install -y \
    niri \
    xwayland-satellite \
    greetd \
    tuigreet \
    ptyxis \
    nautilus \
    gvfs-mtp \
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

### Tailscale — RPM from the vendor repo (disabled after the build like the
### others: updates ride image rebuilds). tailscaled is enabled system-wide;
### node state lives in /var/lib/tailscale and survives image updates, so a
### machine only ever logs in once. That login is automated too:
### tailscale-autoconnect (system_files/usr/bin) runs from a user timer, and
### when tailscaled reports NeedsLogin it reads an auth key from 1Password
### and does `tailscale up` via a sudoers rule limited to that one command.
### Everything a phone reaches (Moshi/mosh) rides Tailscale — see README.
rpm --import https://pkgs.tailscale.com/stable/fedora/repo.gpg
curl -fsSL https://pkgs.tailscale.com/stable/fedora/tailscale.repo -o /etc/yum.repos.d/tailscale.repo
dnf5 install -y tailscale
dnf5 config-manager setopt tailscale-stable.enabled=0
systemctl enable tailscaled.service
chmod 0755 /usr/bin/tailscale-autoconnect
chmod 0440 /etc/sudoers.d/tailscale-autoconnect
visudo -cf /etc/sudoers.d/tailscale-autoconnect
systemctl --global enable tailscale-autoconnect.timer

### Bootstrap tools — the dotfiles flow is `git clone` + `make stow` before
### brew exists, so make and stow must come from the image.
dnf5 install -y make stow

### Homebrew prerequisites — Homebrew on Linux needs a system C toolchain
### (docs.brew.sh/Homebrew-on-Linux#requirements) even when everything is
### bottled: the gcc formula's post-install shells out to /usr/bin/cc to find
### glibc's crt*.o, and tap formulae without bottles (hashicorp/tap terraform,
### siderolabs/tap talosctl — plain binary downloads) refuse to install
### without one ("No developer tools installed").
dnf5 install -y gcc gcc-c++ glibc-devel

### Disaster-recovery tooling — homelab's scripts/op-vault-export.sh (and the
### restore path in its docs/1password-recovery.md) must work on a fresh
### machine BEFORE brew/dotfiles exist — that is exactly the scenario the
### export exists for — so its dependencies are baked rather than left to the
### Brewfile. age + jq come from Fedora; 1Password below. kubectl stays in
### the Brewfile: the script's cluster-marker refresh degrades to a warning
### without it.
dnf5 install -y age jq

### 1Password desktop + op CLI — RPMs from 1Password's repo, disabled after
### the build like the vscode repo below (updates ride image rebuilds). The
### desktop RPM needs the known ostree dance (recipe: rsturla/eternal-images,
### briorg/bluefin lineage):
###  - it installs into /opt/1Password, but /opt is a symlink to machine-local
###    /var/opt which is not shipped — relocate to /usr/lib/1Password and
###    recreate /opt/1Password as a boot-time tmpfiles.d symlink;
###  - its %post creates groups, but /etc/group is 3-way merged on deploy and
###    any real system has local edits, so image-built entries never land —
###    fixed-GID sysusers.d entries own the groups instead (created before the
###    install so the %post groupadds are no-ops at the same GIDs).
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

# Fixed GIDs: must be >1000 and never collide with real groups; normal user
# group GIDs are sequential from 1000, so park these well above.
GID_ONEPASSWORD=1790
GID_ONEPASSWORDCLI=1791
GID_ONEPASSWORDMCP=1792
cat >/usr/lib/sysusers.d/onepassword.conf <<EOF
g onepassword ${GID_ONEPASSWORD}
g onepassword-cli ${GID_ONEPASSWORDCLI}
g onepassword-mcp ${GID_ONEPASSWORDMCP}
EOF
systemd-sysusers /usr/lib/sysusers.d/onepassword.conf

# The %post also runs `mkdir -p /usr/local/bin` for its 1password-mcp symlink;
# during the build /usr/local dangles into /var, which makes mkdir -p (and so
# the whole dnf transaction) fail. Pre-create the target; the symlink it drops
# there is machine-local /var content that is not shipped either way.
mkdir -p "$(readlink -f /usr/local)/bin"
mkdir -p /var/opt
dnf5 install -y 1password 1password-cli
dnf5 config-manager setopt 1password.enabled=0

# Relocate out of unshipped /var/opt; /opt/1Password reappears at boot.
mv /var/opt/1Password /usr/lib/1Password
rm -f /usr/bin/1password
ln -s /opt/1Password/1password /usr/bin/1password
cat >/usr/lib/tmpfiles.d/onepassword.conf <<'EOF'
L  /opt/1Password  -  -  -  -  /usr/lib/1Password
EOF

# after-install.sh equivalent: setgid hardening on the helper binaries (no
# extra privileges — protects them from environmental tampering).
chgrp "${GID_ONEPASSWORD}" /usr/lib/1Password/1Password-BrowserSupport
chmod g+s /usr/lib/1Password/1Password-BrowserSupport
chgrp "${GID_ONEPASSWORDCLI}" /usr/bin/op
chmod g+s /usr/bin/op

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
