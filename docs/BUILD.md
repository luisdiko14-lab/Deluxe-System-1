# Build, test and write to USB

## 1. Build

Needs: Ubuntu 24.04 amd64 (VM is fine), ≥ 18 GB free disk (≈ 30 GB with KEEP_CHROOT=1), 4+ GB RAM, internet. `build.sh` installs its own host dependencies.

```bash
git clone https://github.com/luisdiko14-lab/deluxe-system-1 && cd deluxe-system-1
sudo ./build.sh              # release build: xz squashfs (smallest, slow: 30–90 min)
sudo ./build.sh --quick      # zstd squashfs: much faster, ISO a few hundred MB bigger (testing)
sudo ./build.sh --clean      # wipe build/ and out/ first
```

Useful variables (put before `sudo -E`): `DELUXE_SNAPSHOT=20261101T000000Z` (pin the archive), `APT_PROXY=http://localhost:3142` (apt-cacher-ng), `UBUNTU_MIRROR=…`, `VSCODIUM_KEY_FPR=<fingerprint printed by a previous build>`.

Output in `out/`: `deluxe-system-1-1.0-amd64.iso`, `…iso.sha256`, `…manifest` (every package + version).

What each stage does: **assets** (generate artwork) → **bootstrap** (debootstrap noble) → **00-prepare** (block snap/telemetry, add Mozilla + VSCodium repos) → **10-packages** → overlay copy → **20-branding** → **30-desktop** → **40-system** → **50-installer** → **90-cleanup** → kernel/initrd → squashfs → GRUB BIOS + signed-shim UEFI boot files → hybrid ISO (`xorriso`) → size check (< 4.7 GB) + SHA-256.

Re-running is safe: the chroot is rebuilt from scratch every time (debootstrap's download cache in `build/cache` makes it faster).

Verify the download: `sha256sum -c deluxe-system-1-1.0-amd64.iso.sha256`.

## 2. Test in QEMU

```bash
sudo apt install qemu-system-x86 ovmf
./tools/test-qemu.sh bios          # legacy BIOS
./tools/test-qemu.sh uefi          # UEFI
./tools/test-qemu.sh uefi-secure   # UEFI with Secure Boot enabled (Microsoft keys)
```
Remove `-enable-kvm -cpu host` in the script if the host has no KVM (it will be slow).
To test installation, keep the same `/tmp/deluxe-test.qcow2` disk, install, then boot from the disk without `-cdrom`.

## 3. Test in VirtualBox

1. *New* → Type Linux, Version *Ubuntu (64-bit)*, ≥ 4 GB RAM, 2+ CPUs, 40 GB disk.
2. *Settings → System → Motherboard*: tick **Enable EFI** to test UEFI; leave unticked for BIOS. (VirtualBox's EFI has no Secure Boot by default.)
3. *Settings → Display*: Graphics controller **VMSVGA**, 128 MB video memory, 3D acceleration on.
4. *Storage*: attach the ISO to the optical drive. Start the VM.
5. Wi-Fi cannot be tested in a VM (virtual NIC only) — test it on real hardware.

## 4. Write to a USB stick (≥ 8 GB)

The ISO is a *hybrid* image: write it raw, don't copy files onto the stick.

* **Linux (checked script):** `sudo ./tools/write-usb.sh /dev/sdX` — refuses system and non-USB disks, verifies the checksum before and the written data after. Find the device with `lsblk`.
* **Linux (plain dd):**
  `sudo dd if=out/deluxe-system-1-1.0-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync conv=fsync` — double-check `/dev/sdX`; the wrong device is destroyed.
* **balenaEtcher (Windows/macOS/Linux):** *Flash from file* → pick the ISO → pick the USB drive → *Flash*.
* **Rufus (Windows):** select the ISO, Partition scheme **GPT** for UEFI machines or **MBR** for legacy BIOS, click Start and choose **Write in DD Image mode** when asked (not ISO mode).

Boot it: open the firmware boot menu (F12 / F10 / Esc / F2 depending on vendor) and choose the USB. With Secure Boot on, it works with the signed shim; if the firmware complains, accept the "Deluxe/Ubuntu" boot entry or disable Secure Boot.

## 5. Live session

User `deluxe`, no password (auto-login; `sudo` needs no password). Double-click **Install Deluxe System 1** on the desktop. In the partition step tick **Encrypt system** for full-disk encryption (LUKS).
