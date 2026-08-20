#!/usr/bin/env python3
"""Fallback squircles (white on dark) for apps Lawnicons does not cover."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "theme/icons/Nothing/scalable/apps"
OUT.mkdir(parents=True, exist_ok=True)

def svg(inner: str, bg: str = "#1a1a1a") -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="28" fill="{bg}"/>
{inner}
</svg>
'''

W = "#ffffff"

icons = {
    "firefox": svg(
        f'''  <circle cx="64" cy="64" r="22" fill="none" stroke="{W}" stroke-width="6"/>
  <path d="M28 72 Q64 18 108 58" fill="none" stroke="{W}" stroke-width="8" stroke-linecap="round"/>'''
    ),
    "spotify": svg(
        f'''  <path d="M38 54 Q64 42 90 54" fill="none" stroke="{W}" stroke-width="7" stroke-linecap="round"/>
  <path d="M40 66 Q64 56 88 66" fill="none" stroke="{W}" stroke-width="6" stroke-linecap="round"/>
  <path d="M44 77 Q64 69 84 77" fill="none" stroke="{W}" stroke-width="5" stroke-linecap="round"/>'''
    ),
    "kitty": svg(
        f'''  <path d="M40 44 L56 64 L40 84" fill="none" stroke="{W}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M70 82 H92" fill="none" stroke="{W}" stroke-width="8" stroke-linecap="round"/>'''
    ),
    "vesktop": svg(
        f'''  <path d="M44 42 L84 42 L90 78 L64 90 L38 78 Z" fill="none" stroke="{W}" stroke-width="6" stroke-linejoin="round"/>
  <circle cx="54" cy="62" r="4" fill="{W}"/>
  <circle cx="74" cy="62" r="4" fill="{W}"/>'''
    ),
    "google-chrome": svg(
        f'''  <circle cx="64" cy="64" r="28" fill="none" stroke="{W}" stroke-width="7"/>
  <circle cx="64" cy="64" r="10" fill="{W}"/>'''
    ),
    "zen": svg(
        f'''  <circle cx="64" cy="64" r="24" fill="none" stroke="{W}" stroke-width="7"/>
  <circle cx="64" cy="64" r="8" fill="{W}"/>'''
    ),
    "org.kde.dolphin": svg(
        f'''  <path d="M34 56 H56 L64 48 H94 V86 H34 Z" fill="none" stroke="{W}" stroke-width="6" stroke-linejoin="round"/>
  <path d="M34 56 H94" fill="none" stroke="{W}" stroke-width="6"/>'''
    ),
    "code": svg(
        f'''  <path d="M48 40 L32 64 L48 88" fill="none" stroke="{W}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M80 40 L96 64 L80 88" fill="none" stroke="{W}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>'''
    ),
    "cursor": svg(
        f'''  <path d="M46 32 L46 92 L70 70 L86 96 L96 90 L78 62 L98 62 Z" fill="{W}"/>'''
    ),
    "helium-browser": svg(
        f'''  <circle cx="64" cy="64" r="26" fill="none" stroke="{W}" stroke-width="8"/>
  <circle cx="64" cy="64" r="8" fill="{W}"/>'''
    ),
    "obs": svg(
        f'''  <circle cx="64" cy="64" r="22" fill="none" stroke="{W}" stroke-width="7"/>
  <circle cx="64" cy="64" r="10" fill="{W}"/>'''
    ),
    # EndeavourOS triangle (sail), white on squircle - not the purple logo.
    "endeavouros": svg(
        f'''  <g transform="translate(14,18) scale(1.56)">
    <path fill="{W}" d="M34.682 15.269c7 6.985 15.691 15.691 15.691 22.228s-10.46 6.538-18.306 6.538H15.069z"/>
  </g>'''
    ),
}

icons["io.github.zen_browser.zen"] = icons["zen"]
icons["zen-browser"] = icons["zen"]
icons["spotify-client"] = icons["spotify"]
icons["co.anysphere.cursor"] = icons["cursor"]
icons["dolphin"] = icons["org.kde.dolphin"]
icons["code-oss"] = icons["code"]
icons["com.google.chrome"] = icons["google-chrome"]
icons["chromium"] = icons["google-chrome"]
icons["discord"] = icons["vesktop"]
icons["helium"] = icons["helium-browser"]
icons["com.obsproject.studio"] = icons["obs"]
icons["endeavouros-icon"] = icons["endeavouros"]
icons["distributor-logo-endeavouros"] = icons["endeavouros"]
icons["distributor-logo"] = icons["endeavouros"]

for name, body in icons.items():
    if not body:
        continue
    (OUT / f"{name}.svg").write_text(body)
    print(OUT / f"{name}.svg")
