# Verification checklist

Tick every box on a clean build. Nothing here has been run on a full build yet — this is the test plan.

## Build
- [ ] `build.sh` ends with `Done:` and prints an ISO size ≤ 4,700,000,000 bytes
- [ ] `sha256sum -c *.iso.sha256` says OK
- [ ] `out/*.manifest` has no `snapd`, `ubuntu-report`, `apport`, `whoopsie`; `firefox` version is not a snap stub

## Boot
- [ ] **BIOS**: QEMU `bios` / VirtualBox without EFI → themed GRUB menu (navy, gold logo) → Plymouth splash → live desktop
- [ ] **UEFI**: QEMU `uefi` / VirtualBox with EFI → same
- [ ] **UEFI + Secure Boot**: QEMU `uefi-secure` → boots (shim → signed GRUB → signed kernel)
- [ ] Live user is `deluxe`, logged in without a password
- [ ] "Safe graphics" menu entry reaches the desktop on a VM with no 3D

## Installer (Calamares)
- [ ] "Install Deluxe System 1" icon on the live desktop opens the installer (no blank/black window)
- [ ] Navy/gold branding, logo and welcome image; slideshow (6 slides) cycles during installation
- [ ] **Without LUKS:** erase-disk install on BIOS VM → reboots into the installed system
- [ ] **Without LUKS:** erase-disk install on UEFI VM → reboots; `efibootmgr` shows "Deluxe System 1"
- [ ] **With LUKS:** tick *Encrypt system*, install on BIOS and on UEFI; passphrase asked at boot (once), system starts
- [ ] Installed system: `deluxe` user gone, `casper`/`calamares` not installed (`dpkg -l casper calamares`), your user in `sudo` and `docker`

## Hardware (real machine)
- [ ] Wi-Fi networks are listed and connect; Bluetooth pairs
- [ ] Sound, brightness keys, suspend/resume, touchpad gestures
- [ ] `fwupdmgr get-devices` runs

## Apps launch
- [ ] Firefox (from Mozilla repo, not snap) · LibreOffice Writer/Calc/Impress · VLC plays an MP4 and an MKV with H.264/AAC · GIMP · VSCodium (`codium`)
- [ ] `git --version`, `python3 --version`, `node --version`, `gcc --version`
- [ ] `sudo docker run --rm hello-world` (docker group needs a re-login)
- [ ] Timeshift, GParted, BleachBit, Software (Flathub apps listed)
- [ ] Welcome app: theme switch works; Inkscape installs from Flathub; *Check now* returns counts
- [ ] `deluxe-update` completes (apt + flatpak + firmware)

## Branding shows everywhere
- [ ] GRUB menu (live and installed) · Plymouth splash · GDM login screen shows the D1 logo and banner
- [ ] Settings → About shows "Deluxe System 1 1.0 (Aurora)" and the logo
- [ ] `cat /etc/os-release /etc/lsb-release /etc/issue` · `lsb_release -d` · `hostnamectl`
- [ ] Wallpapers: 5 entries in Settings → Background, each with light/dark variants
- [ ] Papirus icons, Inter UI font, JetBrains Mono in the terminal/editor, bottom dock, rounded windows
- [ ] No "Ubuntu" logo/wordmark visible anywhere in the UI

## Performance and security
- [ ] `zramctl` shows zram0 ~ half of RAM, `swapon --show` lists it
- [ ] `systemctl status fstrim.timer preload` active
- [ ] `sudo ufw status` → active, `aa-status` → profiles loaded
- [ ] `systemctl list-timers` shows apt-daily and apt-daily-upgrade; `sudo unattended-upgrade --dry-run -v` lists `Ubuntu:noble-security`
- [ ] `snap` command not found; no Snap Store prompts
- [ ] Night Light enabled (Settings → Displays)
- [ ] Theme: `deluxe-theme --status`; change the system clock past 19:00 and run `deluxe-theme --apply` → dark
