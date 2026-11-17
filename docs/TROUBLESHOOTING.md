# Troubleshooting

## Top 5 build errors

### 1. `debootstrap` fails: "Release file … not found" / "Couldn't download packages" / GPG error
**Cause:** no internet, a proxy, a wrong mirror, or a missing archive keyring on the host.
**Fix:** `sudo apt install ubuntu-keyring ca-certificates`; test `curl -I http://archive.ubuntu.com/ubuntu/dists/noble/Release`. Behind a proxy export `http_proxy`/`https_proxy` and use `sudo -E`, or set `APT_PROXY`. Use a nearby mirror: `UBUNTU_MIRROR=http://<cc>.archive.ubuntu.com/ubuntu sudo -E ./build.sh`. If you pinned a snapshot, check the date exists (`DELUXE_SNAPSHOT=` empty to unpin).

### 2. "these packages have no install candidate in noble: …"
**Cause:** a name in `packages/packages.list` does not exist (or is in a component not enabled) on noble.
**Fix:** the hook lists *every* missing package at once. In a noble VM run `apt-cache policy <name>` / `apt-cache search <word>`; correct or delete the line. Components `main restricted universe multiverse` are enabled by default. For `firefox`/`codium` the cause is usually error 3.

### 3. Mozilla/VSCodium repo errors: "key fingerprint mismatch", `NO_PUBKEY`, 404, or "firefox resolved to Ubuntu's snap stub"
**Cause:** the key download failed, the vendor rotated its key, or the pin did not take effect.
**Fix:** rerun (transient). For a Mozilla fingerprint mismatch compare with Mozilla's documentation and update `MOZILLA_KEY_FPR` in `config.env` — **do not** just delete the check. VSCodium: run once, copy the fingerprint the build prints, and set `VSCODIUM_KEY_FPR` to pin it. Without network access to these hosts, remove `firefox` and `codium` from `packages.list` and install them later with the Welcome app/Flathub.

### 4. "No space left on device" during squashfs, or "ISO is N bytes, over the limit"
**Cause:** less than ~16 GB free, or the image grew past 4.7 GB.
**Fix:** free space or set `WORK=/bigdisk/build OUT=/bigdisk/out`. For size: move apps from `packages.list` to the Flatpak list in `welcome.py`, drop `libreoffice-draw`/language packs, keep `xz` (not `--quick`). `build/chroot` size is printed by `du -sh build/chroot`.

### 5. ISO boots to a GRUB prompt, "no such device", or "can't find /casper/vmlinuz"; UEFI doesn't list the stick
**Cause:** stick written by copying files instead of raw-writing; Rufus used in ISO mode; firmware needs Secure Boot off; an old stick with a stale partition table.
**Fix:** write with `dd`/Etcher or Rufus **DD mode**. Re-check `sha256sum`. If the kernel is missing, look for `kernel/initrd not found` earlier in the build log. As a last test, disable Secure Boot in firmware.

## Calamares

### A. Installer window never appears / "cannot connect to display"
Start from a terminal: `deluxe-installer`. It forces X11 (`QT_QPA_PLATFORM=xcb`) and grants root access to Xwayland temporarily. If `xhost` is missing: `sudo apt install x11-xserver-utils`. Log: `~/.cache/calamares/session.log` or `/root/.cache/calamares/session.log`.

### B. "Bootloader installation failed" on UEFI
Check the VM/firmware really booted in UEFI mode (`ls /sys/firmware/efi`). Make sure `shim-signed` and `grub-efi-amd64-signed` are in the image (they are in `packages.list`) and that an EFI System Partition (FAT32, 512 MB, `/boot/efi`) exists; with manual partitioning, create and flag it.

### C. Install with encryption does not boot / asks for the passphrase twice
`luksGenerator` is `luks1` because GRUB 2.12 cannot read LUKS2 with Argon2id. The `luksbootkeyfile` module should avoid the second prompt; if it still appears, confirm `/etc/crypttab` and `initramfs` ran (`grep -i crypt /var/log/installation.log`). A `/boot` partition outside the encrypted volume is an alternative layout for manual partitioning.

## Still stuck
Run the failing stage in isolation: hooks are plain scripts (`sudo chroot build/chroot /bin/bash`), and `build.sh` stops at the first error with the stage name printed in yellow.
