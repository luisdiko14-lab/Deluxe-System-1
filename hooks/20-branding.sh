#!/bin/bash
# 20-branding: runs after the overlay is copied. Identity files, Plymouth, GRUB defaults, icons.
. /tmp/deluxe-build/config.env
export DEBIAN_FRONTEND=noninteractive

# Permissions the overlay cannot carry reliably (zip/tar round-trips lose exec bits).
chmod 0755 /usr/local/bin/deluxe-* /usr/local/lib/deluxe/*.sh
chmod 0755 /etc/NetworkManager/dispatcher.d/90-deluxe-flathub

# /etc/os-release must point at our file (Ubuntu ships it as a symlink to /usr/lib/os-release).
ln -sf ../usr/lib/os-release /etc/os-release
cp /usr/lib/os-release /etc/deluxe/release 2>/dev/null || true

# dpkg vendor: we derive from Ubuntu, so tools keep Ubuntu-compatible behaviour.
ln -sf /etc/dpkg/origins/deluxe /etc/dpkg/origins/default

# Plymouth boot splash
update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
  /usr/share/plymouth/themes/deluxe/deluxe.plymouth 200
update-alternatives --set default.plymouth /usr/share/plymouth/themes/deluxe/deluxe.plymouth
install -d /etc/plymouth
printf '[Daemon]\nTheme=deluxe\nShowDelay=0\n' > /etc/plymouth/plymouthd.conf

# GRUB theme fonts (.pf2 are generated from the installed TTFs; names become "DejaVu Sans Regular 16" etc.)
T=/usr/share/grub/themes/deluxe
for sz in 12 13 16; do grub-mkfont -s $sz -o $T/dejavu-regular-$sz.pf2 /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf; done
for sz in 16 22;    do grub-mkfont -s $sz -o $T/dejavu-bold-$sz.pf2    /usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf; done
ls $T/*.pf2 >/dev/null

# Icons: refresh caches so the logo resolves as LOGO=deluxe-logo in Settings > About.
gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
gtk-update-icon-cache -f -t /usr/share/icons/Papirus >/dev/null 2>&1 || true
gtk-update-icon-cache -f -t /usr/share/icons/Papirus-Dark >/dev/null 2>&1 || true

# Remove leftover Ubuntu-branded artwork/defaults if some package dragged them in.
for p in ubuntu-wallpapers yaru-theme-gtk yaru-theme-icon yaru-theme-sound ubuntu-docs ubuntu-settings; do
  dpkg -s "$p" >/dev/null 2>&1 && apt-get purge -y "$p" || true
done
apt-get autoremove -y --purge

# Legal/MOTD: no Ubuntu advertising.
rm -f /etc/legal /etc/update-motd.d/* 2>/dev/null || true
