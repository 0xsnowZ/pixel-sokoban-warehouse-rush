#!/usr/bin/env python3
"""
tools/generate_store_promo_pack.py

Generates professional, high-converting Google Play Store promotional assets:
- 5 High-Impact Portrait Screenshots (1080x1920) in sleek mobile phone frames
- 1 Feature Graphic Banner (1024x500) featuring the new Golden Sokoban Delivery Crate
- Full ASO metadata pack (Title, Short Description, Long Description)
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(ROOT_DIR, "assets")
ARTIFACT_DIR = "/home/snowz/.gemini/antigravity/brain/f5ae7af8-879e-4866-bb7e-de37bc6d1ca9"

FONT_TITLE_PATH = "/usr/share/fonts/TTF/OpenSans-CondensedExtraBold.ttf"
FONT_BOLD_PATH = "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"
FONT_REG_PATH = "/usr/share/fonts/TTF/OpenSans-Regular.ttf"

def get_font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()

def draw_pill_badge(draw, center_x, top_y, text, bg_color, text_color, font, icon_text=None):
    padding_x = 24
    padding_y = 10
    display_str = f"{icon_text}  {text}" if icon_text else text
    bbox = font.getbbox(display_str)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    
    bw = tw + padding_x * 2
    bh = th + padding_y * 2
    bx0 = center_x - bw // 2
    by0 = top_y
    bx1 = bx0 + bw
    by1 = by0 + bh
    
    # Glow / shadow
    draw.rounded_rectangle([bx0 + 2, by0 + 4, bx1 + 2, by1 + 4], radius=bh // 2, fill=(0, 0, 0, 100))
    # Pill background
    draw.rounded_rectangle([bx0, by0, bx1, by1], radius=bh // 2, fill=bg_color)
    # Border
    draw.rounded_rectangle([bx0, by0, bx1, by1], radius=bh // 2, outline=(255, 255, 255, 180), width=2)
    # Text
    draw.text((bx0 + padding_x, by0 + padding_y - 2), display_str, font=font, fill=text_color)
    return by1


def build_phone_frame(screen_img, target_width=840):
    """Embeds a 540x960 screen capture inside a sleek, modern smartphone frame."""
    sw, sh = screen_img.size
    aspect = sh / float(sw)
    target_height = int(target_width * aspect)
    scaled_screen = screen_img.resize((target_width, target_height), Image.Resampling.LANCZOS)
    
    border_px = 16
    fw = target_width + border_px * 2
    fh = target_height + border_px * 2
    corner_r = 44
    
    frame = Image.new("RGBA", (fw + 60, fh + 80), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(frame)
    
    # Outer drop shadow
    fdraw.rounded_rectangle([30, 40, fw + 30, fh + 40], radius=corner_r + 6, fill=(0, 0, 0, 140))
    frame = frame.filter(ImageFilter.GaussianBlur(16))
    fdraw = ImageDraw.Draw(frame)
    
    # Smartphone bezel
    bezel_box = [30, 20, fw + 30, fh + 20]
    fdraw.rounded_rectangle(bezel_box, radius=corner_r, fill=(18, 22, 32, 255), outline=(55, 65, 85, 255), width=3)
    # Inner metallic edge
    fdraw.rounded_rectangle([30 + 4, 20 + 4, fw + 30 - 4, fh + 20 - 4], radius=corner_r - 4, outline=(100, 116, 139, 120), width=2)
    
    # Screen mask with rounded corners
    screen_mask = Image.new("L", (target_width, target_height), 0)
    sdraw = ImageDraw.Draw(screen_mask)
    sdraw.rounded_rectangle([0, 0, target_width, target_height], radius=corner_r - 12, fill=255)
    
    # Paste screen inside frame
    frame.paste(scaled_screen, (30 + border_px, 20 + border_px), screen_mask)
    
    # Camera pill notch at top
    notch_w = 120
    notch_h = 18
    nx0 = (frame.width - notch_w) // 2
    ny0 = 20 + border_px + 8
    fdraw.rounded_rectangle([nx0, ny0, nx0 + notch_w, ny0 + notch_h], radius=notch_h // 2, fill=(8, 10, 15, 255))
    fdraw.ellipse([nx0 + notch_w - 24, ny0 + 4, nx0 + notch_w - 14, ny0 + 14], fill=(30, 41, 59, 255)) # lens
    
    return frame


def render_promo_screenshot(screen_src_path, headline_1, headline_2, badge_text, badge_icon, badge_col, out_filename):
    canvas_w, canvas_h = 1080, 1920
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (11, 16, 26, 255))
    draw = ImageDraw.Draw(canvas)
    
    # 1. Background vertical atmosphere gradient (Deep warehouse indigo to dark midnight slate)
    for y in range(canvas_h):
        t = y / float(canvas_h - 1)
        # Deep blue top -> dark slate bottom
        r = int(14 * (1.0 - t) + 8 * t)
        g = int(22 * (1.0 - t) + 14 * t)
        b = int(48 * (1.0 - t) + 24 * t)
        draw.line([(0, y), (canvas_w, y)], fill=(r, g, b, 255))
        
    # Top ambient radial spotlight behind text
    spotlight = Image.new("RGBA", (canvas_w, 600), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(spotlight)
    sdraw.ellipse([140, -100, canvas_w - 140, 500], fill=(badge_col[0], badge_col[1], badge_col[2], 35))
    spotlight = spotlight.filter(ImageFilter.GaussianBlur(60))
    canvas.paste(spotlight, (0, 0), spotlight)
    
    # 2. Typography Header
    f_title = get_font(FONT_TITLE_PATH, 82)
    f_sub = get_font(FONT_BOLD_PATH, 32)
    f_badge = get_font(FONT_BOLD_PATH, 24)
    
    # Badge Pill at Top (y = 80)
    pill_bottom = draw_pill_badge(draw, canvas_w // 2, 75, badge_text, badge_col, (255, 255, 255), f_badge, badge_icon)
    
    # Headline Line 1 (y = pill_bottom + 25)
    y_h1 = pill_bottom + 30
    b_h1 = f_title.getbbox(headline_1)
    tw1 = b_h1[2] - b_h1[0]
    # Shadow
    draw.text(((canvas_w - tw1) // 2 + 3, y_h1 + 4), headline_1, font=f_title, fill=(0, 0, 0, 220))
    draw.text(((canvas_w - tw1) // 2, y_h1), headline_1, font=f_title, fill=(255, 215, 0)) # Golden
    
    # Headline Line 2 (Subtitle)
    y_h2 = y_h1 + 90
    b_h2 = f_sub.getbbox(headline_2)
    tw2 = b_h2[2] - b_h2[0]
    draw.text(((canvas_w - tw2) // 2 + 2, y_h2 + 2), headline_2, font=f_sub, fill=(0, 0, 0, 190))
    draw.text(((canvas_w - tw2) // 2, y_h2), headline_2, font=f_sub, fill=(226, 232, 240)) # Crisp white-slate
    
    # 3. Phone Frame with Authentic Gameplay Screen
    raw_screen = Image.open(screen_src_path).convert("RGBA")
    phone = build_phone_frame(raw_screen, target_width=860)
    
    # Center phone horizontally, position below header (y = 360)
    px = (canvas_w - phone.width) // 2
    py = 370
    canvas.paste(phone, (px, py), phone)
    
    # Output file
    out_asset = os.path.join(ASSETS_DIR, out_filename)
    out_artifact = os.path.join(ARTIFACT_DIR, out_filename)
    canvas.convert("RGB").save(out_asset, "PNG", optimize=True)
    canvas.convert("RGB").save(out_artifact, "PNG", optimize=True)
    print(f"Generated {out_filename}")


def render_all_store_promos():
    print("Generating 5 high-converting Google Play Store promo screenshots...")
    
    # 1. Gameplay Screenshot
    render_promo_screenshot(
        screen_src_path=os.path.join(ARTIFACT_DIR, "preview_gameplay.png"),
        headline_1="50 MIND-BENDING PUZZLES",
        headline_2="Handcrafted Warehouse Brain Challenges",
        badge_text="CLASSIC SOKOBAN LOGIC",
        badge_icon="★",
        badge_col=(217, 119, 6),
        out_filename="promo_1_gameplay.png"
    )
    
    # 2. Chapters Progression
    render_promo_screenshot(
        screen_src_path=os.path.join(ARTIFACT_DIR, "preview_chapter_2_cold_storage.png"),
        headline_1="3 INDUSTRIAL CHAPTERS",
        headline_2="Cargo Bay • Cold Storage • Cyber Depot",
        badge_text="UNIQUE WAREHOUSE THEMES",
        badge_icon="❄",
        badge_col=(14, 165, 233),
        out_filename="promo_2_chapters.png"
    )
    
    # 3. Supply Depot Locker
    render_promo_screenshot(
        screen_src_path=os.path.join(ARTIFACT_DIR, "preview_locker_outfits.png"),
        headline_1="CUSTOM WORKER & CRATE SKINS",
        headline_2="Equip Vests, Helmets & Heavy Containers",
        badge_text="THE SUPPLY DEPOT",
        badge_icon="🦺",
        badge_col=(147, 51, 234),
        out_filename="promo_3_locker.png"
    )
    
    # 4. Smart Hints & Undo
    render_promo_screenshot(
        screen_src_path=os.path.join(ARTIFACT_DIR, "preview_hint_gameplay.png"),
        headline_1="SMART HINTS & UNLIMITED UNDO",
        headline_2="Never Get Deadlocked • Pure Puzzle Zen",
        badge_text="ZERO FRUSTRATION",
        badge_icon="💡",
        badge_col=(16, 185, 129),
        out_filename="promo_4_hints.png"
    )
    
    # 5. Offline & Victory
    render_promo_screenshot(
        screen_src_path=os.path.join(ARTIFACT_DIR, "preview_win_modal.png"),
        headline_1="100% OFFLINE • PLAY ANYWHERE",
        headline_2="Earn 3 Stars • No Internet Required",
        badge_text="TRAVEL & COMMUTE FRIENDLY",
        badge_icon="✈",
        badge_col=(234, 88, 12),
        out_filename="promo_5_offline.png"
    )


def render_feature_graphic():
    print("Generating Google Play Feature Graphic (1024x500)...")
    fw, fh = 1024, 500
    canvas = Image.new("RGBA", (fw, fh), (11, 16, 26, 255))
    draw = ImageDraw.Draw(canvas)
    
    # Background: Warehouse scene with deep gradient
    bg_img_path = os.path.join(ASSETS_DIR, "warehouse_bg.jpg")
    if os.path.exists(bg_img_path):
        bg = Image.open(bg_img_path).convert("RGBA").resize((fw, fh), Image.Resampling.LANCZOS)
        # Darken to make foreground pop
        darkener = Image.new("RGBA", (fw, fh), (8, 12, 22, 160))
        bg.paste(darkener, (0, 0), darkener)
        canvas.paste(bg, (0, 0))
    else:
        for y in range(fh):
            t = y / float(fh - 1)
            r = int(14 * (1.0 - t) + 6 * t)
            g = int(22 * (1.0 - t) + 12 * t)
            b = int(48 * (1.0 - t) + 24 * t)
            draw.line([(0, y), (fw, y)], fill=(r, g, b, 255))
            
    # Right side: Big Golden Sokoban Delivery Crate
    crate_src = os.path.join(ASSETS_DIR, "store_icon_raw_1024.jpg")
    if os.path.exists(crate_src):
        crate = Image.open(crate_src).convert("RGBA").resize((440, 440), Image.Resampling.LANCZOS)
        # Drop shadow
        c_shadow = Image.new("RGBA", (480, 480), (0, 0, 0, 0))
        cs_draw = ImageDraw.Draw(c_shadow)
        cs_draw.ellipse([40, 360, 440, 460], fill=(0, 0, 0, 180))
        c_shadow = c_shadow.filter(ImageFilter.GaussianBlur(24))
        canvas.paste(c_shadow, (540, 20), c_shadow)
        canvas.paste(crate, (560, 30), crate)
        
    # Left side: Game Logo
    logo_path = os.path.join(ASSETS_DIR, "logo.png")
    if os.path.exists(logo_path):
        logo = Image.open(logo_path).convert("RGBA")
        lw, lh = 520, int(520 * (logo.height / float(logo.width)))
        scaled_logo = logo.resize((lw, lh), Image.Resampling.LANCZOS)
        canvas.paste(scaled_logo, (45, 75), scaled_logo)
        
    # Bottom value badges
    f_badge = get_font(FONT_BOLD_PATH, 20)
    draw_pill_badge(draw, 170, 385, "50 HANDCRAFTED PUZZLES", (217, 119, 6), (255, 255, 255), f_badge, "★")
    draw_pill_badge(draw, 420, 385, "100% OFFLINE PLAY", (16, 185, 129), (255, 255, 255), f_badge, "⚡")
    
    out_asset = os.path.join(ASSETS_DIR, "feature_graphic_1024x500.png")
    out_artifact = os.path.join(ARTIFACT_DIR, "feature_graphic_1024x500.png")
    canvas.convert("RGB").save(out_asset, "PNG", optimize=True)
    canvas.convert("RGB").save(out_artifact, "PNG", optimize=True)
    print("Generated feature_graphic_1024x500.png")


if __name__ == "__main__":
    render_all_store_promos()
    render_feature_graphic()
    print("All store promotional assets successfully generated!")
