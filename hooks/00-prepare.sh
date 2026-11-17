#!/bin/bash
# 00-prepare: runs inside the chroot. Block snap/telemetry, add third-party APT repos, preseed debconf.
. /tmp/deluxe-build/config.env
export DEBIAN_FRONTEND=noninteractive

# Never start daemons while building the image.
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod 0755 /usr/sbin/policy-rc.d

# Build-only APT settings (removed again in 90-cleanup so users get normal Recommends).
cat > /etc/apt/apt.conf.d/99-deluxe-build-only <<'EOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Acquire::Languages "none";
Dpkg::Options { "--force-confdef"; "--force-confold"; };
EOF

# Permanently keep snap, Ubuntu telemetry and Pro nag-ware off the system.
cat > /etc/apt/preferences.d/50-deluxe-block <<'EOF'
Package: snapd gnome-software-plugin-snap ubuntu-report apport whoopsie popularity-contest
Pin: release *
Pin-Priority: -1
EOF

apt-get update
apt-get -y dist-upgrade

if [ "${SKIP_THIRD_PARTY:-0}" = 1 ]; then
  echo "SKIP_THIRD_PARTY=1: not adding Mozilla/VSCodium repositories (validation build)"
else
# ---- Third-party repositories (signed, pinned) -----------------------------------------
install -d -m 0755 /etc/apt/keyrings /usr/share/keyrings

# Mozilla: Ubuntu's "firefox" package is a snap stub, so use Mozilla's own .deb repository.
curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg -o /etc/apt/keyrings/packages.mozilla.org.asc
got=$(gpg --show-keys --with-colons /etc/apt/keyrings/packages.mozilla.org.asc | awk -F: '/^fpr/{print $10; exit}')
[ "$got" = "$MOZILLA_KEY_FPR" ] || { echo "Mozilla key fingerprint mismatch: $got" >&2; exit 1; }
cat > /etc/apt/sources.list.d/mozilla.sources <<'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
cat > /etc/apt/preferences.d/mozilla <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000

Package: firefox*
Pin: release o=Ubuntu*
Pin-Priority: -1
EOF

# VSCodium (VS Code built from MIT-licensed sources, no Microsoft telemetry or licence strings).
curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
  | gpg --dearmor -o /usr/share/keyrings/vscodium-archive-keyring.gpg
vfpr=$(gpg --show-keys --with-colons /usr/share/keyrings/vscodium-archive-keyring.gpg | awk -F: '/^fpr/{print $10; exit}')
echo "VSCodium signing key fingerprint seen at build time: $vfpr"
if [ -n "${VSCODIUM_KEY_FPR:-}" ] && [ "$vfpr" != "$VSCODIUM_KEY_FPR" ]; then
  echo "VSCodium key fingerprint mismatch (expected $VSCODIUM_KEY_FPR)" >&2; exit 1
fi
cat > /etc/apt/sources.list.d/vscodium.sources <<'EOF'
Types: deb
URIs: https://download.vscodium.com/debs
Suites: vscodium
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/vscodium-archive-keyring.gpg
EOF

fi

# ---- debconf preseeding so nothing prompts ----------------------------------------------
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
echo 'Etc/UTC' > /etc/timezone
debconf-set-selections <<'EOF'
grub-pc grub-pc/install_devices_empty boolean true
grub-pc grub-pc/install_devices string
tzdata tzdata/Areas select Etc
tzdata tzdata/Zones/Etc select UTC
keyboard-configuration keyboard-configuration/layoutcode string us
keyboard-configuration keyboard-configuration/xkb-keymap select us
gdm3 shared/default-x-display-manager select gdm3
EOF

apt-get update
