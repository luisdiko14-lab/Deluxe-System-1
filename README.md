# Deluxe System 1 — "Aurora" 1.0

A polished GNOME desktop built on **Ubuntu 24.04 LTS (noble)**. Boots as a live USB (UEFI incl. Secure Boot, and legacy BIOS) and installs to disk with a fully branded **Calamares** installer that has a full-disk-encryption (LUKS) checkbox.

```
sudo ./build.sh            # → out/deluxe-system-1-1.0-amd64.iso + .sha256 + .manifest
```

## Status — read this first

| Part | State |
|---|---|
| Static checks (bash syntax, Python compile, YAML/XML/SVG/.desktop parse) | done, pass |
| Artwork generator (logo, 5 wallpapers × light/dark, Plymouth, GRUB, Calamares images) | run, output inspected |
| ISO assembly (`make_boot_files` + `make_iso` from `build.sh`) with the real Canonical-signed shim/GRUB and a **stub** root filesystem | run, produced a hybrid ISO |
| **Full end-to-end build** (debootstrap → packages → squashfs → ISO) | **not run yet** — needs ~30 GB and 1–2 h |
| **Booting** the ISO (BIOS, UEFI, Secure Boot), Calamares install with/without LUKS, theme look | **not tested yet** — use [docs/VERIFY.md](docs/VERIFY.md) |

Package names were chosen for noble but not all were verified against the archive from here; `hooks/10-packages.sh` checks every package up front and lists *all* that are missing in one message, so a first build fails fast with an exact fix list (see [Troubleshooting](docs/TROUBLESHOOTING.md)).

## Why not live-build or Cubic? (deviation from the brief, deliberately)

The brief said "Cubic or live-build". `build.sh` instead drives the same underlying tools live-build uses — `debootstrap`, `mksquashfs`, `xorriso`, GRUB — directly. Reasons:

* **Reproducibility.** Cubic is a GUI with hand-made state: not scriptable. live-build is scriptable, but its Ubuntu support on a noble host depends on Debian-oriented defaults and extra patches; a plain script has no hidden behaviour to debug.
* **One auditable file.** Every step is visible in `build.sh` and `hooks/`.
* **Pinnable inputs.** `DELUXE_SNAPSHOT=20261101T000000Z` pins the Ubuntu archive via snapshot.ubuntu.com; `SOURCE_DATE_EPOCH`, sorted file lists and generated (deterministic) artwork complete it.

Honest limit: the **package set and file contents** are reproducible with a snapshot; the ISO is **not guaranteed bit-for-bit identical** (squashfs/file timestamps, random seeds). The shipped `.manifest` records exact package versions.

If you prefer live-build anyway, the `packages/`, `overlay/`, `hooks/`, `calamares/` directories are build-system-agnostic and can be dropped into a live-build `config/` tree.

## Decisions made with you

* **Installer:** Calamares (rebranded, slideshow, LUKS checkbox).
* **VS Code:** ships **VSCodium** (MIT). Microsoft VS Code and Microsoft core fonts are optional installs in the Welcome app (their licences are Microsoft's, not redistributed on the ISO).
* **ISO size:** base trimmed; **Inkscape and OBS Studio are Flatpaks** offered in the Welcome app (not on the disc) to stay under 4.7 GB. To bake them in, add `inkscape` / `obs-studio` to `packages/packages.list` (≈ +450 MB; the build fails if the ISO exceeds 4.7 GB).

## Project layout

```
build.sh                 single entry point (sudo ./build.sh [--quick] [--clean])
config.env               name/version/codename, mirrors, snapshot pin, size limits
packages/packages.list   everything installed          packages/remove.list  everything purged
hooks/00-prepare.sh      snap/telemetry blocks, Mozilla + VSCodium repos (fingerprint-checked)
hooks/10-packages.sh     install packages, purge bloat, divert os-release/lsb-release
hooks/20-branding.sh     Plymouth, GRUB fonts, icon caches, remove Ubuntu artwork
hooks/30-desktop.sh      schemas, dconf, GNOME Shell theme extraction, Flathub, GDM
hooks/40-system.sh       UFW, AppArmor, unattended-upgrades, TRIM, zram, preload, fast boot
hooks/50-installer.sh    install + verify Calamares config
hooks/90-cleanup.sh      initramfs, licence inventory, shrink, reset machine-id
overlay/                 files copied verbatim into the image (/etc, /usr/...)
  etc/                   os-release, lsb-release, issue, dconf defaults, sysctl, zram, grub.d, apt, udev…
  usr/local/bin/         deluxe-update  deluxe-theme  deluxe-installer  deluxe-welcome
  usr/share/themes/      Deluxe, Deluxe-dark (GTK3/4) + GNOME Shell overrides
  usr/share/deluxe/welcome/welcome.py    Welcome app (GTK4 + libadwaita)
  usr/share/plymouth|grub|backgrounds|pixmaps|icons   generated artwork + themes
calamares/               settings.conf, modules/*.conf, branding/deluxe (QML slideshow, QSS, images)
iso/grub/grub.cfg.in     live-ISO boot menu
tools/make-assets.py     generates ALL artwork (original, no Ubuntu/Canonical marks)
tools/test-qemu.sh       boot the ISO: bios | uefi | uefi-secure
tools/write-usb.sh       safe USB writer with checks + verification
docs/                    BUILD.md  VERIFY.md  TROUBLESHOOTING.md  LICENSES.md
```

## Docs

[BUILD.md](docs/BUILD.md) · [VERIFY.md](docs/VERIFY.md) · [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) · [LICENSES.md](docs/LICENSES.md)

## Placeholders to replace

`https://example.org/deluxe-system-1` appears in `config.env`, `overlay/usr/lib/os-release`, `overlay/etc/dpkg/origins/deluxe`, and `calamares/branding/deluxe/branding.desc`. Replace with your real project URL.

## Trademarks

"Ubuntu" and "Canonical" are trademarks of Canonical Ltd. Deluxe System 1 is an independent derivative; it uses no Ubuntu/Canonical logos or names as its identity (package and extension IDs such as `ubuntu-dock@ubuntu.com` are technical identifiers). Firefox is a Mozilla trademark and is installed unmodified from Mozilla's own APT repository.
