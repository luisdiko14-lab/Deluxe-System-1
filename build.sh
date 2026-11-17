#!/usr/bin/env bash
#
# Deluxe System 1 "Aurora" — ISO build script
# ---------------------------------------------------------------------------
# Builds deluxe-system-1-1.0-amd64.iso (+ .sha256, .manifest) from Ubuntu 24.04 (noble).
# Hybrid BIOS + UEFI (Secure Boot capable: Canonical-signed shim + GRUB + kernel).
#
# Run on a fresh Ubuntu 24.04 amd64 machine or VM with ~18 GB free disk (low-disk mode; set KEEP_CHROOT=1 to keep the chroot, needs ~30 GB) and internet:
#     sudo ./build.sh                # normal release build (xz, smallest ISO)
#     sudo ./build.sh --quick        # zstd compression, much faster, bigger ISO (for testing)
#     sudo ./build.sh --clean        # delete ./build and ./out first
#
# Idempotent: the chroot is rebuilt from scratch on every run (debootstrap's package
# cache in ./build/cache makes re-runs fast); outputs are overwritten.
# ---------------------------------------------------------------------------
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$ROOT/config.env"

WORK="${WORK:-$ROOT/build}"
OUT="${OUT:-$ROOT/out}"
CHROOT="$WORK/chroot"
IMAGE="$WORK/image"
CACHE="$WORK/cache"
ISO_NAME="${DELUXE_ISO_BASENAME}-${DELUXE_VERSION}-amd64.iso"
[[ "${SKIP_THIRD_PARTY:-0}" == "1" ]] && ISO_NAME="${DELUXE_ISO_BASENAME}-${DELUXE_VERSION}-amd64-nothirdparty.iso"

DO_CLEAN=0
for arg in "$@"; do
  case "$arg" in
    --clean) DO_CLEAN=1 ;;
    --quick) SQUASHFS_COMP=zstd ;;
    -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 0. Root + sanity checks
# ---------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

umount_chroot() {
  local m
  for m in run sys proc dev/pts dev; do
    mountpoint -q "$CHROOT/$m" 2>/dev/null && umount -lf "$CHROOT/$m" || true
  done
}
trap 'rc=$?; umount_chroot; [[ $rc -ne 0 ]] && echo -e "\n\033[1;31mBuild failed (exit $rc). See docs/TROUBLESHOOTING.md\033[0m" >&2; exit $rc' EXIT

preflight() {
  log "Preflight checks"
  [[ "$(uname -m)" == "x86_64" ]] || die "build host must be x86_64"
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
    [[ "${FORCE:-0}" == "1" ]] || die "build host must be Ubuntu 24.04 (found ${PRETTY_NAME:-unknown}). Set FORCE=1 to override at your own risk."
  fi
  command -v curl >/dev/null || { apt-get update -qq && apt-get install -y -qq curl ca-certificates; }
  mkdir -p "$WORK"
  local free_gb
  free_gb=$(df --output=avail -BG "$WORK" | tail -1 | tr -dc '0-9')
  (( free_gb >= MIN_FREE_GB )) || die "need ${MIN_FREE_GB} GB free in $WORK, have ${free_gb} GB"
  # debootstrap needs device nodes + exec: fix a nodev/noexec work dir (e.g. Codespaces /workspaces).
  local mp opts
  mp=$(findmnt -n -o TARGET -T "$WORK" 2>/dev/null || true)
  opts=$(findmnt -n -o OPTIONS -T "$WORK" 2>/dev/null || true)
  if [[ -n "$mp" && ( ",$opts," == *,nodev,* || ",$opts," == *,noexec,* ) ]]; then
    info "$WORK is on $mp mounted with ($opts); trying to remount with dev,exec"
    if ! mount -o remount,dev,exec,suid "$mp" 2>/dev/null; then
      local alt="/var/tmp/deluxe-build" altfree
      mkdir -p "$alt"
      altfree=$(df --output=avail -BG "$alt" | tail -1 | tr -dc '0-9')
      if findmnt -n -o OPTIONS -T "$alt" | grep -qE '(^|,)(nodev|noexec)(,|$)' || (( altfree < MIN_FREE_GB )); then
        die "$WORK is mounted nodev/noexec and cannot be fixed. Use WORK=<dir on a normal filesystem with >= ${MIN_FREE_GB} GB free>."
      fi
      info "remount failed; using WORK=$alt (${altfree} GB free)"
      WORK="$alt"; CHROOT="$WORK/chroot"; IMAGE="$WORK/image"; CACHE="$WORK/cache"
    fi
  fi
  # shellcheck disable=SC2015
  curl -fsI --max-time 15 "$UBUNTU_MIRROR/dists/$UBUNTU_SUITE/Release" >/dev/null 2>&1 \
    || [[ -n "$DELUXE_SNAPSHOT" ]] || die "cannot reach $UBUNTU_MIRROR (no internet?)"
}

install_host_deps() {
  log "Installing build dependencies on the host"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends \
    debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools dosfstools \
    librsvg2-bin python3 rsync ca-certificates curl gnupg xz-utils zstd git \
    >/dev/null
}

# ---------------------------------------------------------------------------
# 1. Reproducibility inputs
# ---------------------------------------------------------------------------
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null || stat -c %Y "$ROOT/config.env")}"
export SOURCE_DATE_EPOCH
BUILD_MIRROR="$UBUNTU_MIRROR"
[[ -n "$DELUXE_SNAPSHOT" ]] && BUILD_MIRROR="https://snapshot.ubuntu.com/ubuntu/$DELUXE_SNAPSHOT"

# ---------------------------------------------------------------------------
# 2. Branding assets (logo, wallpapers, plymouth/grub/calamares images)
# ---------------------------------------------------------------------------
build_assets() {
  log "Generating logo, wallpapers and boot/installer artwork (deterministic)"
  python3 "$ROOT/tools/make-assets.py"
}

# ---------------------------------------------------------------------------
# 3. Bootstrap the base system
# ---------------------------------------------------------------------------
bootstrap() {
  log "Bootstrapping Ubuntu $UBUNTU_SUITE from $BUILD_MIRROR"
  umount_chroot
  rm -rf "$CHROOT"
  mkdir -p "$CHROOT" "$CACHE"
  debootstrap --arch=amd64 --variant=minbase \
    --components=main,restricted,universe,multiverse \
    --include=ca-certificates,gnupg,curl,locales,apt-utils,dirmngr \
    --cache-dir="$CACHE" \
    "$UBUNTU_SUITE" "$CHROOT" "$BUILD_MIRROR"
}

mount_chroot() {
  mkdir -p "$CHROOT"/{dev,proc,sys,run}
  mountpoint -q "$CHROOT/dev"     || mount --bind /dev "$CHROOT/dev"
  mountpoint -q "$CHROOT/dev/pts" || mount -t devpts devpts "$CHROOT/dev/pts"
  mountpoint -q "$CHROOT/proc"    || mount -t proc proc "$CHROOT/proc"
  mountpoint -q "$CHROOT/sys"     || mount -t sysfs sysfs "$CHROOT/sys"
  mountpoint -q "$CHROOT/run"     || mount -t tmpfs tmpfs "$CHROOT/run"
}

prepare_chroot() {
  log "Preparing chroot (APT sources, DNS, build payload)"
  rm -f "$CHROOT/etc/apt/sources.list"
  mkdir -p "$CHROOT/etc/apt/sources.list.d"
  cat > "$CHROOT/etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: $BUILD_MIRROR
Suites: $UBUNTU_SUITE ${UBUNTU_SUITE}-updates ${UBUNTU_SUITE}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
  [[ -n "$APT_PROXY" ]] && echo "Acquire::http::Proxy \"$APT_PROXY\";" > "$CHROOT/etc/apt/apt.conf.d/01proxy"
  rm -f "$CHROOT/etc/resolv.conf"
  cp -L /etc/resolv.conf "$CHROOT/etc/resolv.conf"
  echo "deluxe-live" > "$CHROOT/etc/hostname"

  rm -rf "$CHROOT/tmp/deluxe-build"
  mkdir -p "$CHROOT/tmp/deluxe-build"
  rsync -a "$ROOT/config.env" "$ROOT/packages" "$ROOT/hooks" "$ROOT/calamares" "$CHROOT/tmp/deluxe-build/"
}

run_hook() {
  local hook="$1"
  log "chroot hook: $hook"
  chroot "$CHROOT" /usr/bin/env -i \
    HOME=/root TERM=xterm \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 \
    SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" \
    DELUXE_SNAPSHOT="$DELUXE_SNAPSHOT" SKIP_THIRD_PARTY="${SKIP_THIRD_PARTY:-0}" \
    /bin/bash -eu -o pipefail "/tmp/deluxe-build/hooks/$hook"
}

apply_overlay() {
  log "Copying overlay (configs, themes, scripts) into the image"
  rsync -aH --chown=root:root "$ROOT/overlay/" "$CHROOT/"
}

# ---------------------------------------------------------------------------
# 4. Build the ISO tree
# ---------------------------------------------------------------------------
pick_first() { # echo the first existing path from the arguments
  local p
  for p in "$@"; do [[ -e "$p" ]] && { echo "$p"; return 0; }; done
  return 1
}

make_image_tree() {
  log "Assembling ISO tree"
  rm -rf "$IMAGE"
  mkdir -p "$IMAGE"/{casper,boot/grub/i386-pc,boot/grub/x86_64-efi,boot/grub/theme,.disk,EFI/boot}

  local kernel initrd
  kernel=$(ls -1 "$CHROOT"/boot/vmlinuz-* | sort -V | tail -n1)
  initrd="${kernel/vmlinuz/initrd.img}"
  [[ -f "$kernel" && -f "$initrd" ]] || die "kernel/initrd not found in chroot /boot"
  info "kernel: $(basename "$kernel")"
  cp "$kernel" "$IMAGE/casper/vmlinuz"
  cp "$initrd" "$IMAGE/casper/initrd"
  chmod 0644 "$IMAGE/casper/vmlinuz" "$IMAGE/casper/initrd"

  # Package manifest (also the reproducibility record of exactly what shipped)
  chroot "$CHROOT" dpkg-query -W --showformat='${Package}\t${Version}\n' > "$IMAGE/casper/filesystem.manifest"
  grep -E '^(casper|calamares)' "$IMAGE/casper/filesystem.manifest" | cut -f1 > "$IMAGE/casper/filesystem.manifest-remove" || true
}

make_squashfs() {
  log "Compressing root filesystem (squashfs, $SQUASHFS_COMP) — this is the slow step"
  umount_chroot
  du -sx --block-size=1 "$CHROOT" | cut -f1 > "$IMAGE/casper/filesystem.size"
  local opts=()
  case "$SQUASHFS_COMP" in
    xz)   opts=(-comp xz -b 1M -Xdict-size 100% -Xbcj x86) ;;
    zstd) opts=(-comp zstd -b 1M -Xcompression-level 3) ;;
    *) die "SQUASHFS_COMP must be xz or zstd" ;;
  esac
  mksquashfs "$CHROOT" "$IMAGE/casper/filesystem.squashfs" \
    -noappend -no-progress -no-recovery -mkfs-time "$SOURCE_DATE_EPOCH" "${opts[@]}"
  info "squashfs size: $(du -h "$IMAGE/casper/filesystem.squashfs" | cut -f1)"
}

make_boot_files() {
  log "Writing GRUB (BIOS + UEFI/Secure Boot) boot files"

  # --- disk identity (casper + GRUB search for this file) -------------------
  local ymd
  ymd=$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y%m%d)
  echo "$DELUXE_NAME $DELUXE_VERSION \"$DELUXE_CODENAME\" - Release amd64 ($ymd)" > "$IMAGE/.disk/info"
  echo "full_cd/single" > "$IMAGE/.disk/cd_type"
  : > "$IMAGE/.disk/base_installable"
  echo "$DELUXE_URL" > "$IMAGE/.disk/release_notes_url"

  # --- GRUB menu + theme -----------------------------------------------------
  sed -e "s|@NAME@|$DELUXE_NAME|g" -e "s|@VERSION@|$DELUXE_VERSION|g" -e "s|@CODENAME@|$DELUXE_CODENAME|g" \
    "$ROOT/iso/grub/grub.cfg.in" > "$IMAGE/boot/grub/grub.cfg"
  cp -a "$CHROOT/usr/share/grub/themes/deluxe/." "$IMAGE/boot/grub/theme/"
  [[ -f "$CHROOT/usr/share/grub/unicode.pf2" ]] && cp "$CHROOT/usr/share/grub/unicode.pf2" "$IMAGE/boot/grub/"

  # --- BIOS: El Torito image + modules --------------------------------------
  cp /usr/lib/grub/i386-pc/*.mod /usr/lib/grub/i386-pc/*.lst "$IMAGE/boot/grub/i386-pc/"
  grub-mkimage -O i386-pc-eltorito -p /boot/grub -o "$IMAGE/boot/grub/i386-pc/eltorito.img" \
    biosdisk iso9660 normal configfile search search_fs_file search_label

  # --- UEFI: Canonical-signed shim + GRUB taken from the chroot (Secure Boot OK)
  local shim mm grub
  shim=$(pick_first "$CHROOT"/usr/lib/shim/shimx64.efi.signed.latest "$CHROOT"/usr/lib/shim/shimx64.efi.signed) || die "signed shim not found (package shim-signed)"
  mm=$(pick_first "$CHROOT"/usr/lib/shim/mmx64.efi.signed.latest "$CHROOT"/usr/lib/shim/mmx64.efi.signed "$CHROOT"/usr/lib/shim/mmx64.efi) || die "mmx64.efi not found"
  grub=$(pick_first "$CHROOT"/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed) || die "signed GRUB not found (package grub-efi-amd64-signed)"
  cp "$CHROOT"/usr/lib/grub/x86_64-efi/*.mod "$CHROOT"/usr/lib/grub/x86_64-efi/*.lst "$IMAGE/boot/grub/x86_64-efi/" 2>/dev/null || true

  local stub="$WORK/efi-grub.cfg"
  cat > "$stub" <<'EOF'
search --no-floppy --file --set=root /.disk/info
set prefix=($root)/boot/grub
configfile ($root)/boot/grub/grub.cfg
EOF
  local efi="$WORK/efi.img"
  rm -f "$efi"
  truncate -s 12M "$efi"
  mkfs.vfat -n DLX_EFI "$efi" >/dev/null
  mmd -i "$efi" ::EFI ::EFI/boot ::boot ::boot/grub
  mcopy -i "$efi" "$shim"  ::EFI/boot/bootx64.efi
  mcopy -i "$efi" "$grub"  ::EFI/boot/grubx64.efi
  mcopy -i "$efi" "$mm"    ::EFI/boot/mmx64.efi
  mcopy -i "$efi" "$stub"  ::EFI/boot/grub.cfg
  mcopy -i "$efi" "$stub"  ::boot/grub/grub.cfg
  # loose copies in the ISO filesystem too (some firmware boots the ISO9660 tree directly)
  cp "$shim" "$IMAGE/EFI/boot/bootx64.efi"; cp "$grub" "$IMAGE/EFI/boot/grubx64.efi"
  cp "$mm" "$IMAGE/EFI/boot/mmx64.efi";     cp "$stub" "$IMAGE/EFI/boot/grub.cfg"

  # --- integrity file used by the "Check disc for defects" menu entry --------
  (cd "$IMAGE" && find . -type f ! -name md5sum.txt -print0 | sort -z | xargs -0 md5sum > md5sum.txt)
}

make_iso() {
  log "Building hybrid ISO with xorriso"
  mkdir -p "$OUT"
  local iso="$OUT/$ISO_NAME"
  local mdate
  mdate=$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y%m%d%H%M%S00)
  rm -f "$iso"
  xorriso -as mkisofs \
    -r -V "$DELUXE_VOLID" -o "$iso" -J -joliet-long -iso-level 3 \
    --modification-date="$mdate" \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    --protective-msdos-label \
    -partition_cyl_align off -partition_offset 16 \
    --mbr-force-bootable \
    -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$WORK/efi.img" \
    -appended_part_as_gpt \
    -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
    -c /boot.catalog \
    -b /boot/grub/i386-pc/eltorito.img \
      -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
    -eltorito-alt-boot \
    -e '--interval:appended_partition_2:::' \
      -no-emul-boot \
    "$IMAGE"

  local size
  size=$(stat -c %s "$iso")
  info "ISO size: $size bytes ($(numfmt --to=iec "$size"))"
  (( size <= MAX_ISO_BYTES )) || die "ISO is $size bytes, over the $MAX_ISO_BYTES limit. Move more apps to the Flatpak list in packages/ and rebuild."

  (cd "$OUT" && sha256sum "$ISO_NAME" > "$ISO_NAME.sha256")
  cp "$IMAGE/casper/filesystem.manifest" "$OUT/${ISO_NAME%.iso}.manifest"
  info "checksum: $(cat "$OUT/$ISO_NAME.sha256")"
}

# ---------------------------------------------------------------------------
main() {
  preflight
  [[ $DO_CLEAN -eq 1 ]] && { log "Cleaning previous build"; umount_chroot; rm -rf "$WORK" "$OUT"; }
  install_host_deps
  build_assets
  bootstrap
  mount_chroot
  prepare_chroot
  run_hook 00-prepare.sh
  run_hook 10-packages.sh
  apply_overlay
  run_hook 20-branding.sh
  run_hook 30-desktop.sh
  run_hook 40-system.sh
  run_hook 50-installer.sh
  run_hook 90-cleanup.sh
  make_image_tree
  make_squashfs
  make_boot_files
  # Low-disk mode: the chroot is no longer needed once squashfs + boot files exist; free ~9 GB before xorriso.
  if [[ "${KEEP_CHROOT:-0}" != 1 ]]; then log "Freeing chroot to save disk"; umount_chroot; rm -rf "$CHROOT" "$CACHE"; fi
  make_iso
  log "Done: $OUT/$ISO_NAME"
}
main "$@"
