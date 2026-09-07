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
- **gcc**/**gcc-c++**/**glibc-devel** — Homebrew on Linux needs a system C
  toolchain even for bottled formulae (its gcc post-install shells out to
  `/usr/bin/cc`; tap formulae without bottles refuse to install without one)
- NVIDIA's **GeForce NOW** Flatpak remote, preconfigured via
  `/etc/flatpak/remotes.d/GeForceNOW.flatpakrepo` — the dotfiles Brewfile
  installs `com.nvidia.geforcenow` from it
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

### Moshi (phone) access

`mosh` (client + server) and `moshi-hook`/`moshi` are baked into the image —
mosh as an RPM so inbound sessions find `/usr/bin/mosh-server` on the default
SSH-exec PATH, moshi-hook fetched checksum-verified from the vendor CDN at
image build (the daily rebuild tracks releases; `moshi-hook update` doesn't
apply on immutable `/usr`). The hardened `~/.config/moshi/config.toml`
(discovery/telemetry off) is pre-seeded via `/etc/skel` for users created on
this image; a pre-existing user (rebase case) must copy it from
`/etc/skel/.config/moshi/config.toml` **before** first running the daemon.
The firewalld `public` zone (`system_files/etc/firewalld/zones/public.xml`)
adds the `mosh` service (UDP 60000-61000) next to `ssh`; a machine that has
already edited the zone with `firewall-cmd --permanent` keeps its own copy
and must add the service itself.
Then, per user:

```bash
moshi-hook pair --token <token from Moshi app: Settings -> Hooks>
moshi-hook install          # writes agent hook configs
moshi-hook service install  # user systemd unit for the daemon
moshi-hook host setup       # Easy Pair SSH/Mosh access (enables sshd as needed;
                            # reachability from the phone is via Tailscale)
```

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
