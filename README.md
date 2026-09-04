# ublue-niri

Custom [bootc](https://bootc-dev.github.io/bootc/) image for my laptop:
[Universal Blue base-main](https://github.com/orgs/ublue-os/packages) (DE-less
Fedora Atomic) + [niri](https://github.com/niri-wm/niri) +
[DankMaterialShell](https://danklinux.com/docs/dankmaterialshell).

Built from [ublue-os/image-template](https://github.com/ublue-os/image-template).
GitHub Actions builds daily and on push to `main`, publishing to
`ghcr.io/sometimeskind/ublue-niri:latest` (cosign-signed, key in
`cosign.pub`).

## What's in the image

- **niri** (Fedora repos) with **xwayland-satellite** for X11 clients
- **DankMaterialShell** + **quickshell** (COPRs `avengemedia/dms`,
  `errornointernet/quickshell` — enabled at build time only) and **matugen**
- **greetd + tuigreet** login on vt1 (`system_files/etc/greetd/config.toml`) —
  base-main has no display manager or fallback session
- **Ptyxis** terminal, **cliphist**/**wl-clipboard**, **zsh**
- Capture: **grim**/**slurp**/**swappy** (region → annotate) and **zbar**
  (on-screen QR decode); **ddcutil** for external-monitor brightness via DMS
- `system-update` — bootc + Flatpak + brew updates in one command
- **make**/**stow** so the dotfiles bootstrap works before brew is installed
- **VS Code** (Microsoft repo RPM, repo disabled after install — updates come
  with image rebuilds; extensions via the dotfiles Brewfile)
- A DMS CLI policy (`/usr/share/dms/cli-policy.json`) re-enabling `dms setup`
  on this ostree image — upstream blocks it wholesale on immutable systems;
  only the greeter subcommands stay blocked (greetd is baked in)
- Fonts: CaskaydiaCove Nerd Font (`cascadia-code-nf-fonts`), Inter
  (`rsms-inter-fonts`)

User-level config (niri config.kdl, DMS setup, shell) comes from
[sometimeskind/dotfiles](https://github.com/sometimeskind/dotfiles) (Stow);
GUI apps (Zen browser etc.) via Flatpak per its Brewfile.

## Consuming the image

From any Fedora Atomic/bootc install:

```bash
sudo bootc switch ghcr.io/sometimeskind/ublue-niri:latest
# or on rpm-ostree systems:
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/sometimeskind/ublue-niri:latest
```

Then follow the dotfiles README ("Fedora Atomic laptop" section) for the home
directory: flathub remote + Zen flatpak, brew, stow, `dms setup`.

## Working on this repo

- `just build ublue-niri latest` — local container build (needs podman)
- `just build-qcow2` / `just run-vm-qcow2` — build and boot a test VM
- Base image digest and Actions pins are Renovate-managed
  (`.github/renovate.json5`)
- `build_files/build.sh` is the package/service layer;
  `system_files/` is copied verbatim onto `/`

Branch + PR for every change; PR builds validate the image without
publishing. Pushes to `main` publish and sign — `SIGNING_SECRET` (cosign
private key) must exist as an Actions secret or the publish job fails.
