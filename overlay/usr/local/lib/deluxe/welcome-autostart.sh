#!/bin/sh
# First login on an INSTALLED system: show the Welcome app once.
grep -qw 'boot=casper' /proc/cmdline && exit 0
[ "$(gsettings get org.deluxe.system welcome-shown 2>/dev/null)" = "true" ] && exit 0
gsettings set org.deluxe.system welcome-shown true 2>/dev/null || true
sleep 4   # let the shell finish drawing first
exec /usr/local/bin/deluxe-welcome
