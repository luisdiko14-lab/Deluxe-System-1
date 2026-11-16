#!/bin/bash
# 50-installer: install the Calamares configuration + branding into the live image.
. /tmp/deluxe-build/config.env
set -u
SRC=/tmp/deluxe-build/calamares

command -v calamares >/dev/null || { echo "calamares is not installed" >&2; exit 1; }

install -d /etc/calamares/modules /usr/share/calamares/branding/deluxe
cp "$SRC/settings.conf" /etc/calamares/settings.conf
cp "$SRC"/modules/*.conf /etc/calamares/modules/
cp -a "$SRC"/branding/deluxe/. /usr/share/calamares/branding/deluxe/

# Calamares refuses to start if a referenced module config is missing: verify now, not at install time.
fail=0
for m in welcome locale keyboard partition users summary finished mount unpackfs fstab \
         bootloader grubcfg initramfs initramfscfg luksbootkeyfile machineid umount; do
  [ -f "/etc/calamares/modules/$m.conf" ] || { echo "missing module config: $m.conf" >&2; fail=1; }
done
[ -f /etc/calamares/modules/shellprocess_postinstall.conf ] || { echo "missing shellprocess_postinstall.conf" >&2; fail=1; }
[ -f /usr/share/calamares/branding/deluxe/branding.desc ] || { echo "missing branding.desc" >&2; fail=1; }
[ "$fail" = 0 ] || exit 1

# Live session identity (casper reads /etc/casper.conf; passwordless user "deluxe").
grep -q '^export USERNAME="deluxe"' /etc/casper.conf
