#!/bin/bash
# 10-packages: install everything from packages/packages.list, then purge packages/remove.list.
. /tmp/deluxe-build/config.env
export DEBIAN_FRONTEND=noninteractive
PKG=/tmp/deluxe-build/packages

strip_list() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"; }

mapfile -t WANT < <(strip_list "$PKG/packages.list")

# Fail early, and list EVERY missing package at once, instead of dying on the first one.
missing=()
for p in "${WANT[@]}"; do
  cand=$(apt-cache policy "$p" 2>/dev/null | awk '/Candidate:/{print $2}')
  if [ -z "$cand" ] || [ "$cand" = "(none)" ]; then missing+=("$p"); fi
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: these packages have no install candidate in noble:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  echo "Fix packages/packages.list (see docs/TROUBLESHOOTING.md #2)." >&2
  exit 1
fi

# The kernel is installed WITH recommends so modules-extra (more Wi-Fi/NIC drivers) comes along.
apt-get install -y --install-recommends linux-generic
apt-get install -y --no-install-recommends "${WANT[@]}"

# Remove bloat that slipped in as a dependency.
mapfile -t DROP < <(strip_list "$PKG/remove.list")
for p in "${DROP[@]}"; do
  dpkg -s "$p" >/dev/null 2>&1 && apt-get purge -y "$p" || true
done
apt-get autoremove -y --purge

# Identity files are owned by Ubuntu's base-files package; divert them so a future base-files
# upgrade can never overwrite Deluxe's os-release / lsb-release (same technique other derivatives use).
# This must happen BEFORE the overlay is copied (build.sh does that right after this hook).
for f in /usr/lib/os-release /etc/lsb-release; do
  dpkg-divert --package deluxe-system --add --rename --divert "${f}.ubuntu" "$f"
done

# Hard guarantee: no snap anywhere.
if dpkg -s snapd >/dev/null 2>&1; then echo "snapd is installed — build aborted" >&2; exit 1; fi
if [ "$(dpkg-query -W -f='${Version}' firefox 2>/dev/null | grep -c snap)" != "0" ]; then
  echo "firefox resolved to Ubuntu's snap stub — Mozilla repo pin failed" >&2; exit 1
fi
