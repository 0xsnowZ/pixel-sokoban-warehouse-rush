#!/usr/bin/env python3
"""
tools/process_premium_icon.py

Processes the iconic Golden Sokoban Delivery Crate artwork into exact production icon assets
with official Android Adaptive Icon 264px safe-zone calibration:
1. assets/store_icon_512.png (512x512 32-bit PNG, Google Play Store)
2. icon.png (512x512 32-bit PNG, Godot Project Icon)
3. assets/icon_192.png (192x192 32-bit PNG, Legacy Launcher Icon)
4. assets/adaptive_background_432.png (432x432 32-bit PNG, Android Adaptive Background)
5. assets/adaptive_foreground_432.png (432x432 32-bit PNG, Android Adaptive Foreground with 264px safe-zone scaling)
"""

import os
from PIL import Image, ImageFilter, ImageDraw

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(ROOT_DIR, "assets")
RAW_SRC = os.path.join(ASSETS_DIR, "store_icon_raw_1024.jpg")


def make_gradient(width, height):
    bg = Image.new("RGBA", (width, height))
    bg_draw = ImageDraw.Draw(bg)
    for y in range(height):
        t = y / float(height - 1)
        r = int(11 * (1.0 - t))
        g = int(14 * (1.0 - t) + 13 * t)
        b = int(59 * (1.0 - t) + 45 * t)
        bg_draw.line([(0, y), (width, y)], fill=(r, g, b, 255))
    return bg


def embed_crate(raw_img, target_canvas_size, crate_size, feather_px=20):
    bg = make_gradient(target_canvas_size, target_canvas_size)
    scaled_crate = raw_img.resize((crate_size, crate_size), Image.Resampling.LANCZOS)
    
    # Feather mask for seamless gradient blending
    mask = Image.new("L", (crate_size, crate_size), 255)
    mask_draw = ImageDraw.Draw(mask)
    for i in range(feather_px):
        alpha = int(255 * (i / float(feather_px)))
        mask_draw.rectangle([i, i, crate_size - 1 - i, crate_size - 1 - i], outline=alpha)
    
    offset = (target_canvas_size - crate_size) // 2
    bg.paste(scaled_crate, (offset, offset), mask)
    return bg


def process_premium_store_icons():
    print(f"Loading raw crate artwork from {RAW_SRC}...")
    raw_img = Image.open(RAW_SRC).convert("RGBA")

    # 1. assets/store_icon_master_1024.jpg (1024x1024 padded master)
    master_1024 = embed_crate(raw_img, 1024, int(1024 * 0.70), feather_px=30)
    out_master = os.path.join(ASSETS_DIR, "store_icon_master_1024.jpg")
    master_1024.convert("RGB").save(out_master, quality=95)
    print(f"Saved {out_master}")

    # 2. assets/store_icon_512.png and icon.png (512x512, 32-bit PNG, Google Play squircle safe)
    icon_512 = embed_crate(raw_img, 512, int(512 * 0.72), feather_px=15)
    icon_512 = icon_512.filter(ImageFilter.UnsharpMask(radius=1.2, percent=115, threshold=2))
    out_store = os.path.join(ASSETS_DIR, "store_icon_512.png")
    out_root = os.path.join(ROOT_DIR, "icon.png")
    icon_512.save(out_store, "PNG", optimize=True)
    icon_512.save(out_root, "PNG", optimize=True)
    print(f"Saved {out_store} and {out_root}")

    # 3. assets/icon_192.png (192x192, 32-bit PNG)
    icon_192 = icon_512.resize((192, 192), Image.Resampling.LANCZOS)
    icon_192 = icon_192.filter(ImageFilter.UnsharpMask(radius=1.0, percent=120, threshold=2))
    out_192 = os.path.join(ASSETS_DIR, "icon_192.png")
    icon_192.save(out_192, "PNG", optimize=True)
    print(f"Saved {out_192}")

    # 4. assets/adaptive_foreground_432.png (432x432, 32-bit PNG, calibrated to 258px safe diameter)
    ad_fg = embed_crate(raw_img, 432, 258, feather_px=12)
    ad_fg = ad_fg.filter(ImageFilter.UnsharpMask(radius=1.1, percent=115, threshold=2))
    out_ad_fg = os.path.join(ASSETS_DIR, "adaptive_foreground_432.png")
    ad_fg.save(out_ad_fg, "PNG", optimize=True)
    print(f"Saved {out_ad_fg}")

    # 5. assets/adaptive_background_432.png (432x432, 32-bit PNG)
    ad_bg = make_gradient(432, 432)
    out_ad_bg = os.path.join(ASSETS_DIR, "adaptive_background_432.png")
    ad_bg.save(out_ad_bg, "PNG", optimize=True)
    print(f"Saved {out_ad_bg}")


if __name__ == "__main__":
    process_premium_store_icons()
    print("All production icons updated with safe-zone calibrated Golden Sokoban Delivery Crate artwork!")
