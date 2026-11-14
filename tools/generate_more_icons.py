#!/usr/bin/env python3
"""
tools/generate_more_icons.py
Generates additional high-resolution vector UI icons using rsvg-convert:
- icon_calendar.png (Daily Shift logistics calendar)
- icon_flame.png (Streak fire icon)
- icon_sector_1.png (Cargo Bay crate icon)
- icon_sector_2.png (Cold Storage frost icon)
- icon_sector_3.png (Cyber Depot bolt icon)
- icon_sector_4.png (Quantum Vault atom icon)
"""
import os
import subprocess
import shutil
import io
from PIL import Image

OUT_DIR = "assets/icons"
os.makedirs(OUT_DIR, exist_ok=True)

def render_svg_to_png(svg_str, filename, size=64):
    p = subprocess.Popen(["rsvg-convert", "-w", str(size * 4), "-h", str(size * 4)],
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    out, _ = p.communicate(input=svg_str.encode("utf-8"))
    im_large = Image.open(io.BytesIO(out))
    im_out = im_large.resize((size, size), Image.Resampling.LANCZOS)
    out_path = os.path.join(OUT_DIR, filename)
    im_out.save(out_path, format="PNG")
    print(f"Generated {out_path} ({size}x{size})")


def make_calendar():
    svg = """<svg viewBox="-32 -32 576 576" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-20%" y="-20%" width="150%" height="150%">
      <feDropShadow dx="8" dy="16" stdDeviation="12" flood-color="#000000" flood-opacity="0.45"/>
    </filter>
    <linearGradient id="bodyGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="100%" stop-color="#E2E8F0"/>
    </linearGradient>
    <linearGradient id="hdrGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F59E0B"/>
      <stop offset="100%" stop-color="#D97706"/>
    </linearGradient>
    <linearGradient id="ringGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#CBD5E1"/>
      <stop offset="100%" stop-color="#64748B"/>
    </linearGradient>
  </defs>
  <g filter="url(#shadow)">
    <!-- Calendar Body -->
    <rect x="32" y="64" width="448" height="416" rx="40" fill="url(#bodyGrad)" stroke="#1E293B" stroke-width="20"/>
    <!-- Top Header Banner -->
    <path d="M 32 104 C 32 82 48 64 72 64 L 440 64 C 464 64 480 82 480 104 L 480 160 L 32 160 Z" fill="url(#hdrGrad)" stroke="#1E293B" stroke-width="20"/>
    
    <!-- Binder Rings -->
    <rect x="120" y="24" width="40" height="72" rx="16" fill="url(#ringGrad)" stroke="#1E293B" stroke-width="12"/>
    <rect x="352" y="24" width="40" height="72" rx="16" fill="url(#ringGrad)" stroke="#1E293B" stroke-width="12"/>
    
    <!-- Grid Squares (Warehouse Shift Days) -->
    <rect x="96" y="210" width="56" height="56" rx="10" fill="#94A3B8"/>
    <rect x="192" y="210" width="56" height="56" rx="10" fill="#94A3B8"/>
    <rect x="288" y="210" width="56" height="56" rx="10" fill="#94A3B8"/>
    <rect x="384" y="210" width="56" height="56" rx="10" fill="#F59E0B"/>
    
    <rect x="96" y="296" width="56" height="56" rx="10" fill="#94A3B8"/>
    <rect x="192" y="296" width="56" height="56" rx="10" fill="#94A3B8"/>
    <rect x="288" y="296" width="56" height="56" rx="10" fill="#10B981"/>
    <rect x="384" y="296" width="56" height="56" rx="10" fill="#10B981"/>
    
    <!-- Star Stamp on Current Day -->
    <path d="M 316 324 L 306 344 L 284 346 L 301 361 L 296 382 L 316 370 L 336 382 L 331 361 L 348 346 L 326 344 Z" fill="#FBBF24" stroke="#78350F" stroke-width="4"/>
  </g>
</svg>"""
    render_svg_to_png(svg, "icon_calendar.png")


def make_flame():
    svg = """<svg viewBox="-32 -32 448 576" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-20%" y="-20%" width="150%" height="150%">
      <feDropShadow dx="8" dy="16" stdDeviation="14" flood-color="#000000" flood-opacity="0.45"/>
    </filter>
    <linearGradient id="flameGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FEF08A"/>
      <stop offset="25%" stop-color="#F59E0B"/>
      <stop offset="70%" stop-color="#DC2626"/>
      <stop offset="100%" stop-color="#991B1B"/>
    </linearGradient>
    <linearGradient id="coreGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="60%" stop-color="#FDE047"/>
      <stop offset="100%" stop-color="#F97316"/>
    </linearGradient>
  </defs>
  <g filter="url(#shadow)">
    <!-- Outer Flame Body -->
    <path d="M 192 16 C 192 16 232 96 232 160 C 232 208 200 240 200 240 C 200 240 248 208 280 160 C 344 240 384 320 384 384 C 384 480 304 528 192 528 C 80 528 0 480 0 384 C 0 288 80 208 128 144 C 152 112 168 56 192 16 Z" fill="url(#flameGrad)" stroke="#1C1917" stroke-width="18" stroke-linejoin="round"/>
    
    <!-- Inner Radiant Core -->
    <path d="M 192 240 C 216 272 240 312 240 368 C 240 432 192 464 192 464 C 192 464 144 432 144 368 C 144 320 176 280 192 240 Z" fill="url(#coreGrad)"/>
    
    <!-- White-hot specular spark -->
    <ellipse cx="192" cy="384" rx="20" ry="32" fill="#FFFFFF" opacity="0.9"/>
  </g>
</svg>"""
    render_svg_to_png(svg, "icon_flame.png")


def make_sector_1_cargo():
    svg = """<svg viewBox="-32 -32 576 576" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-20%" y="-20%" width="150%" height="150%">
      <feDropShadow dx="8" dy="16" stdDeviation="12" flood-color="#000000" flood-opacity="0.45"/>
    </filter>
    <linearGradient id="woodGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#D97706"/>
      <stop offset="50%" stop-color="#B45309"/>
      <stop offset="100%" stop-color="#78350F"/>
    </linearGradient>
    <linearGradient id="metalGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#94A3B8"/>
      <stop offset="100%" stop-color="#334155"/>
    </linearGradient>
  </defs>
  <g filter="url(#shadow)">
    <!-- Crate Base -->
    <rect x="32" y="32" width="448" height="448" rx="24" fill="url(#woodGrad)" stroke="#1E1B18" stroke-width="20"/>
    
    <!-- Planks -->
    <line x1="32" y1="144" x2="480" y2="144" stroke="#451A03" stroke-width="8"/>
    <line x1="32" y1="256" x2="480" y2="256" stroke="#451A03" stroke-width="8"/>
    <line x1="32" y1="368" x2="480" y2="368" stroke="#451A03" stroke-width="8"/>
    
    <!-- Diagonal Cross Brace -->
    <line x1="56" y1="56" x2="456" y2="456" stroke="#F59E0B" stroke-width="36" stroke-linecap="round"/>
    <line x1="56" y1="56" x2="456" y2="456" stroke="#78350F" stroke-width="36" stroke-dasharray="12 12" stroke-linecap="round" opacity="0.3"/>
    
    <!-- Metal Corner Brackets -->
    <path d="M 32 144 L 32 32 L 144 32 L 144 72 L 72 72 L 72 144 Z" fill="url(#metalGrad)" stroke="#0F172A" stroke-width="8"/>
    <path d="M 480 144 L 480 32 L 368 32 L 368 72 L 440 72 L 440 144 Z" fill="url(#metalGrad)" stroke="#0F172A" stroke-width="8"/>
    <path d="M 32 368 L 32 480 L 144 480 L 144 440 L 72 440 L 72 368 Z" fill="url(#metalGrad)" stroke="#0F172A" stroke-width="8"/>
    <path d="M 480 368 L 480 480 L 368 480 L 368 440 L 440 440 L 440 368 Z" fill="url(#metalGrad)" stroke="#0F172A" stroke-width="8"/>
    
    <!-- Brass Center Stamp -->
    <polygon points="256,208 304,256 256,304 208,256" fill="#FDE047" stroke="#78350F" stroke-width="8"/>
  </g>
</svg>"""
    render_svg_to_png(svg, "icon_sector_1.png")


def make_sector_2_cold():
    svg = """<svg viewBox="-32 -32 576 576" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-20%" y="-20%" width="150%" height="150%">
      <feDropShadow dx="8" dy="16" stdDeviation="14" flood-color="#000000" flood-opacity="0.45"/>
    </filter>
    <linearGradient id="iceGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#E0F2FE"/>
      <stop offset="50%" stop-color="#38BDF8"/>
      <stop offset="100%" stop-color="#0284C7"/>
    </linearGradient>
  </defs>
  <g filter="url(#shadow)">
    <!-- Hexagonal Snowflake Center -->
    <circle cx="256" cy="256" r="48" fill="#F0F9FF" stroke="#0C4A6E" stroke-width="16"/>
    
    <!-- 6 Radial Spines -->
    <!-- Vertical -->
    <line x1="256" y1="32" x2="256" y2="480" stroke="url(#iceGrad)" stroke-width="32" stroke-linecap="round"/>
    <!-- Diagonal 1 -->
    <line x1="62" y1="144" x2="450" y2="368" stroke="url(#iceGrad)" stroke-width="32" stroke-linecap="round"/>
    <!-- Diagonal 2 -->
    <line x1="62" y1="368" x2="450" y2="144" stroke="url(#iceGrad)" stroke-width="32" stroke-linecap="round"/>
    
    <!-- Chevrons / Barbs on vertical -->
    <path d="M 200 96 L 256 152 L 312 96" fill="none" stroke="#E0F2FE" stroke-width="24" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 200 416 L 256 360 L 312 416" fill="none" stroke="#E0F2FE" stroke-width="24" stroke-linecap="round" stroke-linejoin="round"/>
    
    <!-- Chevrons on Diagonal 1 -->
    <path d="M 120 120 L 160 190 L 220 160" fill="none" stroke="#E0F2FE" stroke-width="24" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 392 392 L 352 322 L 292 352" fill="none" stroke="#E0F2FE" stroke-width="24" stroke-linecap="round" stroke-linejoin="round"/>
    
    <!-- Chevrons on Diagonal 2 -->
    <path d="M 120 392 L 160 322 L 220 352" fill="none" stroke="#E0F2FE" stroke-width="24" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 392 120 L 352 190 L 292 160" fill="none" stroke="#E0F2FE" stroke-width="24" stroke-linecap="round" stroke-linejoin="round"/>
    
    <!-- Center Crystal Core -->
    <polygon points="256,220 288,256 256,292 224,256" fill="#FFFFFF"/>
  </g>
</svg>"""
    render_svg_to_png(svg, "icon_sector_2.png")


def make_sector_3_cyber():
    svg = """<svg viewBox="-32 -32 576 576" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-20%" y="-20%" width="150%" height="150%">
      <feDropShadow dx="8" dy="16" stdDeviation="14" flood-color="#000000" flood-opacity="0.45"/>
    </filter>
    <linearGradient id="boltGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FEF08A"/>
      <stop offset="30%" stop-color="#FACC15"/>
      <stop offset="70%" stop-color="#EAB308"/>
      <stop offset="100%" stop-color="#CA8A04"/>
    </linearGradient>
  </defs>
  <g filter="url(#shadow)">
    <!-- Bold Lightning Bolt -->
    <polygon points="288,16 96,288 256,288 208,496 416,224 256,224" fill="url(#boltGrad)" stroke="#1E1B18" stroke-width="20" stroke-linejoin="round"/>
    
    <!-- Inner Core Specular Highlight -->
    <polygon points="278,64 148,272 260,272 220,440 376,236 264,236" fill="#FEF9C3" opacity="0.6"/>
  </g>
</svg>"""
    render_svg_to_png(svg, "icon_sector_3.png")


def make_sector_4_quantum():
    svg = """<svg viewBox="-32 -32 576 576" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-20%" y="-20%" width="150%" height="150%">
      <feDropShadow dx="8" dy="16" stdDeviation="14" flood-color="#000000" flood-opacity="0.45"/>
    </filter>
    <linearGradient id="coreGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F5D0FE"/>
      <stop offset="50%" stop-color="#C084FC"/>
      <stop offset="100%" stop-color="#7E22CE"/>
    </linearGradient>
    <linearGradient id="ringGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#E879F9"/>
      <stop offset="100%" stop-color="#A855F7"/>
    </linearGradient>
  </defs>
  <g filter="url(#shadow)">
    <!-- Orbital Ellipse 1 (Horizontal) -->
    <ellipse cx="256" cy="256" rx="224" ry="72" fill="none" stroke="url(#ringGrad)" stroke-width="28" transform="rotate(0 256 256)"/>
    <!-- Orbital Ellipse 2 (60 deg) -->
    <ellipse cx="256" cy="256" rx="224" ry="72" fill="none" stroke="url(#ringGrad)" stroke-width="28" transform="rotate(60 256 256)"/>
    <!-- Orbital Ellipse 3 (120 deg) -->
    <ellipse cx="256" cy="256" rx="224" ry="72" fill="none" stroke="url(#ringGrad)" stroke-width="28" transform="rotate(120 256 256)"/>
    
    <!-- Electrons on Orbits -->
    <circle cx="480" cy="256" r="24" fill="#FDF4FF" stroke="#581C87" stroke-width="8"/>
    <circle cx="144" cy="62" r="24" fill="#FDF4FF" stroke="#581C87" stroke-width="8"/>
    <circle cx="144" cy="450" r="24" fill="#FDF4FF" stroke="#581C87" stroke-width="8"/>
    
    <!-- Central Quantum Nucleus -->
    <circle cx="256" cy="256" r="56" fill="url(#coreGrad)" stroke="#3B0764" stroke-width="16"/>
    <circle cx="240" cy="240" r="16" fill="#FFFFFF" opacity="0.8"/>
  </g>
</svg>"""
    render_svg_to_png(svg, "icon_sector_4.png")


if __name__ == "__main__":
    make_calendar()
    make_flame()
    make_sector_1_cargo()
    make_sector_2_cold()
    make_sector_3_cyber()
    make_sector_4_quantum()
    print("All additional vector icons generated successfully!")

