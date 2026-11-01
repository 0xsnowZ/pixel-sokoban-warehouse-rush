import os
import math
from PIL import Image, ImageDraw, ImageFilter

SS = 4
SIZE = 64 * SS  # 256x256 internal canvas
OUT_DIR = "assets/icons"
os.makedirs(OUT_DIR, exist_ok=True)

def new_canvas():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

def save_icon(img: Image.Image, name: str):
    res = img.resize((64, 64), Image.Resampling.LANCZOS)
    path = os.path.join(OUT_DIR, name)
    res.save(path, format="PNG")
    print(f"Generated {path}")

# ==========================================
# 1. icon_home.png (Solid Golden Home / Depot)
# ==========================================
def make_home():
    import subprocess
    import shutil
    import io

    svg_content = """<svg viewBox="-64 -48 704 608" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-20%" y="-20%" width="150%" height="150%">
      <feDropShadow dx="12" dy="20" stdDeviation="14" flood-color="#000000" flood-opacity="0.45"/>
    </filter>
    <linearGradient id="goldGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFF59D"/>
      <stop offset="35%" stop-color="#FDD835"/>
      <stop offset="85%" stop-color="#FB8C00"/>
      <stop offset="100%" stop-color="#E65100"/>
    </linearGradient>
  </defs>
  <g filter="url(#shadow)">
    <!-- Main House Silhouette -->
    <path fill="url(#goldGrad)" stroke="#1E1B18" stroke-width="24" stroke-linejoin="round" d="M575.8 255.5C575.8 273.5 560.8 287.5 542.8 287.5H512V443.5C512 479.5 482.5 509.5 446.5 509.5H352C335.3 509.5 320 495.7 320 478.5V383.5C320 366.1 305.9 351.5 288 351.5C270.1 351.5 256 366.1 256 383.5V478.5C256 495.7 240.7 509.5 224 509.5H129.5C93.53 509.5 64 479.5 64 443.5V287.5H33.22C15.22 287.5 .3033 273.5 .3033 255.5C.3033 246.7 3.923 238.3 10.15 232.2L273.4 8.711C281.4 1.748 294.6 1.748 302.6 8.711L565.8 232.2C572.2 238.3 575.8 246.7 575.8 255.5z"/>
    
    <!-- Roof Left Highlight Ridge -->
    <path fill="none" stroke="#FFFFFF" stroke-linecap="round" stroke-width="20" opacity="0.8" d="M56 244L288 52"/>
    <!-- Doorway Inset Arch -->
    <path fill="#1E1B18" d="M256 383.5C256 366.1 270.1 351.5 288 351.5C305.9 351.5 320 366.1 320 383.5V478.5C320 495.7 335.3 509.5 352 509.5H224C240.7 509.5 256 495.7 256 478.5V383.5z" opacity="0.4"/>
  </g>
</svg>"""

    if shutil.which("rsvg-convert"):
        p = subprocess.Popen(["rsvg-convert", "-w", "256", "-h", "256"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        out, _ = p.communicate(input=svg_content.encode("utf-8"))
        im_large = Image.open(io.BytesIO(out))
        res = im_large.resize((64, 64), Image.Resampling.LANCZOS)
        path = os.path.join(OUT_DIR, "icon_home.png")
        res.save(path, format="PNG")
        print(f"Generated {path} (Solid Golden Home)")
    else:
        im = new_canvas()
        save_icon(im, "icon_home.png")

# ==========================================
# 2. icon_music_on.png & icon_music_off.png
# ==========================================
def make_music_on():
    im = new_canvas()
    d = ImageDraw.Draw(im)
    
    # Shadow
    d.ellipse([58, 170, 108, 214], fill=(0, 0, 0, 90))
    d.ellipse([154, 140, 204, 184], fill=(0, 0, 0, 90))

    col_gold = (250, 195, 40, 255)
    col_hilite = (255, 245, 190, 255)
    col_dark = (175, 110, 10, 255)

    # Noteheads (rotated ellipses)
    d.ellipse([54, 162, 104, 206], fill=col_gold, outline=col_dark, width=5)
    d.ellipse([64, 170, 84, 190], fill=col_hilite)
    d.ellipse([150, 132, 200, 176], fill=col_gold, outline=col_dark, width=5)
    d.ellipse([160, 140, 180, 160], fill=col_hilite)

    # Stems
    d.rectangle([94, 60, 106, 184], fill=col_gold)
    d.line([(95, 60), (95, 184)], fill=col_hilite, width=3)
    d.rectangle([190, 42, 202, 154], fill=col_gold)
    d.line([(191, 42), (191, 154)], fill=col_hilite, width=3)

    # Top Beam
    pts = [(94, 60), (202, 42), (202, 74), (94, 92)]
    d.polygon(pts, fill=col_gold)
    d.line([(94, 60), (202, 42)], fill=col_hilite, width=5)
    d.line([(94, 92), (202, 74)], fill=col_dark, width=4)

    # Sparkle glint
    d.line([(128, 30), (128, 42)], fill=(255, 255, 255, 230), width=3)
    d.line([(122, 36), (134, 36)], fill=(255, 255, 255, 230), width=3)

    save_icon(im, "icon_music_on.png")

def make_music_off():
    im = new_canvas()
    d = ImageDraw.Draw(im)

    col_slate = (110, 125, 145, 255)
    col_dark = (55, 68, 85, 255)

    # Noteheads
    d.ellipse([54, 162, 104, 206], fill=col_slate, outline=col_dark, width=5)
    d.ellipse([150, 132, 200, 176], fill=col_slate, outline=col_dark, width=5)
    # Stems
    d.rectangle([94, 60, 106, 184], fill=col_slate)
    d.rectangle([190, 42, 202, 154], fill=col_slate)
    # Beam
    d.polygon([(94, 60), (202, 42), (202, 74), (94, 92)], fill=col_slate)

    # Red Slash Bar
    d.line([(38, 38), (218, 218)], fill=(0, 0, 0, 140), width=24)
    d.line([(40, 40), (216, 216)], fill=(235, 55, 60, 255), width=18)
    d.line([(42, 38), (218, 214)], fill=(255, 140, 140, 255), width=4)

    save_icon(im, "icon_music_off.png")

# ==========================================
# 3. Control Mode Icons (Swipe, DPad, Gamepad)
# ==========================================
def make_control_swipe():
    # Canonical Backhand Index Pointing Up Hand Icon (👆)
    import subprocess
    import shutil

    svg_data = """<svg id="emoji" viewBox="0 0 72 72" version="1.1" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-20%" y="-20%" width="150%" height="150%">
      <feDropShadow dx="1.5" dy="2.5" stdDeviation="1.8" flood-color="#000000" flood-opacity="0.45"/>
    </filter>
    <linearGradient id="goldGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFF176"/>
      <stop offset="45%" stop-color="#FDD835"/>
      <stop offset="100%" stop-color="#F57F17"/>
    </linearGradient>
  </defs>
  <g filter="url(#shadow)">
    <path fill="url(#goldGrad)" d="M55.36,33.7297c-0.38-1.44-1.66-2.53-3.23-2.6c-1.67-0.07-3.12,1.04-3.52,2.6h-0.19 c0,0.02,0.01,0.05,0.01,0.08c-0.01-0.03-0.01-0.06-0.02-0.08v-0.0099c0,0,0,0,0-0.01c-0.11-0.56-0.35-1.06-0.69-1.49 c-0.06-0.08-0.1299-0.16-0.21-0.2401c-0.17-0.18-0.35-0.34-0.56-0.47c-0.07-0.05-0.14-0.1-0.21-0.14c-0.17-0.1-0.34-0.18-0.52-0.25 c-0.1-0.04-0.2-0.07-0.3-0.09c-0.12-0.04-0.25-0.07-0.38-0.09c-0.08-0.01-0.16-0.02-0.24-0.03h-0.04c-0.01,0-0.01,0-0.02,0 c-0.09-0.01-0.17-0.01-0.26-0.01c-0.12,0-0.23,0-0.34,0.02c-0.23,0.02-0.44,0.06-0.65,0.12c-0.43,0.13-0.83,0.34-1.18,0.6201 c-0.08,0.06-0.16,0.1299-0.24,0.21c-0.09,0.07-0.16,0.15-0.23,0.24c-0.07,0.08-0.14,0.16-0.2,0.25c-0.06,0.09-0.12,0.18-0.18,0.28 c-0.11,0.19-0.2,0.39-0.28,0.6c-0.05,0.16-0.1,0.32-0.12,0.49h-0.13c-0.12-1.72-1.49-3.12-3.26-3.23c-1.74-0.11-3.25,1.06-3.63,2.7 v0.58l-0.09-0.01v-22.37c0-0.11-0.01-0.23-0.02-0.34c-0.17-1.78-1.65-3.16-3.48-3.16c-1.93,0-3.5,1.56-3.5,3.5v24.27l0.02,0.03 l-0.02,1.25v-1.28l-0.79-1.0699l-1.35-1.83l-0.69,0.45c-0.22-0.23-0.51-0.48-0.87-0.71l-0.01-0.01c-1.8-1.28-5-2.58-6.16-1.46 c-1.35,1.3101-0.56,4.23,4.86,11.3701c0.99,20.84,8.68,19.56,16.58,21.69c7.66,0.71,16.13-6.3101,16.25-18.14h0.21v-11.34 C55.48,34.3098,55.44,34.0198,55.36,33.7297z M41.5,34.1097h-0.01c0.01-0.07,0.01-0.14,0.03-0.21 C41.51,33.9698,41.5,34.0397,41.5,34.1097z"/>
    <g fill="none" stroke="#1E1B18" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.4">
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
    <!-- Specular highlight facet on index finger -->
    <line x1="29.5" y1="11" x2="29.5" y2="28" stroke="#FFFFFF" stroke-linecap="round" stroke-width="1.4" opacity="0.8"/>
  </g>
</svg>"""

    if shutil.which("rsvg-convert"):
        p = subprocess.Popen(["rsvg-convert", "-w", "256", "-h", "256"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        out, _ = p.communicate(input=svg_data.encode("utf-8"))
        import io
        im_large = Image.open(io.BytesIO(out))
        res = im_large.resize((64, 64), Image.Resampling.LANCZOS)
        path = os.path.join(OUT_DIR, "icon_control_swipe.png")
        res.save(path, format="PNG")
        print(f"Generated {path} (👆 backhand index pointing up)")
    else:
        # Fallback to direct draw
        im = new_canvas()
        save_icon(im, "icon_control_swipe.png")

def make_control_dpad():
    im = new_canvas()
    d = ImageDraw.Draw(im)

    # Shadow
    d.rounded_rectangle([38, 102, 222, 162], radius=12, fill=(0, 0, 0, 80))
    d.rounded_rectangle([102, 38, 162, 222], radius=12, fill=(0, 0, 0, 80))

    # Base Cross
    d.rounded_rectangle([34, 96, 218, 156], radius=12, fill=(245, 180, 30, 255), outline=(160, 100, 10, 255), width=6)
    d.rounded_rectangle([96, 34, 156, 218], radius=12, fill=(245, 180, 30, 255), outline=(160, 100, 10, 255), width=6)
    # Central overlap fill
    d.rectangle([98, 98, 154, 154], fill=(245, 180, 30, 255))

    # Directional Arrows on Arms
    col_arrow = (255, 250, 220, 255)
    # Up
    d.polygon([(126, 48), (142, 68), (110, 68)], fill=col_arrow)
    # Down
    d.polygon([(126, 204), (142, 184), (110, 184)], fill=col_arrow)
    # Left
    d.polygon([(48, 126), (68, 110), (68, 142)], fill=col_arrow)
    # Right
    d.polygon([(204, 126), (184, 110), (184, 142)], fill=col_arrow)

    # Center Pivot
    d.ellipse([110, 110, 142, 142], fill=(180, 115, 15, 255), outline=(255, 230, 140, 255), width=3)
    save_icon(im, "icon_control_dpad.png")

def make_control_gamepad():
    im = new_canvas()
    d = ImageDraw.Draw(im)

    # Gamepad Console Body
    d.rounded_rectangle([30, 78, 226, 178], radius=38, fill=(16, 185, 129, 255), outline=(6, 95, 70, 255), width=6)
    # Grip accents
    d.rounded_rectangle([38, 86, 218, 170], radius=32, fill=(20, 150, 110, 255))
    # Bevel highlight
    d.arc([36, 82, 220, 172], start=180, end=360, fill=(110, 235, 185, 255), width=6)

    # Mini D-pad on Left
    d.rounded_rectangle([60, 118, 98, 138], radius=4, fill=(15, 23, 42, 255))
    d.rounded_rectangle([70, 108, 88, 148], radius=4, fill=(15, 23, 42, 255))

    # Action Buttons on Right
    d.ellipse([160, 126, 180, 146], fill=(245, 158, 11, 255), outline=(255, 220, 130, 255), width=3)
    d.ellipse([182, 106, 202, 126], fill=(239, 68, 68, 255), outline=(255, 180, 180, 255), width=3)

    # Screen / center LED
    d.ellipse([122, 122, 134, 134], fill=(56, 189, 248, 255))
    save_icon(im, "icon_control_gamepad.png")

# ==========================================
# 4. Directional D-Pad Arrow Chevrons
# ==========================================
def make_dpad_arrow(angle_deg, name):
    base = new_canvas()
    d = ImageDraw.Draw(base)

    # Up-pointing chevron
    pts = [
        (128, 44),
        (208, 136),
        (176, 168),
        (128, 114),
        (80, 168),
        (48, 136)
    ]
    # Shadow
    d.polygon([(x+4, y+6) for x, y in pts], fill=(0, 0, 0, 100))
    # Fill
    d.polygon(pts, fill=(245, 180, 30, 255))
    # Outline
    d.polygon(pts, outline=(150, 95, 10, 255))
    # Specular rim
    d.line([(48, 136), (128, 44), (208, 136)], fill=(255, 245, 190, 255), width=7)
    # Inner dark ridge
    d.line([(80, 168), (128, 114), (176, 168)], fill=(180, 110, 10, 255), width=6)

    # Rotate
    if angle_deg != 0:
        base = base.rotate(-angle_deg, resample=Image.Resampling.BICUBIC)

    save_icon(base, name)

# ==========================================
# 5. In-Game Action Icons (Undo, Restart, Hint)
# ==========================================
def make_undo():
    im = new_canvas()
    d = ImageDraw.Draw(im)

    def get_undo_pts(ox=0, oy=0):
        pts = []
        pts.append((32 + ox, 96 + oy))
        pts.append((96 + ox, 44 + oy))
        pts.append((88 + ox, 74 + oy))
        pts.append((156 + ox, 74 + oy))
        cx, cy = 156 + ox, 138 + oy
        r_out = 64
        for i in range(21):
            ang = -math.pi/2.0 + math.pi * (i / 20.0)
            pts.append((cx + math.cos(ang) * r_out, cy + math.sin(ang) * r_out))
        pts.append((108 + ox, 202 + oy))
        cap_cx, cap_cy = 108 + ox, 183 + oy
        cap_r = 19
        for i in range(11):
            ang = math.pi/2.0 + math.pi * (i / 10.0)
            pts.append((cap_cx + math.cos(ang) * cap_r, cap_cy + math.sin(ang) * cap_r))
        r_in = 26
        for i in range(21):
            ang = math.pi/2.0 - math.pi * (i / 20.0)
            pts.append((cx + math.cos(ang) * r_in, cy + math.sin(ang) * r_in))
        pts.append((88 + ox, 112 + oy))
        pts.append((96 + ox, 148 + oy))
        return pts

    # Shadow
    d.polygon(get_undo_pts(4, 6), fill=(0, 0, 0, 95))
    # Outer dark rim
    d.polygon(get_undo_pts(0, 0), fill=(24, 154, 211, 255), outline=(10, 45, 80, 255), width=8)
    # Core fill
    d.polygon(get_undo_pts(0, 0), fill=(45, 190, 245, 255))
    # Highlight facet
    d.line([(36, 96), (92, 48)], fill=(225, 248, 255, 255), width=6)
    d.line([(90, 75), (156, 75)], fill=(180, 235, 255, 255), width=5)
    cx, cy = 156, 138
    r_out = 64
    arc_pts = []
    for i in range(11):
        ang = -math.pi/2.0 + (math.pi/2.0) * (i / 10.0)
        arc_pts.append((cx + math.cos(ang) * r_out, cy + math.sin(ang) * r_out))
    d.line(arc_pts, fill=(180, 235, 255, 255), width=5)
    d.polygon(get_undo_pts(0, 0), outline=(12, 50, 90, 255), width=5)

    save_icon(im, "icon_undo.png")

def make_restart():
    im = new_canvas()
    d = ImageDraw.Draw(im)

    def get_restart_pts(ox=0, oy=0):
        pts = []
        pts.append((32, 96))
        pts.append((96, 44))
        pts.append((88, 74))
        pts.append((156, 74))
        cx, cy = 156, 138
        r_out = 64
        for i in range(21):
            ang = -math.pi/2.0 + math.pi * (i / 20.0)
            pts.append((cx + math.cos(ang) * r_out, cy + math.sin(ang) * r_out))
        pts.append((108, 202))
        cap_cx, cap_cy = 108, 183
        cap_r = 19
        for i in range(11):
            ang = math.pi/2.0 + math.pi * (i / 10.0)
            pts.append((cap_cx + math.cos(ang) * cap_r, cap_cy + math.sin(ang) * cap_r))
        r_in = 26
        for i in range(21):
            ang = math.pi/2.0 - math.pi * (i / 20.0)
            pts.append((cx + math.cos(ang) * r_in, cy + math.sin(ang) * r_in))
        pts.append((88, 112))
        pts.append((96, 148))
        res = []
        for x, y in pts:
            mirrored_x = 256 - x + ox
            res.append((mirrored_x, y + oy))
        return res

    d.polygon(get_restart_pts(4, 6), fill=(0, 0, 0, 95))
    d.polygon(get_restart_pts(0, 0), fill=(230, 95, 30, 255), outline=(90, 30, 10, 255), width=8)
    d.polygon(get_restart_pts(0, 0), fill=(251, 146, 60, 255))
    # Highlight
    d.line([(256-36, 96), (256-92, 48)], fill=(255, 235, 215, 255), width=6)
    d.line([(256-90, 75), (256-156, 75)], fill=(255, 215, 180, 255), width=5)
    cx_r, cy_r = 256-156, 138
    arc_pts_r = []
    for i in range(11):
        ang = -math.pi/2.0 - (math.pi/2.0) * (i / 10.0)
        arc_pts_r.append((cx_r + math.cos(ang) * 64, cy_r + math.sin(ang) * 64))
    d.line(arc_pts_r, fill=(255, 215, 180, 255), width=5)
    d.polygon(get_restart_pts(0, 0), outline=(95, 35, 10, 255), width=5)

    save_icon(im, "icon_restart.png")

def make_hint():
    im = new_canvas()
    d = ImageDraw.Draw(im)

    # Bulb Glow
    d.ellipse([50, 28, 206, 184], fill=(253, 224, 71, 70))

    # Bulb Dome
    d.ellipse([64, 40, 192, 168], fill=(253, 224, 71, 255), outline=(202, 138, 4, 255), width=7)
    # Glass highlight
    d.arc([76, 52, 180, 156], start=190, end=290, fill=(255, 255, 255, 220), width=9)

    # Tungsten Filament
    filament = [(110, 130), (120, 95), (136, 110), (146, 95), (146, 130)]
    d.line(filament, fill=(255, 255, 255, 255), width=6)

    # Screw Base
    d.rounded_rectangle([98, 162, 158, 208], radius=8, fill=(180, 130, 25, 255), outline=(115, 80, 10, 255), width=5)
    for y in [176, 192]:
        d.line([(102, y), (154, y)], fill=(245, 210, 110, 255), width=4)
    # Contact point
    d.rounded_rectangle([112, 206, 144, 218], radius=4, fill=(75, 85, 99, 255))

    # Sparkle rays
    for angle in [0, 45, 90, 135, 180]:
        rad = math.radians(angle)
        x1 = 128 - math.cos(rad) * 88
        y1 = 104 - math.sin(rad) * 88
        x2 = 128 - math.cos(rad) * 110
        y2 = 104 - math.sin(rad) * 110
        d.line([(x1, y1), (x2, y2)], fill=(250, 204, 21, 230), width=6)

    save_icon(im, "icon_hint.png")

# ==========================================
# 6. Star, Trophy, Settings, Locker
# ==========================================
def make_star(is_full=True):
    import subprocess
    import shutil
    import io

    if is_full:
        svg_content = """<svg viewBox="-40 -40 592 592" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="glow" x="-20%" y="-20%" width="150%" height="150%">
      <feDropShadow dx="0" dy="14" stdDeviation="12" flood-color="#000000" flood-opacity="0.40"/>
    </filter>
    <linearGradient id="gold" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FFFDE7"/>
      <stop offset="25%" stop-color="#FFEE58"/>
      <stop offset="65%" stop-color="#FDD835"/>
      <stop offset="100%" stop-color="#F57F17"/>
    </linearGradient>
    <linearGradient id="facet" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.75"/>
      <stop offset="100%" stop-color="#FFF9C4" stop-opacity="0.1"/>
    </linearGradient>
  </defs>
  <g filter="url(#glow)">
    <polygon fill="url(#gold)" stroke="#8D5B00" stroke-width="18" stroke-linejoin="round"
             points="256,24 326,170 488,192 370,306 398,468 256,392 114,468 142,306 24,192 186,170"/>
    <polygon fill="url(#facet)"
             points="256,54 316,170 440,192 344,286 256,220"/>
  </g>
</svg>"""
        out_name = "icon_star_full.png"
    else:
        svg_content = """<svg viewBox="-40 -40 592 592" xmlns="http://www.w3.org/2000/svg">
  <polygon fill="#1E293B" stroke="#64748B" stroke-width="22" stroke-linejoin="round" opacity="0.8"
           points="256,24 326,170 488,192 370,306 398,468 256,392 114,468 142,306 24,192 186,170"/>
</svg>"""
        out_name = "icon_star_empty.png"

    if shutil.which("rsvg-convert"):
        p = subprocess.Popen(["rsvg-convert", "-w", "256", "-h", "256"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        out, _ = p.communicate(input=svg_content.encode("utf-8"))
        im_large = Image.open(io.BytesIO(out))
        res = im_large.resize((64, 64), Image.Resampling.LANCZOS)
        path = os.path.join(OUT_DIR, out_name)
        res.save(path, format="PNG")
        print(f"Generated {path} (Crisp SVG Star)")
    else:
        im = new_canvas()
        save_icon(im, out_name)

def make_trophy():
    im = new_canvas()
    d = ImageDraw.Draw(im)

    # Base Plinth
    d.rounded_rectangle([72, 192, 184, 226], radius=8, fill=(30, 41, 59, 255), outline=(15, 23, 42, 255), width=6)
    d.rounded_rectangle([86, 172, 170, 196], radius=6, fill=(202, 138, 4, 255), outline=(161, 98, 7, 255), width=4)

    # Cup Body
    cup_pts = [
        (66, 60),
        (190, 60),
        (180, 136),
        (144, 172),
        (112, 172),
        (76, 136)
    ]
    d.polygon(cup_pts, fill=(245, 180, 25, 255), outline=(160, 100, 10, 255), width=6)
    # Cup rim
    d.ellipse([64, 50, 192, 70], fill=(255, 235, 130, 255), outline=(160, 100, 10, 255), width=5)

    # Handles
    d.arc([36, 65, 86, 130], start=90, end=270, fill=(245, 180, 25, 255), width=12)
    d.arc([170, 65, 220, 130], start=270, end=90, fill=(245, 180, 25, 255), width=12)

    # Center Star on Cup
    d.polygon([(128, 90), (133, 104), (148, 104), (136, 114), (140, 128), (128, 119), (116, 128), (120, 114), (108, 104), (123, 104)], fill=(255, 255, 255, 240))

    save_icon(im, "icon_trophy.png")

def make_settings():
    im = new_canvas()
    d = ImageDraw.Draw(im)

    center = (128, 128)
    r_outer = 104
    r_inner = 82
    teeth = 6
    pts = []
    for i in range(teeth * 2):
        a1 = i * (math.pi / teeth)
        a2 = a1 + (math.pi / (teeth * 2))
        pts.append((center[0] + math.cos(a1) * r_outer, center[1] + math.sin(a1) * r_outer))
        pts.append((center[0] + math.cos(a2) * r_inner, center[1] + math.sin(a2) * r_inner))

    # Shadow
    d.polygon([(x+4, y+6) for x, y in pts], fill=(0, 0, 0, 90))
    # Gear body
    d.polygon(pts, fill=(148, 163, 184, 255), outline=(51, 65, 85, 255), width=6)
    d.ellipse([center[0]-r_inner, center[1]-r_inner, center[0]+r_inner, center[1]+r_inner], fill=(148, 163, 184, 255), outline=(203, 213, 225, 255), width=5)

    # Axle Hole
    d.ellipse([center[0]-36, center[1]-36, center[0]+36, center[1]+36], fill=(30, 41, 59, 255), outline=(71, 85, 105, 255), width=6)
    # Keyway notch
    d.rectangle([center[0]-8, center[1]-44, center[0]+8, center[1]-26], fill=(30, 41, 59, 255))

    save_icon(im, "icon_settings.png")

def make_locker():
    import subprocess
    import shutil
    import io

    svg_depot = """<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-10%" y="-10%" width="130%" height="130%">
      <feDropShadow dx="0" dy="16" stdDeviation="12" flood-color="#000000" flood-opacity="0.6"/>
    </filter>
    <linearGradient id="crateBody" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FBBF24"/>
      <stop offset="40%" stop-color="#F59E0B"/>
      <stop offset="100%" stop-color="#B45309"/>
    </linearGradient>
    <linearGradient id="steelTrim" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F8FAFC"/>
      <stop offset="50%" stop-color="#94A3B8"/>
      <stop offset="100%" stop-color="#475569"/>
    </linearGradient>
    <linearGradient id="lidBand" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FEF3C7"/>
      <stop offset="100%" stop-color="#F59E0B"/>
    </linearGradient>
  </defs>
  <g filter="url(#shadow)">
    <!-- Main Crate Box -->
    <rect x="56" y="56" width="400" height="400" rx="44" fill="url(#crateBody)" stroke="#0F172A" stroke-width="24"/>
    
    <!-- Outer Heavy Steel Rim -->
    <rect x="76" y="76" width="360" height="360" rx="32" fill="none" stroke="url(#steelTrim)" stroke-width="32"/>

    <!-- Diagonal Steel Cross Braces -->
    <line x1="92" y1="92" x2="420" y2="420" stroke="#0F172A" stroke-width="38" stroke-linecap="round"/>
    <line x1="92" y1="92" x2="420" y2="420" stroke="url(#steelTrim)" stroke-width="26" stroke-linecap="round"/>
    
    <line x1="420" y1="92" x2="92" y2="420" stroke="#0F172A" stroke-width="38" stroke-linecap="round"/>
    <line x1="420" y1="92" x2="92" y2="420" stroke="url(#steelTrim)" stroke-width="26" stroke-linecap="round"/>

    <!-- Center Steel Hub Plate -->
    <rect x="186" y="186" width="140" height="140" rx="28" fill="url(#steelTrim)" stroke="#0F172A" stroke-width="16"/>
    <!-- Central Golden Supply Star / Diamond -->
    <polygon points="256,206 270,242 306,256 270,270 256,306 242,270 206,256 242,242" fill="#FEF08A" stroke="#B45309" stroke-width="6"/>

    <!-- 4 Corner Steel Reinforcement Braces with Rivets -->
    <!-- Top-Left -->
    <path d="M 56 160 L 56 56 L 160 56 L 160 108 L 108 108 L 108 160 Z" fill="url(#steelTrim)" stroke="#0F172A" stroke-width="14"/>
    <circle cx="88" cy="88" r="14" fill="#0F172A"/>
    <circle cx="86" cy="86" r="6" fill="#F8FAFC"/>

    <!-- Top-Right -->
    <path d="M 456 160 L 456 56 L 352 56 L 352 108 L 404 108 L 404 160 Z" fill="url(#steelTrim)" stroke="#0F172A" stroke-width="14"/>
    <circle cx="424" cy="88" r="14" fill="#0F172A"/>
    <circle cx="422" cy="86" r="6" fill="#F8FAFC"/>

    <!-- Bottom-Left -->
    <path d="M 56 352 L 56 456 L 160 456 L 160 404 L 108 404 L 108 352 Z" fill="url(#steelTrim)" stroke="#0F172A" stroke-width="14"/>
    <circle cx="88" cy="424" r="14" fill="#0F172A"/>
    <circle cx="86" cy="422" r="6" fill="#F8FAFC"/>

    <!-- Bottom-Right -->
    <path d="M 456 352 L 456 456 L 352 456 L 352 404 L 404 404 L 404 352 Z" fill="url(#steelTrim)" stroke="#0F172A" stroke-width="14"/>
    <circle cx="424" cy="424" r="14" fill="#0F172A"/>
    <circle cx="422" cy="422" r="6" fill="#F8FAFC"/>
  </g>
</svg>"""

    if shutil.which("rsvg-convert"):
        p = subprocess.run(["rsvg-convert", "-w", "64", "-h", "64", "-f", "png", "-o", os.path.join(OUT_DIR, "icon_locker.png")], input=svg_depot.encode("utf-8"), check=True)
        print("Generated assets/icons/icon_locker.png via rsvg-convert (Supply Depot Crate)")
    else:
        im = new_canvas()
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([48, 80, 208, 220], radius=16, fill=(13, 148, 136, 255), outline=(15, 23, 42, 255), width=6)
        save_icon(im, "icon_locker.png")

# ==========================================
# 19. icon_lock.png (Industrial Padlock)
# ==========================================
def make_lock():
    import subprocess
    import shutil

    svg_lock = """<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-15%" y="-15%" width="140%" height="140%">
      <feDropShadow dx="0" dy="18" stdDeviation="14" flood-color="#000000" flood-opacity="0.65"/>
    </filter>
    <linearGradient id="shackleGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="30%" stop-color="#E2E8F0"/>
      <stop offset="70%" stop-color="#94A3B8"/>
      <stop offset="100%" stop-color="#475569"/>
    </linearGradient>
    <linearGradient id="bodyGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FEF08A"/>
      <stop offset="25%" stop-color="#FBBF24"/>
      <stop offset="70%" stop-color="#D97706"/>
      <stop offset="100%" stop-color="#92400E"/>
    </linearGradient>
    <linearGradient id="bevelHighlight" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.8"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0.1"/>
    </linearGradient>
  </defs>
  <g filter="url(#shadow)">
    <!-- U-shaped Shackle -->
    <path d="M 148 240 L 148 160 C 148 100, 196 52, 256 52 C 316 52, 364 100, 364 160 L 364 240" 
          fill="none" stroke="#0F172A" stroke-width="68" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 148 240 L 148 160 C 148 100, 196 52, 256 52 C 316 52, 364 100, 364 160 L 364 240" 
          fill="none" stroke="url(#shackleGrad)" stroke-width="46" stroke-linecap="round" stroke-linejoin="round"/>
    <!-- Shackle Specular Glint -->
    <path d="M 172 160 C 172 114, 210 76, 256 76" 
          fill="none" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round" opacity="0.9"/>

    <!-- Lock Brass Body -->
    <rect x="80" y="200" width="352" height="260" rx="52" fill="#0F172A"/>
    <rect x="92" y="212" width="328" height="236" rx="40" fill="url(#bodyGrad)" stroke="#78350F" stroke-width="12"/>
    
    <!-- Inner Beveled Face -->
    <rect x="116" y="236" width="280" height="188" rx="26" fill="url(#bevelHighlight)" opacity="0.25"/>
    
    <!-- Heavy Industrial Rivets in 4 corners -->
    <circle cx="126" cy="246" r="10" fill="#78350F"/>
    <circle cx="124" cy="244" r="4" fill="#FEF08A"/>
    <circle cx="386" cy="246" r="10" fill="#78350F"/>
    <circle cx="384" cy="244" r="4" fill="#FEF08A"/>
    <circle cx="126" cy="414" r="10" fill="#78350F"/>
    <circle cx="124" cy="412" r="4" fill="#FEF08A"/>
    <circle cx="386" cy="414" r="10" fill="#78350F"/>
    <circle cx="384" cy="412" r="4" fill="#FEF08A"/>

    <!-- Center Keyhole -->
    <circle cx="256" cy="305" r="34" fill="#0F172A"/>
    <circle cx="256" cy="305" r="26" fill="#1E293B"/>
    <polygon points="238,315 274,315 284,375 228,375" fill="#0F172A"/>
    <polygon points="242,318 270,318 278,368 234,368" fill="#1E293B"/>
  </g>
</svg>"""

    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", "-w", "64", "-h", "64", "-f", "png", "-o", os.path.join(OUT_DIR, "icon_lock.png")], input=svg_lock.encode("utf-8"), check=True)
        print("Generated assets/icons/icon_lock.png via rsvg-convert (Industrial Padlock)")
    else:
        im = new_canvas()
        d = ImageDraw.Draw(im)
        save_icon(im, "icon_lock.png")

# ==========================================
# 20. icon_play.png (Crisp Play Triangle)
# ==========================================
def make_play():
    im = new_canvas()
    d = ImageDraw.Draw(im)

    pts = [(82, 48), (202, 128), (82, 208)]
    # Drop shadow
    d.polygon([(x+4, y+6) for x, y in pts], fill=(0, 0, 0, 90))
    # Base fill
    d.polygon(pts, fill=(46, 204, 113, 255), outline=(22, 140, 70, 255), width=8)
    # Highlight facet
    top_facet = [(82, 48), (202, 128), (82, 128)]
    d.polygon(top_facet, fill=(120, 240, 165, 255))
    d.line([(82, 48), (202, 128)], fill=(220, 255, 235, 255), width=6)
    d.polygon(pts, outline=(18, 120, 60, 255), width=6)

    save_icon(im, "icon_play.png")

# ==========================================
# 21. icon_check.png (Crisp Green Checkmark)
# ==========================================
def make_check():
    im = new_canvas()
    d = ImageDraw.Draw(im)

    pts = [(50, 136), (106, 192), (206, 68)]
    # Shadow
    d.line([(x+4, y+6) for x, y in pts], fill=(0, 0, 0, 90), width=28, joint="round")
    # Border
    d.line(pts, fill=(18, 120, 60, 255), width=28, joint="round")
    # Body
    d.line(pts, fill=(46, 204, 113, 255), width=20, joint="round")
    # Highlight
    d.line([(54, 132), (106, 184), (202, 64)], fill=(150, 250, 185, 255), width=8, joint="round")

    save_icon(im, "icon_check.png")

def main():
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
    make_hint()
    make_star(True)
    make_star(False)
    make_trophy()
    make_settings()
    make_locker()
    make_lock()
    make_play()
    make_check()
    print("All 21 game icons successfully generated!")

if __name__ == "__main__":
    main()

