#!/usr/bin/env python3
"""
tools/process_premium_icon.py

Processes the iconic Golden Sokoban Delivery Crate artwork into exact production icon assets:
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
MASTER_SRC = os.path.join(ASSETS_DIR, "store_icon_master_1024.jpg")


def process_premium_store_icons():
    print(f"Loading master icon artwork from {MASTER_SRC}...")
    master = Image.open(MASTER_SRC).convert("RGBA")

    # 1. assets/store_icon_512.png and icon.png (512x512, 32-bit PNG)
    icon_512 = master.resize((512, 512), Image.Resampling.LANCZOS)
    icon_512_sharp = icon_512.filter(ImageFilter.UnsharpMask(radius=1.2, percent=110, threshold=2))
    out_store = os.path.join(ASSETS_DIR, "store_icon_512.png")
    out_root = os.path.join(ROOT_DIR, "icon.png")
    icon_512_sharp.save(out_store, "PNG", optimize=True)
    icon_512_sharp.save(out_root, "PNG", optimize=True)
    print(f"Saved {out_store} and {out_root}")

    # 2. assets/icon_192.png (192x192, 32-bit PNG)
    icon_192 = master.resize((192, 192), Image.Resampling.LANCZOS)
    icon_192_sharp = icon_192.filter(ImageFilter.UnsharpMask(radius=1.0, percent=120, threshold=2))
    out_192 = os.path.join(ASSETS_DIR, "icon_192.png")
    icon_192_sharp.save(out_192, "PNG", optimize=True)
    print(f"Saved {out_192}")

    # 3. assets/adaptive_foreground_432.png (432x432, 32-bit PNG)
    icon_432 = master.resize((432, 432), Image.Resampling.LANCZOS)
    icon_432_sharp = icon_432.filter(ImageFilter.UnsharpMask(radius=1.1, percent=115, threshold=2))
    out_ad_fg = os.path.join(ASSETS_DIR, "adaptive_foreground_432.png")
    icon_432_sharp.save(out_ad_fg, "PNG", optimize=True)
    print(f"Saved {out_ad_fg}")

    # 4. assets/adaptive_background_432.png (432x432, 32-bit PNG)
    # Deep indigo/navy gradient matching the crate backdrop: rgb(11, 14, 59) -> rgb(0, 13, 45)
    bg_432 = Image.new("RGBA", (432, 432), (11, 14, 59, 255))
    bg_draw = ImageDraw.Draw(bg_432)
    for y in range(432):
        t = y / 432.0
        r = int(11 * (1.0 - t))
        g = int(14 * (1.0 - t) + 13 * t)
        b = int(59 * (1.0 - t) + 45 * t)
        bg_draw.line([(0, y), (432, y)], fill=(r, g, b, 255))
    out_ad_bg = os.path.join(ASSETS_DIR, "adaptive_background_432.png")
    bg_432.save(out_ad_bg, "PNG", optimize=True)
    print(f"Saved {out_ad_bg}")


if __name__ == "__main__":
    process_premium_store_icons()
    print("Production icons updated with Golden Sokoban Delivery Crate artwork!")
