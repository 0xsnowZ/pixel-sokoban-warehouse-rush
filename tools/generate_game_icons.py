#!/usr/bin/env python3
"""
tools/generate_game_icons.py

Generates the unified high-resolution vector UI icon kit for Pixel Sokoban: Warehouse Rush
using rsvg-convert (256x256 supersampled -> 64x64 Lanczos PNG) with cohesive
#0F172A dark outlines, metallic bevel gradients, and soft drop shadows.
"""

import io
import os
import shutil
import subprocess
from PIL import Image, ImageDraw

OUT_DIR = "assets/icons"
os.makedirs(OUT_DIR, exist_ok=True)

SHARED_DEFS = """
    <filter id="shadow" x="-20%" y="-20%" width="150%" height="150%">
      <feDropShadow dx="0" dy="14" stdDeviation="12" flood-color="#000000" flood-opacity="0.52"/>
    </filter>
    <linearGradient id="goldGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FEF08A"/>
      <stop offset="35%" stop-color="#FBBF24"/>
      <stop offset="80%" stop-color="#D97706"/>
      <stop offset="100%" stop-color="#92400E"/>
    </linearGradient>
    <linearGradient id="goldVert" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FFFDE7"/>
      <stop offset="28%" stop-color="#FDE047"/>
      <stop offset="70%" stop-color="#F59E0B"/>
      <stop offset="100%" stop-color="#B45309"/>
    </linearGradient>
    <linearGradient id="steelGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F8FAFC"/>
      <stop offset="35%" stop-color="#CBD5E1"/>
      <stop offset="75%" stop-color="#64748B"/>
      <stop offset="100%" stop-color="#334155"/>
    </linearGradient>
    <linearGradient id="cyanGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#E0F2FE"/>
      <stop offset="35%" stop-color="#38BDF8"/>
      <stop offset="85%" stop-color="#0284C7"/>
      <stop offset="100%" stop-color="#0369A1"/>
    </linearGradient>
    <linearGradient id="orangeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFEDD5"/>
      <stop offset="30%" stop-color="#FB923C"/>
      <stop offset="80%" stop-color="#EA580C"/>
      <stop offset="100%" stop-color="#9A3412"/>
    </linearGradient>
    <linearGradient id="emeraldGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#DCFCE7"/>
      <stop offset="35%" stop-color="#4ADE80"/>
      <stop offset="80%" stop-color="#16A34A"/>
      <stop offset="100%" stop-color="#14532D"/>
    </linearGradient>
    <linearGradient id="crimsonGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FECACA"/>
      <stop offset="35%" stop-color="#EF4444"/>
      <stop offset="100%" stop-color="#991B1B"/>
    </linearGradient>
    <linearGradient id="ivoryGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="65%" stop-color="#FEF3C7"/>
      <stop offset="100%" stop-color="#FDE68A"/>
    </linearGradient>
"""


def render_svg_icon(svg_body: str, out_name: str, viewbox: str = "-32 -32 576 576", size: int = 64) -> None:
    """Renders an SVG markup fragment with shared hardware defs to a crisp supersampled PNG."""
    svg_doc = f'<svg viewBox="{viewbox}" xmlns="http://www.w3.org/2000/svg"><defs>{SHARED_DEFS}</defs>{svg_body}</svg>'
    path = os.path.join(OUT_DIR, out_name)
    if shutil.which("rsvg-convert"):
        p = subprocess.Popen(
            ["rsvg-convert", "-w", str(size * 4), "-h", str(size * 4)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
        )
        out, _ = p.communicate(input=svg_doc.encode("utf-8"))
        im_large = Image.open(io.BytesIO(out)).convert("RGBA")
        res = im_large.resize((size, size), Image.Resampling.LANCZOS)
        res.save(path, format="PNG")
        print(f"Generated {path} ({size}x{size} SVG)")
    else:
        im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([8, 8, size - 8, size - 8], radius=10, fill=(245, 180, 30, 255))
        im.save(path, format="PNG")
        print(f"Generated {path} (PIL fallback)")


def make_home() -> None:
    body = """
  <g filter="url(#shadow)">
    <path fill="url(#goldGrad)" stroke="#0F172A" stroke-width="26" stroke-linejoin="round"
          d="M575.8 255.5C575.8 273.5 560.8 287.5 542.8 287.5H512V443.5C512 479.5 482.5 509.5 446.5 509.5H352C335.3 509.5 320 495.7 320 478.5V383.5C320 366.1 305.9 351.5 288 351.5C270.1 351.5 256 366.1 256 383.5V478.5C256 495.7 240.7 509.5 224 509.5H129.5C93.53 509.5 64 479.5 64 443.5V287.5H33.22C15.22 287.5 .3033 273.5 .3033 255.5C.3033 246.7 3.923 238.3 10.15 232.2L273.4 8.711C281.4 1.748 294.6 1.748 302.6 8.711L565.8 232.2C572.2 238.3 575.8 246.7 575.8 255.5z"/>
    <path fill="none" stroke="#FFFFFF" stroke-linecap="round" stroke-width="18" opacity="0.82" d="M56 244L288 52"/>
    <path fill="#0F172A" d="M244 378C244 353 263 334 288 334C313 334 332 353 332 378V496H244V378z" opacity="0.65"/>
  </g>"""
    render_svg_icon(body, "icon_home.png", viewbox="-64 -48 704 608")


def make_music_on() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- Beamed Double Eighth Notes -->
    <path d="M 176 352 L 176 96 L 432 56 L 432 312" fill="none" stroke="#0F172A" stroke-width="64" stroke-linecap="round" stroke-linejoin="round"/>
    <ellipse cx="132" cy="368" rx="74" ry="56" transform="rotate(-18 132 368)" fill="#0F172A"/>
    <ellipse cx="388" cy="328" rx="74" ry="56" transform="rotate(-18 388 328)" fill="#0F172A"/>

    <path d="M 176 352 L 176 96 L 432 56 L 432 312" fill="none" stroke="url(#goldVert)" stroke-width="38" stroke-linecap="round" stroke-linejoin="round"/>
    <polygon points="157,74 451,28 451,106 157,152" fill="url(#goldVert)" stroke="#0F172A" stroke-width="20" stroke-linejoin="round"/>
    <line x1="176" y1="88" x2="432" y2="48" stroke="#FFFFFF" stroke-width="10" stroke-linecap="round" opacity="0.85"/>

    <ellipse cx="132" cy="368" rx="60" ry="44" transform="rotate(-18 132 368)" fill="url(#goldGrad)" stroke="#0F172A" stroke-width="14"/>
    <ellipse cx="118" cy="356" rx="22" ry="12" transform="rotate(-18 118 356)" fill="#FFFFFF" opacity="0.72"/>

    <ellipse cx="388" cy="328" rx="60" ry="44" transform="rotate(-18 388 328)" fill="url(#goldGrad)" stroke="#0F172A" stroke-width="14"/>
    <ellipse cx="374" cy="316" rx="22" ry="12" transform="rotate(-18 374 316)" fill="#FFFFFF" opacity="0.72"/>

    <!-- Specular Sparkle -->
    <polygon points="96,42 106,66 130,76 106,86 96,110 86,86 62,76 86,66" fill="#FEF08A" stroke="#0F172A" stroke-width="8"/>
  </g>"""
    render_svg_icon(body, "icon_music_on.png")


def make_music_off() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- Brushed Steel Muted Notes -->
    <g opacity="0.88">
      <path d="M 176 352 L 176 96 L 432 56 L 432 312" fill="none" stroke="#0F172A" stroke-width="64" stroke-linecap="round" stroke-linejoin="round"/>
      <ellipse cx="132" cy="368" rx="74" ry="56" transform="rotate(-18 132 368)" fill="#0F172A"/>
      <ellipse cx="388" cy="328" rx="74" ry="56" transform="rotate(-18 388 328)" fill="#0F172A"/>
      <path d="M 176 352 L 176 96 L 432 56 L 432 312" fill="none" stroke="url(#steelGrad)" stroke-width="38" stroke-linecap="round" stroke-linejoin="round"/>
      <polygon points="157,74 451,28 451,106 157,152" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="20" stroke-linejoin="round"/>
      <ellipse cx="132" cy="368" rx="60" ry="44" transform="rotate(-18 132 368)" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="14"/>
      <ellipse cx="388" cy="328" rx="60" ry="44" transform="rotate(-18 388 328)" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="14"/>
    </g>

    <!-- Bold Outlined Crimson Slash -->
    <line x1="60" y1="60" x2="452" y2="452" stroke="#0F172A" stroke-width="68" stroke-linecap="round"/>
    <line x1="60" y1="60" x2="452" y2="452" stroke="url(#crimsonGrad)" stroke-width="40" stroke-linecap="round"/>
    <line x1="68" y1="54" x2="444" y2="430" stroke="#FECACA" stroke-width="8" stroke-linecap="round" opacity="0.85"/>
  </g>"""
    render_svg_icon(body, "icon_music_off.png")


def make_control_swipe() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- Directional Swipe Motion Chevrons (high-visibility arcs near index finger) -->
    <path d="M 142 78 L 76 132 L 142 186" fill="none" stroke="#0F172A" stroke-width="52" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 142 78 L 76 132 L 142 186" fill="none" stroke="url(#cyanGrad)" stroke-width="28" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 370 78 L 436 132 L 370 186" fill="none" stroke="#0F172A" stroke-width="52" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 370 78 L 436 132 L 370 186" fill="none" stroke="url(#cyanGrad)" stroke-width="28" stroke-linecap="round" stroke-linejoin="round"/>

    <!-- Index Hand Silhouette scaled boldly to fill HUD icon cleanly -->
    <g transform="translate(56, 68) scale(5.6)">
      <path fill="url(#goldGrad)" d="M55.36,33.7297c-0.38-1.44-1.66-2.53-3.23-2.6c-1.67-0.07-3.12,1.04-3.52,2.6h-0.19 c0,0.02,0.01,0.05,0.01,0.08c-0.01-0.03-0.01-0.06-0.02-0.08v-0.0099c0,0,0,0,0-0.01c-0.11-0.56-0.35-1.06-0.69-1.49 c-0.06-0.08-0.1299-0.16-0.21-0.2401c-0.17-0.18-0.35-0.34-0.56-0.47c-0.07-0.05-0.14-0.1-0.21-0.14c-0.17-0.1-0.34-0.18-0.52-0.25 c-0.1-0.04-0.2-0.07-0.3-0.09c-0.12-0.04-0.25-0.07-0.38-0.09c-0.08-0.01-0.16-0.02-0.24-0.03h-0.04c-0.01,0-0.01,0-0.02,0 c-0.09-0.01-0.17-0.01-0.26-0.01c-0.12,0-0.23,0-0.34,0.02c-0.23,0.02-0.44,0.06-0.65,0.12c-0.43,0.13-0.83,0.34-1.18,0.6201 c-0.08,0.06-0.16,0.1299-0.24,0.21c-0.09,0.07-0.16,0.15-0.23,0.24c-0.07,0.08-0.14,0.16-0.2,0.25c-0.06,0.09-0.12,0.18-0.18,0.28 c-0.11,0.19-0.2,0.39-0.28,0.6c-0.05,0.16-0.1,0.32-0.12,0.49h-0.13c-0.12-1.72-1.49-3.12-3.26-3.23c-1.74-0.11-3.25,1.06-3.63,2.7 v0.58l-0.09-0.01v-22.37c0-0.11-0.01-0.23-0.02-0.34c-0.17-1.78-1.65-3.16-3.48-3.16c-1.93,0-3.5,1.56-3.5,3.5v24.27l0.02,0.03 l-0.02,1.25v-1.28l-0.79-1.0699l-1.35-1.83l-0.69,0.45c-0.22-0.23-0.51-0.48-0.87-0.71l-0.01-0.01c-1.8-1.28-5-2.58-6.16-1.46 c-1.35,1.3101-0.56,4.23,4.86,11.3701c0.99,20.84,8.68,19.56,16.58,21.69c7.66,0.71,16.13-6.3101,16.25-18.14h0.21v-11.34 C55.48,34.3098,55.44,34.0198,55.36,33.7297z"/>
      <g fill="none" stroke="#0F172A" stroke-linecap="round" stroke-linejoin="round" stroke-width="3.2">
        <path d="M55.4792,47.6473c0,9.0883-7.3675,16.4558-16.4558,16.4558s-16.4558-7.3675-16.4558-16.4558"/>
        <line x1="55.4792" x2="55.4792" y1="46.7738" y2="34.7738"/>
        <path d="M48.4869,34.4804c0.081-1.9313,1.7123-3.4313,3.6436-3.3502c1.9313,0.081,3.4312,1.7123,3.3502,3.6436"/>
        <path d="M41.49,34.2475c0.081-1.9313,1.7123-3.4312,3.6436-3.3502s3.4313,1.7123,3.3502,3.6436"/>
        <path d="M34.4524,33.7692c0.1237-1.929,1.7878-3.3925,3.7168-3.2688s3.3925,1.7878,3.2688,3.7168"/>
        <path d="M17.4986,35.9928c-1.3429-1.3904-1.3044-3.6061,0.086-4.949c1.3904-1.3429,3.6061-1.3044,4.949,0.086"/>
        <path d="M27.4524,11.3969c0-1.933,1.567-3.5,3.5-3.5s3.5,1.567,3.5,3.5"/>
        <line x1="34.4524" x2="34.4524" y1="33.7321" y2="11.3969"/>
        <line x1="27.4524" x2="27.4524" y1="11.3969" y2="39.1875"/>
        <line x1="24.4916" x2="22.5336" y1="33.3435" y2="31.1298"/>
        <path d="M19.2663,38.3125c1.9526,2.1439,3.3734,5.1677,3.3013,9.5218"/>
        <line x1="17.4986" x2="19.32" y1="35.9928" y2="38.373"/>
      </g>
      <line x1="29.5" y1="11" x2="29.5" y2="28" stroke="#FFFFFF" stroke-linecap="round" stroke-width="1.6" opacity="0.85"/>
    </g>
  </g>"""
    render_svg_icon(body, "icon_control_swipe.png")


def make_control_dpad() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- Industrial Cross D-Pad -->
    <path d="M 184 44 H 328 V 184 H 468 V 328 H 328 V 468 H 184 V 328 H 44 V 184 H 184 Z"
          fill="url(#goldGrad)" stroke="#0F172A" stroke-width="28" stroke-linejoin="round"/>
    <line x1="196" y1="58" x2="316" y2="58" stroke="#FFFFFF" stroke-width="10" stroke-linecap="round" opacity="0.7"/>
    <line x1="58" y1="198" x2="176" y2="198" stroke="#FFFFFF" stroke-width="10" stroke-linecap="round" opacity="0.7"/>
    <!-- Recessed Pivot Socket -->
    <circle cx="256" cy="256" r="42" fill="#0F172A"/>
    <circle cx="256" cy="256" r="28" fill="#334155" stroke="#FEF08A" stroke-width="5"/>
    <!-- 4 Crisp Directional Triangles -->
    <polygon points="256,74 294,132 218,132" fill="#FFFBEB" stroke="#0F172A" stroke-width="10" stroke-linejoin="round"/>
    <polygon points="256,438 294,380 218,380" fill="#FFFBEB" stroke="#0F172A" stroke-width="10" stroke-linejoin="round"/>
    <polygon points="74,256 132,218 132,294" fill="#FFFBEB" stroke="#0F172A" stroke-width="10" stroke-linejoin="round"/>
    <polygon points="438,256 380,218 380,294" fill="#FFFBEB" stroke="#0F172A" stroke-width="10" stroke-linejoin="round"/>
  </g>"""
    render_svg_icon(body, "icon_control_dpad.png")


def make_control_gamepad() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- Retro Dual-Control Arcade Controller -->
    <rect x="32" y="132" width="448" height="248" rx="116" fill="url(#goldGrad)" stroke="#0F172A" stroke-width="26"/>
    <rect x="64" y="160" width="384" height="192" rx="90" fill="#B45309" opacity="0.25"/>
    <path d="M 140 150 H 372" fill="none" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round" opacity="0.75"/>

    <!-- Gunmetal Left Mini D-Pad -->
    <path d="M 134 202 H 170 V 238 H 206 V 274 H 170 V 310 H 134 V 274 H 98 V 238 H 134 Z"
          fill="#1E293B" stroke="#0F172A" stroke-width="12" stroke-linejoin="round"/>
    <circle cx="152" cy="256" r="10" fill="#64748B"/>

    <!-- Center LED Indicator -->
    <circle cx="256" cy="256" r="18" fill="#0F172A"/>
    <circle cx="256" cy="256" r="10" fill="#FFFFFF"/>

    <!-- Right Arcade Action Buttons (Cyan & Crimson) -->
    <circle cx="338" cy="284" r="32" fill="url(#cyanGrad)" stroke="#0F172A" stroke-width="12"/>
    <circle cx="330" cy="276" r="8" fill="#FFFFFF" opacity="0.8"/>
    <circle cx="394" cy="224" r="32" fill="url(#crimsonGrad)" stroke="#0F172A" stroke-width="12"/>
    <circle cx="386" cy="216" r="8" fill="#FFFFFF" opacity="0.8"/>
  </g>"""
    render_svg_icon(body, "icon_control_gamepad.png")


def make_dpad_arrow(angle_deg: int, name: str) -> None:
    body = f"""
  <g filter="url(#shadow)" transform="rotate({angle_deg} 256 256)">
    <polygon points="256,88 436,288 370,354 256,232 142,354 76,288"
             fill="url(#goldVert)" stroke="#0F172A" stroke-width="28" stroke-linejoin="round"/>
    <polyline points="104,284 256,118 408,284" fill="none" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" opacity="0.8"/>
  </g>"""
    render_svg_icon(body, name)


def make_undo() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- Bold Cyan U-Turn Rewind Arrow -->
    <path d="M 190 144 H 316 C 398 144, 444 196, 444 276 C 444 356, 398 408, 316 408 H 184"
          fill="none" stroke="#0F172A" stroke-width="102" stroke-linecap="round" stroke-linejoin="round"/>
    <polygon points="48,148 212,38 212,258" fill="#0F172A" stroke="#0F172A" stroke-width="34" stroke-linejoin="round"/>

    <path d="M 190 144 H 316 C 398 144, 444 196, 444 276 C 444 356, 398 408, 316 408 H 184"
          fill="none" stroke="url(#cyanGrad)" stroke-width="58" stroke-linecap="round" stroke-linejoin="round"/>
    <polygon points="56,148 206,48 206,248" fill="url(#cyanGrad)"/>

    <!-- Specular Top Bevel -->
    <path d="M 186 128 H 316 C 378 128, 418 166, 428 228"
          fill="none" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round" opacity="0.72"/>
    <line x1="78" y1="142" x2="196" y2="62" stroke="#FFFFFF" stroke-width="10" stroke-linecap="round" opacity="0.78"/>
  </g>"""
    render_svg_icon(body, "icon_undo.png")


def make_restart() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- Circular Clockwise Reset Arrow -->
    <path d="M 380 146 C 344 102, 294 82, 240 84 C 142 88, 72 168, 76 266 C 80 364, 158 432, 256 432 C 338 432, 404 380, 424 304"
          fill="none" stroke="#0F172A" stroke-width="96" stroke-linecap="round"/>
    <polygon points="462,214 432,56 300,176" fill="#0F172A" stroke="#0F172A" stroke-width="30" stroke-linejoin="round"/>

    <path d="M 380 146 C 344 102, 294 82, 240 84 C 142 88, 72 168, 76 266 C 80 364, 158 432, 256 432 C 338 432, 404 380, 424 304"
          fill="none" stroke="url(#orangeGrad)" stroke-width="54" stroke-linecap="round"/>
    <polygon points="454,206 426,64 310,170" fill="url(#orangeGrad)"/>

    <!-- Highlight Rim -->
    <path d="M 136 138 C 176 100, 232 88, 294 100" fill="none" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round" opacity="0.75"/>
  </g>"""
    render_svg_icon(body, "icon_restart.png")


def make_back() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- Dedicated Navigation Back Chevron Bar (Steel & Brass Trim) -->
    <rect x="64" y="96" width="56" height="320" rx="20" fill="url(#goldGrad)" stroke="#0F172A" stroke-width="24"/>
    <polygon points="154,256 346,84 428,158 312,256 428,354 346,428"
             fill="url(#steelGrad)" stroke="#0F172A" stroke-width="26" stroke-linejoin="round"/>
    <polyline points="178,256 344,106 404,160" fill="none" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" opacity="0.82"/>
  </g>"""
    render_svg_icon(body, "icon_back.png")


def make_hint() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- Outer Light Rays -->
    <g stroke="#0F172A" stroke-width="34" stroke-linecap="round">
      <line x1="256" y1="30" x2="256" y2="70"/>
      <line x1="94" y1="96" x2="124" y2="126"/>
      <line x1="418" y1="96" x2="388" y2="126"/>
      <line x1="36" y1="224" x2="78" y2="224"/>
      <line x1="476" y1="224" x2="434" y2="224"/>
    </g>
    <g stroke="#FDE047" stroke-width="18" stroke-linecap="round">
      <line x1="256" y1="30" x2="256" y2="70"/>
      <line x1="94" y1="96" x2="124" y2="126"/>
      <line x1="418" y1="96" x2="388" y2="126"/>
      <line x1="36" y1="224" x2="78" y2="224"/>
      <line x1="476" y1="224" x2="434" y2="224"/>
    </g>

    <!-- Bulb Glass Body -->
    <path d="M 140 228 C 140 160, 192 108, 256 108 C 320 108, 372 160, 372 228 C 372 276, 336 308, 326 356 H 186 C 176 308, 140 276, 140 228 Z"
          fill="url(#goldVert)" stroke="#0F172A" stroke-width="26" stroke-linejoin="round"/>
    <!-- Specular Glass Crescent -->
    <path d="M 176 208 C 178 166, 206 138, 246 134" fill="none" stroke="#FFFFFF" stroke-width="14" stroke-linecap="round" opacity="0.88"/>
    <!-- Crisp Filament -->
    <polyline points="218,324 218,244 238,214 256,238 274,214 294,244 294,324"
              fill="none" stroke="#FFFFFF" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>

    <!-- Industrial Brass Screw Base -->
    <rect x="184" y="356" width="144" height="84" rx="18" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="24"/>
    <line x1="196" y1="386" x2="316" y2="386" stroke="#0F172A" stroke-width="12" stroke-linecap="round"/>
    <line x1="196" y1="414" x2="316" y2="414" stroke="#0F172A" stroke-width="12" stroke-linecap="round"/>
    <rect x="218" y="440" width="76" height="32" rx="14" fill="#334155" stroke="#0F172A" stroke-width="18"/>
  </g>"""
    render_svg_icon(body, "icon_hint.png")


def make_star(is_full: bool = True) -> None:
    if is_full:
        body = """
  <g filter="url(#shadow)">
    <polygon fill="url(#goldVert)" stroke="#0F172A" stroke-width="22" stroke-linejoin="round"
             points="256,24 326,170 488,192 370,306 398,468 256,392 114,468 142,306 24,192 186,170"/>
    <polygon fill="#FFFFFF" opacity="0.42"
             points="256,52 314,174 446,196 340,264 256,226"/>
  </g>"""
        render_svg_icon(body, "icon_star_full.png", viewbox="-40 -40 592 592")
    else:
        body = """
  <g>
    <polygon fill="#1E293B" stroke="#64748B" stroke-width="24" stroke-linejoin="round" opacity="0.88"
             points="256,24 326,170 488,192 370,306 398,468 256,392 114,468 142,306 24,192 186,170"/>
  </g>"""
        render_svg_icon(body, "icon_star_empty.png", viewbox="-40 -40 592 592")


def make_trophy() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- Side Handles -->
    <path d="M 134 118 H 64 C 46 118, 42 134, 46 164 C 54 226, 98 264, 152 268"
          fill="none" stroke="#0F172A" stroke-width="46" stroke-linecap="round"/>
    <path d="M 134 118 H 64 C 46 118, 42 134, 46 164 C 54 226, 98 264, 152 268"
          fill="none" stroke="url(#goldGrad)" stroke-width="22" stroke-linecap="round"/>
    <path d="M 378 118 H 448 C 466 118, 470 134, 466 164 C 458 226, 414 264, 360 268"
          fill="none" stroke="#0F172A" stroke-width="46" stroke-linecap="round"/>
    <path d="M 378 118 H 448 C 466 118, 470 134, 466 164 C 458 226, 414 264, 360 268"
          fill="none" stroke="url(#goldGrad)" stroke-width="22" stroke-linecap="round"/>

    <!-- Stem & Plinth -->
    <rect x="226" y="300" width="60" height="84" fill="url(#goldGrad)" stroke="#0F172A" stroke-width="20"/>
    <rect x="156" y="370" width="200" height="36" rx="10" fill="url(#goldGrad)" stroke="#0F172A" stroke-width="20"/>
    <rect x="120" y="402" width="272" height="62" rx="14" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="22"/>
    <rect x="196" y="422" width="120" height="22" rx="6" fill="#FBBF24" stroke="#0F172A" stroke-width="8"/>

    <!-- Chalice Cup -->
    <path d="M 118 76 H 394 L 372 220 C 362 288, 314 326, 256 326 C 198 326, 150 288, 140 220 Z"
          fill="url(#goldVert)" stroke="#0F172A" stroke-width="24" stroke-linejoin="round"/>
    <ellipse cx="256" cy="76" rx="138" ry="26" fill="#FEF08A" stroke="#0F172A" stroke-width="20"/>
    <!-- Embossed Star -->
    <polygon points="256,144 274,190 322,196 286,230 296,278 256,254 216,278 226,230 190,196 238,190"
             fill="#FFFBEB" stroke="#92400E" stroke-width="10" stroke-linejoin="round"/>
  </g>"""
    render_svg_icon(body, "icon_trophy.png")


def make_crown() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- 3-Spire Master Par Golden Crown -->
    <path d="M 68 364 L 46 154 L 164 246 L 256 96 L 348 246 L 466 154 L 444 364 Z"
          fill="url(#goldVert)" stroke="#0F172A" stroke-width="26" stroke-linejoin="round"/>
    <!-- Left & Right Highlight Facets -->
    <polygon points="256,120 338,256 256,348 174,256" fill="#FFFFFF" opacity="0.28"/>

    <!-- Heavy Crown Base Band -->
    <rect x="64" y="348" width="384" height="68" rx="18" fill="url(#goldGrad)" stroke="#0F172A" stroke-width="24"/>
    <line x1="88" y1="368" x2="424" y2="368" stroke="#FFFFFF" stroke-width="8" stroke-linecap="round" opacity="0.65"/>

    <!-- Central Diamond Cabochon -->
    <polygon points="256,226 292,268 256,310 220,268" fill="url(#cyanGrad)" stroke="#0F172A" stroke-width="14" stroke-linejoin="round"/>
    <!-- Spire Tip Pearls -->
    <circle cx="46" cy="144" r="24" fill="#FEF08A" stroke="#0F172A" stroke-width="14"/>
    <circle cx="256" cy="86" r="28" fill="#FFFBEB" stroke="#0F172A" stroke-width="14"/>
    <circle cx="466" cy="144" r="24" fill="#FEF08A" stroke="#0F172A" stroke-width="14"/>
  </g>"""
    render_svg_icon(body, "icon_crown.png")


def make_settings() -> None:
    import math
    # Build crisp 8-tooth industrial steel gear path
    cx, cy = 256.0, 256.0
    r_out, r_in = 208.0, 152.0
    teeth = 8
    pts = []
    for i in range(teeth):
        base_a = i * (2.0 * math.pi / teeth)
        step = (2.0 * math.pi / teeth) / 4.0
        for r, offset in [
            (r_in, -1.6 * step),
            (r_out, -0.8 * step),
            (r_out, 0.8 * step),
            (r_in, 1.6 * step),
        ]:
            ang = base_a + offset
            pts.append(f"{cx + math.cos(ang)*r:.1f},{cy + math.sin(ang)*r:.1f}")
    poly_pts = " ".join(pts)

    body = f"""
  <g filter="url(#shadow)">
    <!-- Brushed Steel 8-Tooth Industrial Gear -->
    <polygon points="{poly_pts}" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="26" stroke-linejoin="round"/>
    <circle cx="256" cy="256" r="124" fill="none" stroke="#F8FAFC" stroke-width="10" opacity="0.55"/>
    <!-- Warm Brass Center Hub Ring & Recessed Axle -->
    <circle cx="256" cy="256" r="88" fill="url(#goldGrad)" stroke="#0F172A" stroke-width="20"/>
    <circle cx="256" cy="256" r="46" fill="#0F172A"/>
    <circle cx="256" cy="256" r="30" fill="#1E293B" stroke="#FBBF24" stroke-width="6"/>
  </g>"""
    render_svg_icon(body, "icon_settings.png")


def make_locker() -> None:
    body = """
  <g filter="url(#shadow)">
    <rect x="56" y="56" width="400" height="400" rx="44" fill="url(#goldGrad)" stroke="#0F172A" stroke-width="24"/>
    <rect x="76" y="76" width="360" height="360" rx="32" fill="none" stroke="url(#steelGrad)" stroke-width="32"/>
    <line x1="92" y1="92" x2="420" y2="420" stroke="#0F172A" stroke-width="38" stroke-linecap="round"/>
    <line x1="92" y1="92" x2="420" y2="420" stroke="url(#steelGrad)" stroke-width="26" stroke-linecap="round"/>
    <line x1="420" y1="92" x2="92" y2="420" stroke="#0F172A" stroke-width="38" stroke-linecap="round"/>
    <line x1="420" y1="92" x2="92" y2="420" stroke="url(#steelGrad)" stroke-width="26" stroke-linecap="round"/>
    <rect x="186" y="186" width="140" height="140" rx="28" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="16"/>
    <polygon points="256,206 270,242 306,256 270,270 256,306 242,270 206,256 242,242" fill="#FEF08A" stroke="#B45309" stroke-width="6"/>
    <path d="M 56 160 L 56 56 L 160 56 L 160 108 L 108 108 L 108 160 Z" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="14"/>
    <circle cx="88" cy="88" r="14" fill="#0F172A"/><circle cx="86" cy="86" r="6" fill="#F8FAFC"/>
    <path d="M 456 160 L 456 56 L 352 56 L 352 108 L 404 108 L 404 160 Z" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="14"/>
    <circle cx="424" cy="88" r="14" fill="#0F172A"/><circle cx="422" cy="86" r="6" fill="#F8FAFC"/>
    <path d="M 56 352 L 56 456 L 160 456 L 160 404 L 108 404 L 108 352 Z" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="14"/>
    <circle cx="88" cy="424" r="14" fill="#0F172A"/><circle cx="86" cy="422" r="6" fill="#F8FAFC"/>
    <path d="M 456 352 L 456 456 L 352 456 L 352 404 L 404 404 L 404 352 Z" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="14"/>
    <circle cx="424" cy="424" r="14" fill="#0F172A"/><circle cx="422" cy="422" r="6" fill="#F8FAFC"/>
  </g>"""
    render_svg_icon(body, "icon_locker.png", viewbox="0 0 512 512")


def make_lock() -> None:
    body = """
  <g filter="url(#shadow)">
    <path d="M 148 240 L 148 160 C 148 100, 196 52, 256 52 C 316 52, 364 100, 364 160 L 364 240"
          fill="none" stroke="#0F172A" stroke-width="68" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 148 240 L 148 160 C 148 100, 196 52, 256 52 C 316 52, 364 100, 364 160 L 364 240"
          fill="none" stroke="url(#steelGrad)" stroke-width="46" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 172 160 C 172 114, 210 76, 256 76" fill="none" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round" opacity="0.9"/>
    <rect x="80" y="200" width="352" height="260" rx="52" fill="#0F172A"/>
    <rect x="92" y="212" width="328" height="236" rx="40" fill="url(#goldGrad)" stroke="#78350F" stroke-width="12"/>
    <circle cx="126" cy="246" r="10" fill="#78350F"/><circle cx="124" cy="244" r="4" fill="#FEF08A"/>
    <circle cx="386" cy="246" r="10" fill="#78350F"/><circle cx="384" cy="244" r="4" fill="#FEF08A"/>
    <circle cx="126" cy="414" r="10" fill="#78350F"/><circle cx="124" cy="412" r="4" fill="#FEF08A"/>
    <circle cx="386" cy="414" r="10" fill="#78350F"/><circle cx="384" cy="412" r="4" fill="#FEF08A"/>
    <circle cx="256" cy="305" r="34" fill="#0F172A"/><circle cx="256" cy="305" r="26" fill="#1E293B"/>
    <polygon points="238,315 274,315 284,375 228,375" fill="#0F172A"/>
    <polygon points="242,318 270,318 278,368 234,368" fill="#1E293B"/>
  </g>"""
    render_svg_icon(body, "icon_lock.png", viewbox="0 0 512 512")


def make_play() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- Dark-Outlined High-Contrast Ivory/Gold Play Chevron (pops on amber PrimaryButton!) -->
    <polygon points="120,64 432,256 120,448"
             fill="url(#ivoryGrad)" stroke="#0F172A" stroke-width="34" stroke-linejoin="round"/>
    <polygon points="140,104 388,256 140,256" fill="#FFFFFF" opacity="0.65"/>
  </g>"""
    render_svg_icon(body, "icon_play.png")


def make_check() -> None:
    body = """
  <g filter="url(#shadow)">
    <polyline points="84,268 206,390 434,126" fill="none" stroke="#0F172A" stroke-width="96" stroke-linecap="round" stroke-linejoin="round"/>
    <polyline points="84,268 206,390 434,126" fill="none" stroke="url(#emeraldGrad)" stroke-width="58" stroke-linecap="round" stroke-linejoin="round"/>
    <polyline points="92,262 206,376 426,120" fill="none" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" opacity="0.72"/>
  </g>"""
    render_svg_icon(body, "icon_check.png")


def make_levels() -> None:
    body = """
  <g filter="url(#shadow)">
    <!-- 2x2 Warehouse Freight Bay Grid -->
    <rect x="64" y="64" width="168" height="168" rx="28" fill="url(#goldGrad)" stroke="#0F172A" stroke-width="26"/>
    <line x1="88" y1="88" x2="208" y2="88" stroke="#FFFFFF" stroke-width="10" stroke-linecap="round" opacity="0.7"/>
    <rect x="280" y="64" width="168" height="168" rx="28" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="26"/>
    <rect x="64" y="280" width="168" height="168" rx="28" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="26"/>
    <rect x="280" y="280" width="168" height="168" rx="28" fill="url(#steelGrad)" stroke="#0F172A" stroke-width="26"/>
  </g>"""
    render_svg_icon(body, "icon_levels.png")


def main() -> None:
    make_home()
    make_music_on()
    make_music_off()
    make_control_swipe()
    make_control_dpad()
    make_control_gamepad()
    make_dpad_arrow(0, "icon_dpad_up.png")
    make_dpad_arrow(180, "icon_dpad_down.png")
    make_dpad_arrow(270, "icon_dpad_left.png")
    make_dpad_arrow(90, "icon_dpad_right.png")
    make_undo()
    make_restart()
    make_back()
    make_hint()
    make_star(True)
    make_star(False)
    make_trophy()
    make_crown()
    make_settings()
    make_locker()
    make_lock()
    make_play()
    make_check()
    make_levels()
    print("All unified SVG game icons generated successfully!")


if __name__ == "__main__":
    main()
