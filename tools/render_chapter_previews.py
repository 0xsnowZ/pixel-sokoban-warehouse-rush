#!/usr/bin/env python3
"""
Pixel Porter - Chapter Themes & Progression Visualizer (Phase 2)
Generates high-fidelity visual render previews for:
- Chapter 1: Cargo Bay (Levels 1-15, warm tungsten industrial, polished brass bevels)
- Chapter 2: Cold Storage (Levels 16-35, cryogenic sub-zero frost sheen, cyan bevels)
- Chapter 3: Cyber Depot (Levels 36-50, high-tech obsidian carbon, hazard amber bevels, laser emerald aura)
- Level Select Progression with Chapter themes and star milestones
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont

ARTIFACT_DIR = "/home/snowz/.gemini/antigravity/brain/f5ae7af8-879e-4866-bb7e-de37bc6d1ca9"
ASSETS_DIR = "/home/snowz/godot/assets"
W, H = 540, 960

def get_font(size):
    try:
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)
    except:
        return ImageFont.load_default()

def get_regular_font(size):
    try:
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size)
    except:
        return ImageFont.load_default()

def draw_styled_button(draw, rect, text, is_primary=False, is_success=False, font=None, custom_border=None):
    x0, y0, x1, y1 = rect
    r = 10
    if is_primary:
        bg = (218, 138, 30)
        border_top = custom_border if custom_border else (255, 220, 115)
        border_bot = (110, 55, 10)
        text_col = (255, 255, 255)
    elif is_success:
        bg = (46, 148, 82)
        border_top = (115, 230, 148)
        border_bot = (20, 82, 35)
        text_col = (255, 255, 255)
    else:
        bg = (33, 43, 61)
        border_top = custom_border if custom_border else (184, 138, 51)
        border_bot = (75, 55, 18)
        text_col = (240, 244, 250)

    draw.rounded_rectangle([x0 + 1, y0 + 3, x1 + 1, y1 + 3], radius=r, fill=(0, 0, 0, 90))
    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=bg)
    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, outline=border_top, width=2)
    draw.line([(x0 + r, y1), (x1 - r, y1)], fill=border_bot, width=4)

    if font:
        bbox = font.getbbox(text)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = (x0 + x1 - tw) // 2
        ty = (y0 + y1 - th) // 2 - 2
        draw.text((tx, ty + 1), text, font=font, fill=(0, 0, 0, 220))
        draw.text((tx, ty), text, font=font, fill=text_col)

def tint_image(img, tint_rgb):
    r_factor = tint_rgb[0] / 255.0
    g_factor = tint_rgb[1] / 255.0
    b_factor = tint_rgb[2] / 255.0
    
    # Fast PIL point transformation
    img = img.copy()
    bands = list(img.split())
    if len(bands) == 4:
        r, g, b, a = bands
        r = r.point(lambda p: int(p * r_factor))
        g = g.point(lambda p: int(p * g_factor))
        b = b.point(lambda p: int(p * b_factor))
        return Image.merge("RGBA", (r, g, b, a))
    return img

def render_chapter_screen(ch_id, level_num, out_filename):
    bg_path = os.path.join(ASSETS_DIR, "warehouse_bg.jpg")
    bg = Image.open(bg_path).convert("RGBA").resize((W, H))

    # Chapter palette definitions
    if ch_id == 0:
        # Chapter 1: Cargo Bay
        ch_title = "Cargo Bay"
        badge_text = "📦 CH. 1"
        badge_col = (250, 209, 64)
        dim_rgba = (15, 20, 31, 180)
        frame_base = (30, 38, 51)
        frame_rim = (198, 153, 56) # Polished brass
        bolt_col = (235, 188, 71)
        floor_tint = (255, 255, 255)
        wall_tint = (255, 255, 255)
        goal_aura_col = (250, 209, 51, 80)
        goal_core_col = (255, 255, 220)
        crate_tint = (255, 255, 255)
    elif ch_id == 1:
        # Chapter 2: Cold Storage
        ch_title = "Cold Storage"
        badge_text = "❄ CH. 2"
        badge_col = (89, 217, 255)
        dim_rgba = (8, 22, 42, 195)
        frame_base = (20, 36, 56)
        frame_rim = (89, 209, 255) # Cryo cyan
        bolt_col = (140, 230, 255)
        floor_tint = (209, 235, 255) # Frost sheen
        wall_tint = (204, 230, 255) # Insulated walls
        goal_aura_col = (64, 217, 255, 95) # Cyan pressure plate
        goal_core_col = (220, 250, 255)
        crate_tint = (235, 245, 255)
    else:
        # Chapter 3: Cyber Depot
        ch_title = "Cyber Depot"
        badge_text = "⚡ CH. 3"
        badge_col = (255, 166, 51)
        dim_rgba = (16, 14, 24, 200)
        frame_base = (16, 18, 26) # Obsidian carbon
        frame_rim = (255, 166, 46) # Hazard amber
        bolt_col = (255, 184, 61)
        floor_tint = (224, 224, 240) # High-tech composite
        wall_tint = (199, 194, 219)
        goal_aura_col = (51, 255, 140, 95) # Laser emerald
        goal_core_col = (190, 255, 220)
        crate_tint = (255, 240, 230)

    # Apply background ambient tint
    overlay = Image.new("RGBA", (W, H), dim_rgba)
    game_img = Image.alpha_composite(bg, overlay)
    draw = ImageDraw.Draw(game_img)

    f_top = get_font(18)
    f_badge = get_font(14)
    f_stats = get_regular_font(14)
    f_btn = get_font(15)

    # Top Bar
    draw.rectangle([0, 0, W, 68], fill=(20, 26, 38, 248))
    draw.line([(0, 68), (W, 68)], fill=frame_rim, width=2)
    # Menu btn
    draw_styled_button(draw, (14, 12, 56, 54), "⌂", font=f_top, custom_border=frame_rim)
    # Music & Control buttons
    draw_styled_button(draw, (62, 12, 104, 54), "♪", font=f_top, custom_border=frame_rim)
    draw_styled_button(draw, (110, 12, 152, 54), "✋", font=f_top, custom_border=frame_rim)

    # Chapter Badge
    draw.rounded_rectangle([160, 17, 240, 49], radius=6, fill=(24, 32, 48), outline=badge_col, width=1)
    bb = f_badge.getbbox(badge_text)
    bw = bb[2] - bb[0]
    draw.text((160 + (80 - bw)//2, 23), badge_text, font=f_badge, fill=badge_col)

    # Level label
    lvl_str = "LVL %d/50" % level_num
    draw.text((250, 24), lvl_str, font=f_top, fill=(255, 255, 255))
    # Stats
    draw.text((W - 165, 26), "M: 0 | P: 0", font=f_stats, fill=(225, 235, 250))

    # Bottom Bar
    draw.rectangle([0, H - 76, W, H], fill=(20, 26, 38, 248))
    draw.line([(0, H - 76), (W, H - 76)], fill=frame_rim, width=2)
    draw_styled_button(draw, (14, H - 64, 94, H - 16), "< Prev", font=f_btn, custom_border=frame_rim)
    draw_styled_button(draw, (102, H - 64, 202, H - 16), "Undo ↶", font=f_btn, custom_border=frame_rim)
    draw_styled_button(draw, (210, H - 64, 310, H - 16), "Hint 💡", font=f_btn, custom_border=frame_rim)
    draw_styled_button(draw, (318, H - 64, 430, H - 16), "Restart ↺", is_primary=True, font=f_btn, custom_border=frame_rim)
    draw_styled_button(draw, (438, H - 64, 526, H - 16), "Next >", is_success=True, font=f_btn)

    # Board layout (5x5 grid)
    tile_sz = 84
    grid_w, grid_h = 5, 5
    board_px_w, board_px_h = grid_w * tile_sz, grid_h * tile_sz
    gx0 = (W - board_px_w) // 2
    gy0 = (H - board_px_h) // 2

    frame_m = 12
    fx0, fy0 = gx0 - frame_m, gy0 - frame_m
    fx1, fy1 = gx0 + board_px_w + frame_m, gy0 + board_px_h + frame_m

    # Frame shadow
    draw.rectangle([fx0 + 8, fy0 + 10, fx1 + 8, fy1 + 10], fill=(0, 0, 0, 160))
    # Frame base & bevel rim
    draw.rectangle([fx0, fy0, fx1, fy1], fill=frame_base, outline=frame_rim, width=3)
    # Inner groove
    draw.rectangle([gx0 - 2, gy0 - 2, gx0 + board_px_w + 2, gy0 + board_px_h + 2], outline=(15, 18, 24), width=2)

    # 4 Corner Bolts
    for bx, by in [(fx0 + 6, fy0 + 6), (fx1 - 6, fy0 + 6), (fx0 + 6, fy1 - 6), (fx1 - 6, fy1 - 6)]:
        draw.ellipse([bx - 4, by - 4, bx + 4, by + 4], fill=bolt_col, outline=(30, 20, 10))

    # Tile textures
    if ch_id == 1:
        wall_file = "wall_cold_storage.png"
        tex_wall_raw = Image.open(os.path.join(ASSETS_DIR, wall_file)).convert("RGBA").resize((tile_sz, tile_sz))
        tex_wall = tex_wall_raw
    elif ch_id == 2:
        wall_file = "wall_cyber_depot.png"
        tex_wall_raw = Image.open(os.path.join(ASSETS_DIR, wall_file)).convert("RGBA").resize((tile_sz, tile_sz))
        tex_wall = tex_wall_raw
    else:
        wall_file = "wall_brick.png"
        tex_wall_raw = Image.open(os.path.join(ASSETS_DIR, wall_file)).convert("RGBA").resize((tile_sz, tile_sz))
        tex_wall = tint_image(tex_wall_raw, wall_tint)
    tex_f1_raw = Image.open(os.path.join(ASSETS_DIR, "floor_tile_1.png")).convert("RGBA").resize((tile_sz, tile_sz))
    tex_f2_raw = Image.open(os.path.join(ASSETS_DIR, "floor_tile_2.png")).convert("RGBA").resize((tile_sz, tile_sz))
    tex_goal_raw = Image.open(os.path.join(ASSETS_DIR, "goal_pad.png")).convert("RGBA").resize((tile_sz, tile_sz))
    tex_crate_raw = Image.open(os.path.join(ASSETS_DIR, "crate_normal.png")).convert("RGBA").resize((tile_sz, tile_sz))
    tex_player = Image.open(os.path.join(ASSETS_DIR, "player_down.png")).convert("RGBA").resize((tile_sz, tile_sz))

    tex_f1 = tint_image(tex_f1_raw, floor_tint)
    tex_f2 = tint_image(tex_f2_raw, floor_tint)
    tex_crate = tint_image(tex_crate_raw, crate_tint)
    tex_goal = tex_goal_raw

    level_map = [
        "#####",
        "#   #",
        "# $ #",
        "#.@ #",
        "#####"
    ]

    for y in range(grid_h):
        for x in range(grid_w):
            ch = level_map[y][x]
            tx = gx0 + x * tile_sz
            ty = gy0 + y * tile_sz
            if ch == '#':
                game_img.paste(tex_wall, (tx, ty), tex_wall)
            else:
                f_tex = tex_f1 if (x + y) % 2 == 0 else tex_f2
                game_img.paste(f_tex, (tx, ty), f_tex)
                if y > 0 and level_map[y - 1][x] == '#':
                    s_overlay = Image.new("RGBA", (tile_sz, int(tile_sz * 0.22)), (0, 0, 0, 110))
                    game_img.paste(s_overlay, (tx, ty), s_overlay)

                if ch == '.':
                    game_img.paste(tex_goal, (tx, ty), tex_goal)
                    # Pulsing Chapter Aura
                    aura_layer = Image.new("RGBA", (tile_sz, tile_sz), (0, 0, 0, 0))
                    a_draw = ImageDraw.Draw(aura_layer)
                    cx, cy = tile_sz // 2, tile_sz // 2
                    rad = int(tile_sz * 0.28)
                    a_draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=goal_aura_col)
                    a_draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=goal_core_col)
                    game_img.alpha_composite(aura_layer, (tx, ty))

                elif ch == '$':
                    # Crate shadow
                    c_shadow = Image.new("RGBA", (tile_sz, tile_sz), (0, 0, 0, 0))
                    cs_draw = ImageDraw.Draw(c_shadow)
                    cs_draw.rectangle([4, 6, tile_sz - 4, tile_sz - 2], fill=(0, 0, 0, 95))
                    game_img.alpha_composite(c_shadow, (tx, ty))
                    game_img.paste(tex_crate, (tx, ty), tex_crate)

                elif ch == '@':
                    s_layer = Image.new("RGBA", (tile_sz, tile_sz), (0, 0, 0, 0))
                    s_draw = ImageDraw.Draw(s_layer)
                    rad = tile_sz / 2.0
                    sc_x = rad
                    sc_y = tile_sz * 0.94
                    rx_o, ry_o = rad * 0.54, rad * 0.18
                    s_draw.ellipse([sc_x - rx_o, sc_y - ry_o, sc_x + rx_o, sc_y + ry_o], fill=(0, 0, 0, 56))
                    rx_i, ry_i = rad * 0.40, rad * 0.11
                    s_draw.ellipse([sc_x - rx_i, sc_y - ry_i, sc_x + rx_i, sc_y + ry_i], fill=(0, 0, 0, 82))
                    game_img.alpha_composite(s_layer, (tx, ty))
                    game_img.alpha_composite(tex_player, (tx, ty))

    # Chapter Toast Banner Announcement
    banner_w, banner_h = 360, 42
    bx0, by0 = (W - banner_w)//2, gy0 - 64
    bx1, by1 = bx0 + banner_w, by0 + banner_h
    draw.rounded_rectangle([bx0 + 2, by0 + 4, bx1 + 2, by1 + 4], radius=8, fill=(0, 0, 0, 140))
    draw.rounded_rectangle([bx0, by0, bx1, by1], radius=8, fill=(18, 24, 36, 240), outline=frame_rim, width=2)
    toast_str = "★ CHAPTER %d: %s ★" % (ch_id + 1, ch_title.upper())
    f_toast = get_font(13)
    tb = f_toast.getbbox(toast_str)
    tw = tb[2] - tb[0]
    draw.text((bx0 + (banner_w - tw)//2, by0 + 13), toast_str, font=f_toast, fill=badge_col)

    out_path = os.path.join(ARTIFACT_DIR, out_filename)
    game_img.save(out_path)
    print("Saved %s" % out_filename)


def render_progression_level_select():
    bg_path = os.path.join(ASSETS_DIR, "warehouse_bg.jpg")
    bg = Image.open(bg_path).convert("RGBA").resize((W, H))
    overlay = Image.new("RGBA", (W, H), (14, 18, 26, 215))
    img = Image.alpha_composite(bg, overlay)
    draw = ImageDraw.Draw(img)

    f_top = get_font(18)
    f_bar = get_font(12)
    f_ch_badge = get_font(12)
    f_lvl_num = get_font(17)
    f_lvl_sub = get_font(13)

    # Top Bar
    draw.rectangle([0, 0, W, 68], fill=(20, 26, 38, 250))
    draw.line([(0, 68), (W, 68)], fill=(184, 138, 51), width=2)
    draw_styled_button(draw, (16, 12, 64, 54), "⌂", font=f_top)
    draw.text((80, 24), "LEVEL SELECT", font=f_top, fill=(245, 209, 89))
    draw.text((W - 130, 25), "★ 42/150", font=f_top, fill=(255, 224, 102))

    # Campaign Banner Card
    draw.rounded_rectangle([20, 84, W - 20, 160], radius=12, fill=(24, 32, 46, 245), outline=(184, 138, 51), width=1)
    # 3 Chapter Segment Indicators inside banner
    ch_data = [
        ("📦 Ch. 1: Cargo Bay", (250, 209, 64), "15/15", (24, 94, 180, 106)),
        ("❄ Ch. 2: Cold Storage", (89, 217, 255), "12/20", (186, 94, 350, 106)),
        ("⚡ Ch. 3: Cyber Depot", (255, 166, 51), "0/15", (356, 94, W - 24, 106))
    ]
    for name, col, stars, (rx0, ry0, rx1, ry1) in ch_data:
        draw.rounded_rectangle([rx0, ry0, rx1, ry1], radius=6, fill=(18, 24, 36), outline=col, width=1)
        draw.text((rx0 + 8, ry0 + 4), name, font=f_bar, fill=col)

    # Overall Progress Bar
    draw.rounded_rectangle([32, 116, W - 32, 130], radius=6, fill=(15, 19, 28))
    # Fill 36%
    fill_w = int((W - 64) * 0.36)
    draw.rounded_rectangle([32, 116, 32 + fill_w, 130], radius=6, fill=(218, 138, 30))

    draw.text((32, 138), "★ 42 / 150 Stars Collected", font=f_bar, fill=(220, 230, 245))
    draw.text((W - 160, 138), "27/50 Cleared • 54%", font=f_bar, fill=(140, 160, 185))

    # Grid of Levels (Showing Chapters 1, 2, 3 color transitions)
    cols = 5
    rows = 7 # Display levels 1 to 35
    col_w, row_h = 92, 92
    pad_x, pad_y = 12, 12
    grid_x0 = (W - (cols * col_w + (cols - 1) * pad_x)) // 2
    grid_y0 = 176

    for r in range(rows):
        for c in range(cols):
            idx = r * cols + c + 1
            if idx > 35:
                continue

            bx0 = grid_x0 + c * (col_w + pad_x)
            by0 = grid_y0 + r * (row_h + pad_y)
            bx1 = bx0 + col_w
            by1 = by0 + row_h

            # Determine chapter
            if idx <= 15:
                ch_color = (250, 209, 64) # Cargo Bay Gold
            elif idx <= 35:
                ch_color = (89, 217, 255) # Cold Storage Cyan
            else:
                ch_color = (255, 166, 51) # Cyber Depot Amber

            if idx < 15:
                # Completed
                draw.rounded_rectangle([bx0 + 1, by0 + 3, bx1 + 1, by1 + 3], radius=10, fill=(0, 0, 0, 90))
                draw.rounded_rectangle([bx0, by0, bx1, by1], radius=10, fill=(30, 42, 60), outline=ch_color, width=2)
                draw.line([(bx0 + 6, by1), (bx1 - 6, by1)], fill=(75, 55, 18), width=4)

                num_str = str(idx)
                nb = f_lvl_num.getbbox(num_str)
                draw.text((bx0 + (col_w - (nb[2] - nb[0]))//2, by0 + 14), num_str, font=f_lvl_num, fill=(255, 245, 220))

                sub_str = "★★★"
                sb = f_lvl_sub.getbbox(sub_str)
                draw.text((bx0 + (col_w - (sb[2] - sb[0]))//2, by0 + 50), sub_str, font=f_lvl_sub, fill=ch_color)

            elif idx == 15 or idx == 16:
                # Active Chapter 2 unlocked level
                draw.rounded_rectangle([bx0 + 1, by0 + 4, bx1 + 1, by1 + 4], radius=10, fill=(0, 0, 0, 100))
                draw.rounded_rectangle([bx0, by0, bx1, by1], radius=10, fill=(35, 75, 110) if idx == 16 else (30, 42, 60), outline=ch_color, width=2)
                draw.line([(bx0 + 6, by1), (bx1 - 6, by1)], fill=(20, 60, 90), width=4)

                num_str = str(idx)
                nb = f_lvl_num.getbbox(num_str)
                draw.text((bx0 + (col_w - (nb[2] - nb[0]))//2, by0 + 14), num_str, font=f_lvl_num, fill=(255, 255, 255))

                play_str = "▶" if idx == 16 else "★★☆"
                pb = f_lvl_sub.getbbox(play_str)
                draw.text((bx0 + (col_w - (pb[2] - pb[0]))//2, by0 + 50), play_str, font=f_lvl_sub, fill=ch_color)

            else:
                # Locked levels with chapter tint
                draw.rounded_rectangle([bx0, by0, bx1, by1], radius=10, fill=(20, 26, 36, 240), outline=(42, 54, 72), width=1)
                num_str = str(idx)
                nb = f_lvl_num.getbbox(num_str)
                draw.text((bx0 + (col_w - (nb[2] - nb[0]))//2, by0 + 16), num_str, font=f_lvl_num, fill=(110, 125, 145))
                lock_str = "🔒"
                lb = f_lvl_sub.getbbox(lock_str)
                draw.text((bx0 + (col_w - (lb[2] - lb[0]))//2, by0 + 50), lock_str, font=f_lvl_sub, fill=(140, 155, 175))

    out_path = os.path.join(ARTIFACT_DIR, "preview_level_select_chapters.png")
    img.save(out_path)
    print("Saved preview_level_select_chapters.png")


if __name__ == "__main__":
    render_chapter_screen(0, 1, "preview_chapter_1_cargo_bay.png")
    render_chapter_screen(1, 16, "preview_chapter_2_cold_storage.png")
    render_chapter_screen(2, 36, "preview_chapter_3_cyber_depot.png")
    render_progression_level_select()
