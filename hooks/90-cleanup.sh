#!/bin/bash
# 90-cleanup: final initramfs, record licences, restore normal APT behaviour, shrink the image.
. /tmp/deluxe-build/config.env
export DEBIAN_FRONTEND=noninteractive

# Rebuild all initramfs images now that casper, plymouth theme and cryptsetup hooks are in place.
update-initramfs -c -k all
update-grub 2>/dev/null || true

# Licence inventory of everything that shipped (see docs/LICENSES.md for the human summary).
install -d /usr/share/doc/deluxe-system
{
  echo "# Deluxe System 1 $DELUXE_VERSION — licences found in /usr/share/doc/*/copyright (count of packages per licence)"
  grep -h -i '^License:' /usr/share/doc/*/copyright 2>/dev/null | sed 's/^[Ll]icense:[[:space:]]*//' \
    | sed 's/[[:space:]]*$//' | sort | uniq -c | sort -rn | head -80
} > /usr/share/doc/deluxe-system/package-licenses.txt

# Normal APT behaviour for end users (undo build-only settings, point at the live archive).
rm -f /etc/apt/apt.conf.d/99-deluxe-build-only /etc/apt/apt.conf.d/01proxy
cat > /etc/apt/sources.list.d/ubuntu.sources <<EOF
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: ${UBUNTU_SUITE} ${UBUNTU_SUITE}-updates ${UBUNTU_SUITE}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu
Suites: ${UBUNTU_SUITE}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

# Remove build leftovers.
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/deluxe-build /tmp/* /var/tmp/* /root/.cache
rm -f /usr/sbin/policy-rc.d /var/log/*.log /var/log/apt/* /var/log/dpkg.log /var/log/alternatives.log
find /var/log -type f -name '*.log' -delete 2>/dev/null || true

# Unique machine identity is created at first boot / by the installer, never baked in.
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id
rm -f /etc/ssh/ssh_host_* 2>/dev/null || true

# resolv.conf the way Ubuntu ships it.
rm -f /etc/resolv.conf
ln -s ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Passwords/history must not leak into the image.
rm -f /root/.bash_history /etc/shadow- /etc/passwd- /etc/group- /etc/gshadow-
