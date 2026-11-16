#!/bin/sh
# Runs at login in the LIVE session only: puts the "Install Deluxe System 1" launcher on the desktop
# and marks it trusted so GNOME lets it start with a double-click.
grep -qw 'boot=casper' /proc/cmdline || exit 0
DESK="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
mkdir -p "$DESK"
cp /usr/share/applications/deluxe-install.desktop "$DESK/install-deluxe.desktop"
chmod +x "$DESK/install-deluxe.desktop"
gio set "$DESK/install-deluxe.desktop" metadata::trusted true 2>/dev/null || true
# Live session: the Welcome app is only useful after installation.
gsettings set org.deluxe.system welcome-shown true 2>/dev/null || true
