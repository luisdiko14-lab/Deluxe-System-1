#!/usr/bin/env bash
# Safely write the ISO to a USB stick:  sudo ./tools/write-usb.sh /dev/sdX [iso]
# Refuses system disks, non-removable disks, and verifies the checksum before and after writing.
set -euo pipefail
DEV="${1:-}"; ISO="${2:-$(dirname "$0")/../out/deluxe-system-1-1.0-amd64.iso}"
[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }
[ -b "$DEV" ] || { echo "usage: sudo $0 /dev/sdX [iso]   (a whole-disk block device, e.g. /dev/sdb)" >&2; exit 2; }
[ -f "$ISO" ] || { echo "ISO not found: $ISO" >&2; exit 1; }
[[ "$DEV" =~ [0-9]$ && ! "$DEV" =~ nvme ]] && { echo "$DEV looks like a partition; pass the whole disk" >&2; exit 2; }
ROOT_DISK=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null || true)
[ "/dev/$ROOT_DISK" != "$DEV" ] || { echo "refusing: $DEV holds the running system" >&2; exit 1; }
RM=$(lsblk -dno RM "$DEV"); TRAN=$(lsblk -dno TRAN "$DEV" || true)
if [ "$RM" != "1" ] && [ "$TRAN" != "usb" ]; then echo "refusing: $DEV is not a removable/USB device" >&2; exit 1; fi
( cd "$(dirname "$ISO")" && sha256sum -c "$(basename "$ISO").sha256" )
echo; lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS "$DEV"
read -r -p "ALL DATA on $DEV will be destroyed. Type YES to continue: " a; [ "$a" = YES ] || exit 1
umount "$DEV"* 2>/dev/null || true
dd if="$ISO" of="$DEV" bs=4M status=progress oflag=sync conv=fsync
sync
SZ=$(stat -c %s "$ISO")
cmp -n "$SZ" "$ISO" "$DEV" && echo "Verified: USB matches the ISO. You can unplug it." || { echo "VERIFY FAILED" >&2; exit 1; }
