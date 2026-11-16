#!/bin/bash
# Runs INSIDE the freshly installed system (chroot), called by Calamares' shellprocess@postinstall.
# Removes everything that only makes sense in the live session.
export DEBIAN_FRONTEND=noninteractive
LIVE_USER=deluxe
log() { echo "[deluxe-postinstall] $*"; }

# 1. Live-only packages
log "removing live-only packages"
for p in calamares calamares-settings-ubuntu ubiquity ubiquity-frontend-gtk casper lupin-casper; do
  dpkg -s "$p" >/dev/null 2>&1 && apt-get purge -y "$p" >/dev/null 2>&1 || true
done
apt-get autoremove -y --purge >/dev/null 2>&1 || true

# 2. Live user, its sudo rule, autologin
log "removing live user $LIVE_USER"
if id "$LIVE_USER" >/dev/null 2>&1; then userdel -f -r "$LIVE_USER" 2>/dev/null || userdel -f "$LIVE_USER" || true; fi
rm -rf "/home/$LIVE_USER"
rm -f /etc/sudoers.d/casper* /etc/sudoers.d/*live* /etc/casper.conf
sed -i '/^AutomaticLogin/d;/^AutomaticLoginEnable/d' /etc/gdm3/custom.conf 2>/dev/null || true

# 3. Installer leftovers
rm -rf /etc/calamares /usr/share/calamares
rm -f /usr/share/applications/deluxe-install.desktop /usr/local/bin/deluxe-installer \
      /etc/xdg/autostart/deluxe-live-setup.desktop
rm -f /etc/skel/Desktop/install-deluxe.desktop

# 4. Fresh identity
rm -f /etc/ssh/ssh_host_* && (command -v ssh-keygen >/dev/null && dpkg-reconfigure -f noninteractive openssh-server 2>/dev/null || true)

# 5. Make sure the firewall and updates are on in the installed system
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf 2>/dev/null || true

update-initramfs -u -k all >/dev/null 2>&1 || true
log "done"
exit 0
