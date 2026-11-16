#!/usr/bin/env python3
"""Welcome to Deluxe System 1 — theme, wallpaper, extra apps and update check in one window.

GTK4 + libadwaita (python3-gi, gir1.2-adw-1). All long-running work (flatpak/apt/network) runs in
worker threads; the UI is only touched through GLib.idle_add.
"""
import os
import shutil
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gio, GLib, Gtk  # noqa: E402

APP_ID = "org.deluxe.Welcome"
SCHEMA = "org.deluxe.system"
WALLPAPER_DIR = "/usr/share/backgrounds/deluxe"
WALLPAPERS = [("aurora", "Aurora"), ("dunes", "Golden Dunes"), ("horizon", "Horizon Grid"),
              ("orbits", "Orbits"), ("facets", "Facets")]

# (id, title, subtitle, kind, target)  kind: flatpak | apt-terminal
APPS = [
    ("inkscape", "Inkscape", "Vector graphics editor", "flatpak", "org.inkscape.Inkscape"),
    ("obs", "OBS Studio", "Screen recording and live streaming", "flatpak", "com.obsproject.Studio"),
    ("vscode", "Visual Studio Code (Microsoft)", "Proprietary Microsoft build; licence is accepted on first run",
     "flatpak", "com.visualstudio.code"),
    ("thunderbird", "Thunderbird", "Email, calendar and contacts", "flatpak", "org.mozilla.Thunderbird"),
    ("kdenlive", "Kdenlive", "Video editor", "flatpak", "org.kde.kdenlive"),
    ("audacity", "Audacity", "Audio recorder and editor", "flatpak", "org.audacityteam.Audacity"),
    ("blender", "Blender", "3D modelling, animation and rendering", "flatpak", "org.blender.Blender"),
    ("bitwarden", "Bitwarden", "Password manager", "flatpak", "com.bitwarden.desktop"),
    ("msfonts", "Microsoft core fonts", "Arial, Times New Roman… (downloads under Microsoft's EULA)",
     "apt-terminal", "ttf-mscorefonts-installer"),
]


def settings():
    src = Gio.SettingsSchemaSource.get_default()
    if src and src.lookup(SCHEMA, True):
        return Gio.Settings.new(SCHEMA)
    return None


def run(cmd, timeout=None):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout or "") + (p.stderr or "")
    except FileNotFoundError:
        return 127, f"{cmd[0]}: not found"
    except subprocess.TimeoutExpired:
        return 124, "timed out"


def flatpak_installed(app_id):
    rc, _ = run(["flatpak", "info", app_id], timeout=20)
    return rc == 0


class Welcome(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Welcome to Deluxe System 1")
        self.set_default_size(760, 720)
        self.gs = settings()
        self.toasts = Adw.ToastOverlay()
        self.app_rows = {}

        view = Adw.ToolbarView()
        header = Adw.HeaderBar()
        view.add_top_bar(header)

        page = Adw.PreferencesPage()
        page.add(self._hero())
        page.add(self._theme_group())
        page.add(self._wallpaper_group())
        page.add(self._apps_group())
        page.add(self._updates_group())
        view.set_content(page)
        self.toasts.set_child(view)
        self.set_content(self.toasts)

    # -- helpers -----------------------------------------------------------------------
    def toast(self, text):
        GLib.idle_add(lambda: self.toasts.add_toast(Adw.Toast.new(text)) or False)

    def _hero(self):
        g = Adw.PreferencesGroup()
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8, margin_top=12, margin_bottom=12)
        img = Gtk.Image.new_from_icon_name("deluxe-logo")
        img.set_pixel_size(96)
        title = Gtk.Label(label="Welcome to Deluxe System 1")
        title.add_css_class("title-1")
        sub = Gtk.Label(label="Version 1.0 “Aurora” — let’s set things up the way you like them.")
        sub.add_css_class("dim-label")
        for w in (img, title, sub):
            box.append(w)
        g.add(box)
        return g

    # -- theme -------------------------------------------------------------------------
    def _theme_group(self):
        g = Adw.PreferencesGroup(title="Appearance", description="Auto switches to dark at 19:00 and back to light at 07:00.")
        row = Adw.ComboRow(title="Theme", subtitle="Light, dark, or follow the time of day")
        row.set_model(Gtk.StringList.new(["Auto (day/night)", "Light", "Dark"]))
        modes = ["auto", "light", "dark"]
        cur = self.gs.get_string("theme-mode") if self.gs else "auto"
        row.set_selected(modes.index(cur) if cur in modes else 0)

        def changed(r, _p):
            mode = modes[r.get_selected()]
            threading.Thread(target=lambda: run(["deluxe-theme", mode]), daemon=True).start()
        row.connect("notify::selected", changed)
        g.add(row)

        nl = Adw.SwitchRow(title="Night Light", subtitle="Warmer screen colours in the evening")
        gsd = Gio.Settings.new("org.gnome.settings-daemon.plugins.color")
        nl.set_active(gsd.get_boolean("night-light-enabled"))
        nl.connect("notify::active", lambda r, _p: gsd.set_boolean("night-light-enabled", r.get_active()))
        g.add(nl)
        return g

    def _wallpaper_group(self):
        g = Adw.PreferencesGroup(title="Wallpaper")
        row = Adw.ActionRow(title="Choose a wallpaper", subtitle="Each one has a light and a dark version")
        flow = Gtk.Box(spacing=8, margin_top=8, margin_bottom=8)
        for key, label in WALLPAPERS:
            pic = Gtk.Picture.new_for_filename(f"{WALLPAPER_DIR}/{key}-dark.png")
            pic.set_size_request(84, 48)
            pic.set_content_fit(Gtk.ContentFit.COVER)
            pic.add_css_class("card")
            btn = Gtk.Button(child=pic, tooltip_text=label)
            btn.add_css_class("flat")
            btn.connect("clicked", self._set_wallpaper, key)
            flow.append(btn)
        sc = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.AUTOMATIC, vscrollbar_policy=Gtk.PolicyType.NEVER)
        sc.set_child(flow)
        sc.set_hexpand(True)
        row.add_suffix(sc)
        g.add(row)
        return g

    def _set_wallpaper(self, _btn, key):
        bg = Gio.Settings.new("org.gnome.desktop.background")
        bg.set_string("picture-uri", f"file://{WALLPAPER_DIR}/{key}-light.png")
        bg.set_string("picture-uri-dark", f"file://{WALLPAPER_DIR}/{key}-dark.png")
        self.toast("Wallpaper changed")

    # -- extra apps -------------------------------------------------------------------------
    def _apps_group(self):
        g = Adw.PreferencesGroup(
            title="Extra apps",
            description="Installed from Flathub. Inkscape and OBS Studio are not on the disc to keep it small.")
        for app_id, title, sub, kind, target in APPS:
            row = Adw.ActionRow(title=title, subtitle=sub)
            btn = Gtk.Button(label="Install", valign=Gtk.Align.CENTER)
            btn.add_css_class("suggested-action")
            btn.connect("clicked", self._install, app_id, kind, target)
            row.add_suffix(btn)
            g.add(row)
            self.app_rows[app_id] = (row, btn)
        threading.Thread(target=self._refresh_installed, daemon=True).start()
        return g

    def _refresh_installed(self):
        if not shutil.which("flatpak"):
            return
        for app_id, _t, _s, kind, target in APPS:
            if kind == "flatpak" and flatpak_installed(target):
                GLib.idle_add(self._mark_installed, app_id)

    def _mark_installed(self, app_id):
        _row, btn = self.app_rows[app_id]
        btn.set_label("Installed")
        btn.set_sensitive(False)
        btn.remove_css_class("suggested-action")
        return False

    def _install(self, btn, app_id, kind, target):
        btn.set_sensitive(False)
        btn.set_label("Installing…")

        def work():
            if kind == "flatpak":
                rc, out = run(["flatpak", "install", "--system", "-y", "--noninteractive", "flathub", target])
                if rc != 0:  # fall back to a per-user install (no admin prompt needed)
                    rc, out = run(["flatpak", "install", "--user", "-y", "--noninteractive", "flathub", target])
                ok = rc == 0
            else:
                # Needs the user to accept an EULA, so it runs in a terminal.
                rc, out = run(["gnome-terminal", "--wait", "--", "bash", "-c",
                               f"sudo apt-get install -y {target}; echo; read -rp 'Press Enter to close…'"])
                ok = rc == 0
            if ok:
                GLib.idle_add(self._mark_installed, app_id)
                self.toast(f"{target if kind != 'flatpak' else app_id} installed")
            else:
                def reset():
                    btn.set_sensitive(True)
                    btn.set_label("Retry")
                    return False
                GLib.idle_add(reset)
                self.toast("Install failed — check your internet connection")
        threading.Thread(target=work, daemon=True).start()

    # -- updates -------------------------------------------------------------------------
    def _updates_group(self):
        g = Adw.PreferencesGroup(title="Updates")
        self.update_row = Adw.ActionRow(title="Check for updates", subtitle="System packages, apps and firmware")
        self.spinner = Gtk.Spinner()
        chk = Gtk.Button(label="Check now", valign=Gtk.Align.CENTER)
        chk.connect("clicked", self._check_updates)
        upd = Gtk.Button(label="Update everything", valign=Gtk.Align.CENTER)
        upd.add_css_class("suggested-action")
        upd.connect("clicked", lambda *_: subprocess.Popen(
            ["gnome-terminal", "--", "deluxe-update", "--pause"]))
        for w in (self.spinner, chk, upd):
            self.update_row.add_suffix(w)
        g.add(self.update_row)
        return g

    def _check_updates(self, _btn):
        self.spinner.start()
        self.update_row.set_subtitle("Checking…")

        def work():
            rc, out = run(["deluxe-update", "--check", "--no-firmware"], timeout=180)
            lines = [ln.strip() for ln in out.splitlines() if ":" in ln]
            msg = "; ".join(lines) if rc == 0 and lines else "Could not check (are you online?)"

            def done():
                self.spinner.stop()
                self.update_row.set_subtitle(msg)
                return False
            GLib.idle_add(done)
        threading.Thread(target=work, daemon=True).start()


class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.FLAGS_NONE)

    def do_activate(self):
        win = self.props.active_window or Welcome(self)
        win.present()


if __name__ == "__main__":
    sys.exit(App().run(sys.argv))
