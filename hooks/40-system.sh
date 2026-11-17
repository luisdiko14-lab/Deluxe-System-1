#!/bin/bash
# 40-system: performance, security and fast-boot tuning.
. /tmp/deluxe-build/config.env
export DEBIAN_FRONTEND=noninteractive

# --- Firewall: UFW on by default (deny incoming, allow outgoing) ------------------------
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
sed -i 's/^DEFAULT_INPUT_POLICY=.*/DEFAULT_INPUT_POLICY="DROP"/' /etc/default/ufw
sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw
systemctl enable ufw.service

# --- AppArmor ----------------------------------------------------------------------------
systemctl enable apparmor.service

# --- Automatic security updates (config in apt.conf.d from the overlay) -------------------
systemctl enable unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer

# --- SSD TRIM, zram swap (config from overlay), preload ----------------------------------
systemctl enable fstrim.timer
systemctl enable preload.service 2>/dev/null || true

# --- Fast boot: don't wait for the network, trim idle services -----------------------------
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true
systemctl disable cups-browsed.service 2>/dev/null || true
# Docker only starts when first used (socket activation), not on every boot.
systemctl disable docker.service containerd.service 2>/dev/null || true
systemctl enable docker.socket 2>/dev/null || true
systemctl enable NetworkManager.service bluetooth.service power-profiles-daemon.service 2>/dev/null || true

# --- Kernel boot parameters for the INSTALLED system (Calamares also sets these) ---------
# (see overlay/etc/default/grub.d/deluxe.cfg)

# --- Make sure no leftover Ubuntu telemetry units exist -----------------------------------
for u in apport.service whoopsie.service ubuntu-report.service popularity-contest.timer; do
  systemctl mask "$u" 2>/dev/null || true
done

# --- Ubuntu Pro client: required by gnome-software's dependency chain, so keep the package but silence it
for u in ubuntu-advantage.service ua-timer.timer ua-timer.service apt-news.service esm-cache.service \
         ubuntu-advantage-desktop-daemon.service ua-reboot-cmds.service; do
  systemctl mask "$u" 2>/dev/null || true
done
rm -f /etc/apt/apt.conf.d/20apt-esm-hook.conf /etc/apt/apt.conf.d/20apt-esm-hook 2>/dev/null || true
rm -f /etc/apt/apt.conf.d/20pro-news* 2>/dev/null || true
install -d /etc/ubuntu-advantage
printf 'apt_news: false\n' > /etc/ubuntu-advantage/uaclient.conf.deluxe 2>/dev/null || true
