#!/usr/bin/env python3
"""Generate every original piece of Deluxe System 1 artwork.

Outputs (all deterministic, so builds stay reproducible):
  * logo (gold "D1" on a dark gradient) as SVG + PNG sizes, hicolor icons
  * 5 wallpapers x (dark, light) as SVG sources + 2560x1440 PNG
  * Plymouth boot-splash images
  * GRUB background (installed system + ISO menu)
  * Calamares installer images

Needs only: python3 and rsvg-convert (package librsvg2-bin). No Ubuntu/Canonical artwork is used.
"""
import random
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OV = ROOT / "overlay"
NAVY0, NAVY1, NAVY2 = "#070c20", "#0e1738", "#1a2a63"
GOLD0, GOLD1, GOLD2 = "#ffe9a3", "#f5c542", "#c8921a"

RSVG = shutil.which("rsvg-convert")
if not RSVG:
    sys.exit("rsvg-convert not found (apt install librsvg2-bin)")


def write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def png(svg: Path, out: Path, w: int, h: int | None = None):
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = [RSVG, "-w", str(w)]
    if h:
        cmd += ["-h", str(h)]
    cmd += ["-o", str(out), str(svg)]
    subprocess.run(cmd, check=True)


# --------------------------------------------------------------------------- logo
def logo_svg(badge: bool = False) -> str:
    arrow = ""
    if badge:  # download arrow badge used for the "Install" launcher icon
        arrow = f"""
  <circle cx="196" cy="196" r="46" fill="{NAVY0}" stroke="url(#g)" stroke-width="6"/>
  <path d="M196 170 V210 M178 194 L196 212 L214 194" fill="none" stroke="url(#g)" stroke-width="10"
        stroke-linecap="round" stroke-linejoin="round"/>"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{NAVY2}"/><stop offset="0.55" stop-color="{NAVY1}"/><stop offset="1" stop-color="{NAVY0}"/>
    </linearGradient>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{GOLD0}"/><stop offset="0.5" stop-color="{GOLD1}"/><stop offset="1" stop-color="{GOLD2}"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.3" cy="0.2" r="0.9">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.16"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="256" height="256" rx="58" fill="url(#bg)"/>
  <rect width="256" height="256" rx="58" fill="url(#glow)"/>
  <rect x="5" y="5" width="246" height="246" rx="53" fill="none" stroke="url(#g)" stroke-opacity="0.45" stroke-width="2.5"/>
  <!-- D -->
  <path fill="url(#g)" fill-rule="evenodd"
        d="M40 62 H92 C128 62 150 88 150 128 C150 168 128 194 92 194 H40 Z
           M68 88 V168 H90 C110 168 122 154 122 128 C122 102 110 88 90 88 Z"/>
  <!-- 1 -->
  <path fill="url(#g)" d="M166 86 L190 62 H212 V194 H184 V98 L166 108 Z"/>{arrow}
</svg>
"""


def make_logo():
    svg = ROOT / "overlay/usr/share/pixmaps/deluxe-logo.svg"
    write(svg, logo_svg())
    inst = ROOT / "overlay/usr/share/pixmaps/deluxe-install.svg"
    write(inst, logo_svg(badge=True))
    png(svg, OV / "usr/share/pixmaps/deluxe-logo.png", 512)
    hic = OV / "usr/share/icons/hicolor"
    for name, src in (("deluxe-logo", svg), ("deluxe-welcome", svg), ("deluxe-install", inst)):
        write(hic / f"scalable/apps/{name}.svg", src.read_text())
        for s in (48, 64, 128, 256, 512):
            png(src, hic / f"{s}x{s}/apps/{name}.png", s)
    # Calamares
    cal = ROOT / "calamares/branding/deluxe"
    png(svg, cal / "logo.png", 256)
    png(svg, cal / "icon.png", 128)
    # Plymouth
    ply = OV / "usr/share/plymouth/themes/deluxe"
    png(svg, ply / "logo.png", 220)


# --------------------------------------------------------------------------- wallpapers
W, H = 2560, 1440
DARK = dict(bg=(NAVY0, NAVY1, NAVY2), a=GOLD1, b="#4f7cff", c="#8d5cff", line=0.55, mode="dark")
LIGHT = dict(bg=("#f4f6ff", "#e3e9ff", "#cfd9ff"), a="#d9a21b", b="#6a8dff", c="#a98aff", line=0.7, mode="light")


def defs_bg(p, gid="bg"):
    return (f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1">'
            f'<stop offset="0" stop-color="{p["bg"][0]}"/><stop offset="0.55" stop-color="{p["bg"][1]}"/>'
            f'<stop offset="1" stop-color="{p["bg"][2]}"/></linearGradient>')


def wall_aurora(p):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
<defs>{defs_bg(p)}
<filter id="b1" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="55"/></filter>
<filter id="b2" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="22"/></filter></defs>
<rect width="{W}" height="{H}" fill="url(#bg)"/>
<g filter="url(#b1)" opacity="{0.9 if p['mode']=='dark' else 0.65}">
<path d="M-100 900 C500 420 900 1100 1500 640 S2300 300 2700 560 L2700 760 C2300 560 1900 980 1400 940 S500 700 -100 1100Z" fill="{p['b']}" opacity="0.7"/>
<path d="M-100 1000 C400 650 1000 1200 1600 820 S2300 560 2700 800 L2700 930 C2300 760 1900 1160 1450 1120 S500 900 -100 1220Z" fill="{p['c']}" opacity="0.55"/>
<path d="M-100 1120 C500 880 1100 1300 1700 1010 S2300 840 2700 1000 L2700 1080 C2300 960 1900 1290 1500 1260 S600 1080 -100 1330Z" fill="{p['a']}" opacity="0.8"/>
</g>
<g filter="url(#b2)" opacity="0.55"><path d="M-100 1060 C500 800 1100 1250 1700 940 S2300 800 2700 950" fill="none" stroke="{p['a']}" stroke-width="10"/></g>
</svg>"""


def wall_dunes(p):
    layers = []
    cols = [p["b"], p["c"], p["a"]] if p["mode"] == "dark" else [p["b"], p["c"], p["a"]]
    for i, (y, amp, op) in enumerate([(700, 140, 0.35), (860, 190, 0.5), (1020, 230, 0.7), (1180, 260, 0.9)]):
        col = cols[min(i, 2)]
        d = f"M0 {y} C400 {y-amp} 800 {y+amp} 1280 {y} S2100 {y-amp} {W} {y+amp//2} V{H} H0Z"
        layers.append(f'<path d="{d}" fill="{col}" opacity="{op}"/>')
    sun = f'<circle cx="1850" cy="470" r="150" fill="{p["a"]}" opacity="{0.9 if p["mode"]=="dark" else 0.75}"/>'
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
<defs>{defs_bg(p)}<filter id="s"><feGaussianBlur stdDeviation="3"/></filter></defs>
<rect width="{W}" height="{H}" fill="url(#bg)"/>{sun}
<g filter="url(#s)">{''.join(layers)}</g></svg>"""


def wall_horizon(p):
    lines = []
    cx, hy = W / 2, 860
    for i in range(-24, 25):
        lines.append(f'<line x1="{cx + i*28}" y1="{hy}" x2="{cx + i*260}" y2="{H}" />')
    y, step = hy, 12
    while y < H:
        lines.append(f'<line x1="0" y1="{y:.0f}" x2="{W}" y2="{y:.0f}" />')
        step *= 1.32
        y += step
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
<defs>{defs_bg(p)}
<linearGradient id="sun" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{GOLD0}"/><stop offset="1" stop-color="{p['a']}"/></linearGradient>
<clipPath id="c"><rect width="{W}" height="{hy}"/></clipPath></defs>
<rect width="{W}" height="{H}" fill="url(#bg)"/>
<g clip-path="url(#c)"><circle cx="{cx}" cy="{hy}" r="330" fill="url(#sun)" opacity="0.92"/>
<g stroke="{p['bg'][0]}" stroke-width="9" opacity="0.8"><line x1="0" y1="640" x2="{W}" y2="640"/><line x1="0" y1="720" x2="{W}" y2="720"/><line x1="0" y1="790" x2="{W}" y2="790"/><line x1="0" y1="845" x2="{W}" y2="845"/></g></g>
<rect y="{hy}" width="{W}" height="{H-hy}" fill="{p['bg'][1]}" opacity="0.65"/>
<g stroke="{p['b']}" stroke-opacity="{p['line']}" stroke-width="2.5">{''.join(lines)}</g></svg>"""


def wall_orbits(p):
    rings, dots = [], []
    cx, cy = W * 0.68, H * 0.5
    rnd = random.Random(11)
    for i in range(1, 15):
        r = 90 + i * 85
        rings.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{p["a"] if i % 4 == 0 else p["b"]}" '
                     f'stroke-opacity="{0.55 if i % 4 == 0 else 0.28}" stroke-width="{3 if i % 4 == 0 else 1.6}"/>')
        a = rnd.random() * 6.283
        import math
        dots.append(f'<circle cx="{cx + r*math.cos(a):.1f}" cy="{cy + r*math.sin(a):.1f}" r="{6 + (i % 3)*3}" fill="{p["a"]}"/>')
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
<defs>{defs_bg(p)}<radialGradient id="rg" cx="{cx/W}" cy="{cy/H}" r="0.6">
<stop offset="0" stop-color="{p['c']}" stop-opacity="0.55"/><stop offset="1" stop-color="{p['c']}" stop-opacity="0"/></radialGradient></defs>
<rect width="{W}" height="{H}" fill="url(#bg)"/><rect width="{W}" height="{H}" fill="url(#rg)"/>
{''.join(rings)}{''.join(dots)}<circle cx="{cx}" cy="{cy}" r="56" fill="{p['a']}"/></svg>"""


def wall_facets(p):
    rnd = random.Random(2026)
    cols, rows = 16, 9
    cw, ch = W / cols, H / rows
    pts = [[(x * cw + (rnd.uniform(-.35, .35) * cw if 0 < x < cols else 0),
             y * ch + (rnd.uniform(-.35, .35) * ch if 0 < y < rows else 0))
            for x in range(cols + 1)] for y in range(rows + 1)]

    def mix(t):
        stops = [p["bg"][0], p["bg"][2], p["c"], p["a"]] if p["mode"] == "dark" else [p["bg"][0], p["bg"][2], p["b"], p["a"]]
        t = max(0, min(0.999, t)) * (len(stops) - 1)
        i, f = int(t), t - int(t)
        a, b = stops[i], stops[i + 1]
        ca = [int(a[k:k + 2], 16) for k in (1, 3, 5)]
        cb = [int(b[k:k + 2], 16) for k in (1, 3, 5)]
        return "#%02x%02x%02x" % tuple(int(ca[j] + (cb[j] - ca[j]) * f) for j in range(3))

    polys = []
    for y in range(rows):
        for x in range(cols):
            a, b, c, d = pts[y][x], pts[y][x + 1], pts[y + 1][x + 1], pts[y + 1][x]
            base = (x / cols) * 0.55 + (y / rows) * 0.35
            for tri in ((a, b, c), (a, c, d)):
                t = base + rnd.uniform(-0.12, 0.12)
                poly = " ".join(f"{px:.1f},{py:.1f}" for px, py in tri)
                polys.append(f'<polygon points="{poly}" fill="{mix(t)}" stroke="{mix(t)}" stroke-width="1"/>')
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
<rect width="{W}" height="{H}" fill="{p['bg'][0]}"/>{''.join(polys)}</svg>"""


WALLPAPERS = {"aurora": wall_aurora, "dunes": wall_dunes, "horizon": wall_horizon,
              "orbits": wall_orbits, "facets": wall_facets}
WALL_TITLES = {"aurora": "Aurora", "dunes": "Golden Dunes", "horizon": "Horizon Grid",
               "orbits": "Orbits", "facets": "Facets"}


def make_wallpapers():
    base = OV / "usr/share/backgrounds/deluxe"
    for name, fn in WALLPAPERS.items():
        for tag, pal in (("dark", DARK), ("light", LIGHT)):
            svg = base / "svg" / f"{name}-{tag}.svg"
            write(svg, fn(pal))
            png(svg, base / f"{name}-{tag}.png", W, H)
    xml = ['<?xml version="1.0"?>',
           '<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">', "<wallpapers>"]
    for name in WALLPAPERS:
        xml.append(f"""  <wallpaper deleted="false">
    <name>{WALL_TITLES[name]}</name>
    <filename>/usr/share/backgrounds/deluxe/{name}-light.png</filename>
    <filename-dark>/usr/share/backgrounds/deluxe/{name}-dark.png</filename-dark>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#0e1738</pcolor>
    <scolor>#0e1738</scolor>
  </wallpaper>""")
    xml.append("</wallpapers>\n")
    write(OV / "usr/share/gnome-background-properties/deluxe-wallpapers.xml", "\n".join(xml))


# --------------------------------------------------------------------------- plymouth
def make_plymouth():
    ply = OV / "usr/share/plymouth/themes/deluxe"
    tmp = ROOT / "build" / "tmp-assets"
    tmp.mkdir(parents=True, exist_ok=True)
    bar = lambda fill: (f'<svg xmlns="http://www.w3.org/2000/svg" width="300" height="6" viewBox="0 0 300 6">'
                        f'<rect width="300" height="6" rx="3" fill="{fill}"/></svg>')
    for name, fill in (("bar-bg", "#ffffff22"), ("bar-fg", GOLD1)):
        s = tmp / f"{name}.svg"
        write(s, bar(fill))
        png(s, ply / f"{name}.png", 300, 6)
    s = tmp / "bullet.svg"
    write(s, f'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><circle cx="8" cy="8" r="6" fill="{GOLD1}"/></svg>')
    png(s, ply / "bullet.png", 16, 16)
    s = tmp / "box.svg"
    write(s, '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="40"><rect x="1" y="1" width="318" height="38" rx="10" '
             f'fill="#ffffff14" stroke="{GOLD1}" stroke-opacity="0.6" stroke-width="2"/></svg>')
    png(s, ply / "box.png", 320, 40)


# --------------------------------------------------------------------------- grub
def grub_bg_svg(w=1920, h=1080):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">
<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{NAVY0}"/><stop offset="1" stop-color="{NAVY2}"/></linearGradient>
<filter id="b"><feGaussianBlur stdDeviation="70"/></filter></defs>
<rect width="{w}" height="{h}" fill="url(#bg)"/>
<g filter="url(#b)" opacity="0.8"><ellipse cx="{w*0.8}" cy="{h*0.95}" rx="620" ry="200" fill="#4f7cff" opacity="0.5"/>
<ellipse cx="{w*0.35}" cy="{h*1.02}" rx="700" ry="170" fill="{GOLD1}" opacity="0.45"/></g></svg>"""


def make_grub():
    th = OV / "usr/share/grub/themes/deluxe"
    tmp = ROOT / "build" / "tmp-assets"
    tmp.mkdir(parents=True, exist_ok=True)
    s = tmp / "grub-bg.svg"
    write(s, grub_bg_svg())
    png(s, th / "background.png", 1920, 1080)
    png(ROOT / "overlay/usr/share/pixmaps/deluxe-logo.svg", th / "logo.png", 128)
    # Flat 9-slice centres for the selected menu item and the timeout bar
    for name, fill in (("select_c", GOLD1), ("progress_bar_c", "#ffffff22"), ("progress_highlight_c", GOLD1)):
        sv = tmp / f"{name}.svg"
        write(sv, f'<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8" fill="{fill}"/></svg>')
        png(sv, th / f"{name}.png", 8, 8)


# --------------------------------------------------------------------------- calamares
def make_calamares():
    cal = ROOT / "calamares/branding/deluxe"
    tmp = ROOT / "build" / "tmp-assets"
    tmp.mkdir(parents=True, exist_ok=True)
    import base64
    subprocess.run([RSVG, "-w", "170", "-o", str(tmp / "welcome-logo.png"),
                    str(ROOT / "overlay/usr/share/pixmaps/deluxe-logo.svg")], check=True)
    b64 = base64.b64encode((tmp / "welcome-logo.png").read_bytes()).decode()
    s = tmp / "welcome.svg"
    write(s, f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 640 360" width="640" height="360">
<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{NAVY1}"/><stop offset="1" stop-color="{NAVY0}"/></linearGradient>
<filter id="b"><feGaussianBlur stdDeviation="28"/></filter></defs>
<rect width="640" height="360" rx="22" fill="url(#bg)"/>
<g filter="url(#b)" opacity="0.8"><ellipse cx="470" cy="330" rx="260" ry="70" fill="#4f7cff" opacity="0.6"/><ellipse cx="190" cy="350" rx="270" ry="60" fill="{GOLD1}" opacity="0.55"/></g>
<image x="235" y="95" width="170" height="170" xlink:href="data:image/png;base64,{b64}"/></svg>""")
    png(s, cal / "welcome.png", 640, 360)


def main():
    make_logo()
    make_wallpapers()
    make_plymouth()
    make_grub()
    make_calamares()
    print("assets OK")


if __name__ == "__main__":
    main()
