#!/bin/bash
# 30-desktop: GSettings schemas, dconf defaults, fonts, Flatpak/Flathub, GDM.
. /tmp/deluxe-build/config.env
export DEBIAN_FRONTEND=noninteractive

glib-compile-schemas /usr/share/glib-2.0/schemas
dconf update                       # compiles /etc/dconf/db/{local,gdm}.d
fc-cache -f

# Flatpak + Flathub (system-wide). If the build host is offline for this step, the
# NetworkManager dispatcher script adds the remote on first connection instead.
if flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null; then
  install -d /var/lib/deluxe && touch /var/lib/deluxe/flathub-done
else
  echo "NOTE: could not add Flathub at build time; it will be added at first network connection."
fi


# ---- GNOME Shell theme "Deluxe": stock theme + our overrides -------------------------------
# A shell (user-theme) stylesheet replaces the whole default one, so we unpack the stock theme from
# gnome-shell's gresource and append the Deluxe overrides to it.
SHELL_DIR=/usr/share/themes/Deluxe/gnome-shell
GRES=/usr/share/gnome-shell/gnome-shell-theme.gresource
if [ -f "$GRES" ]; then
  for r in $(gresource list "$GRES"); do
    rel=${r#/org/gnome/shell/theme/}
    install -d "$SHELL_DIR/$(dirname "$rel")"
    gresource extract "$GRES" "$r" > "$SHELL_DIR/$rel"
  done
  if [ -f "$SHELL_DIR/gnome-shell.css" ]; then
    cat "$SHELL_DIR/deluxe-overrides.css" >> "$SHELL_DIR/gnome-shell.css"
  else
    echo "WARNING: stock gnome-shell.css not found in $GRES; Deluxe shell theme will not apply" >&2
  fi
else
  echo "WARNING: $GRES missing; Deluxe shell theme will not apply" >&2
fi
# Deluxe-dark shares the same shell theme (GNOME Shell's panel/overview is dark in both modes).
ln -sfn ../Deluxe/gnome-shell /usr/share/themes/Deluxe-dark/gnome-shell

# Light/dark auto switching runs as a user timer for every account.
systemctl --global enable deluxe-theme.timer

# GDM: login screen settings come from /etc/dconf/db/gdm.d (logo, banner, dark scheme).
install -d /etc/gdm3
systemctl set-default graphical.target
systemctl enable gdm3.service

# Default applications
update-alternatives --set x-www-browser /usr/bin/firefox 2>/dev/null || true
update-alternatives --set gnome-www-browser /usr/bin/firefox 2>/dev/null || true
xdg-mime default firefox.desktop x-scheme-handler/http x-scheme-handler/https text/html 2>/dev/null || true
