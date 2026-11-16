#!/usr/bin/env bash
# Boot the ISO in QEMU/KVM.   ./tools/test-qemu.sh bios|uefi|uefi-secure  [path/to/iso]
# Needs: sudo apt install qemu-system-x86 ovmf
set -euo pipefail
MODE="${1:-uefi}"
ISO="${2:-$(dirname "$0")/../out/deluxe-system-1-1.0-amd64.iso}"
[ -f "$ISO" ] || { echo "ISO not found: $ISO" >&2; exit 1; }
DISK="${DISK:-/tmp/deluxe-test.qcow2}"
[ -f "$DISK" ] || qemu-img create -f qcow2 "$DISK" 40G >/dev/null
ARGS=(-m 4096 -smp 4 -enable-kvm -cpu host -vga virtio -display gtk
      -device intel-hda -device hda-duplex -nic user,model=virtio-net-pci
      -drive file="$DISK",if=virtio -cdrom "$ISO" -boot d)
case "$MODE" in
  bios) exec qemu-system-x86_64 "${ARGS[@]}" ;;
  uefi) cp /usr/share/OVMF/OVMF_VARS_4M.fd /tmp/deluxe-vars.fd
        exec qemu-system-x86_64 "${ARGS[@]}" \
          -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
          -drive if=pflash,format=raw,file=/tmp/deluxe-vars.fd ;;
  uefi-secure) cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd /tmp/deluxe-vars-sb.fd
        exec qemu-system-x86_64 "${ARGS[@]}" -machine q35,smm=on -global driver=cfi.pflash01,property=secure,value=on \
          -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd \
          -drive if=pflash,format=raw,file=/tmp/deluxe-vars-sb.fd ;;
  *) echo "usage: $0 bios|uefi|uefi-secure [iso]" >&2; exit 2 ;;
esac
