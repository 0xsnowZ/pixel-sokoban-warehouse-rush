#!/usr/bin/env python3
"""
tools/render_level_screenshot.py
Renders high-fidelity in-game screenshots for any Sokoban level using authentic textures.
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 540, 960
ASSETS_DIR = "/home/snowz/godot/assets"
OUTPUT_DIR = "/home/snowz/.gemini/antigravity/brain/db19d3e6-5897-4bec-b12d-4a1222e63add"

def get_font(size, bold=True):
    try:
        if bold:
            return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)
        else:
            return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size)
    except:
        return ImageFont.load_default()

def render_level_image(lvl_num, out_filename):
    # Load level text
    path = f"/home/snowz/godot/levels/level_{lvl_num:02d}.sok"
    with open(path) as f:
        lines = [l.rstrip("\r\n") for l in f.readlines() if l.strip()]

    grid_h = len(lines)
    grid_w = max(len(l) for l in lines)
    grid = [l.ljust(grid_w) for l in lines]

    # Chapter logic
    if lvl_num <= 20:
        ch_idx = 1
        ch_name = "CH. 1"
        wall_tex_file = "wall_brick.png"
    elif lvl_num <= 40:
        ch_idx = 2
        ch_name = "CH. 2"
        wall_tex_file = "wall_cold_storage.png"
    elif lvl_num <= 60:
        ch_idx = 3
        ch_name = "CH. 3"
        wall_tex_file = "wall_cyber_depot.png"
    else:
        ch_idx = 4
        ch_name = "CH. 4"
        wall_tex_file = "wall_quantum_vault.png"

    # Base background
    bg = Image.open(os.path.join(ASSETS_DIR, "warehouse_bg.jpg")).convert("RGBA").resize((W, H))
    overlay = Image.new("RGBA", (W, H), (10, 16, 26, 175))
    screen = Image.alpha_composite(bg, overlay)
    draw = ImageDraw.Draw(screen)

    # Top HUD Bar
    draw.rectangle([0, 0, W, 72], fill=(18, 24, 36, 245))
    draw.line([(0, 72), (W, 72)], fill=(45, 60, 85), width=2)

    f_bold_18 = get_font(18, True)
    f_bold_14 = get_font(14, True)
    f_reg_13 = get_font(13, False)

    # Top bar badge & level title
    # Home, audio, gesture buttons
    for i, icon in enumerate(["⌂", "♪", "✋"]):
        bx = 14 + i * 46
        draw.rounded_rectangle([bx, 14, bx + 38, 56], radius=6, fill=(28, 38, 56), outline=(65, 85, 120), width=1)
        draw.text((bx + 11, 23), icon, font=f_bold_18, fill=(240, 245, 255))

    # Level indicator badge
    lvl_badge = f"{ch_name} • LEVEL {lvl_num} / 75 • ★★★"
    draw.rounded_rectangle([170, 16, W - 14, 54], radius=6, fill=(24, 32, 48), outline=(215, 175, 60), width=1)
    draw.text((185, 25), lvl_badge, font=f_bold_14, fill=(255, 215, 75))

    # Moves & Pushes stats bar
    draw.rectangle([0, 72, W, 102], fill=(12, 16, 24, 230))
    # Count pushes from solutions.json
    import json
    with open("/home/snowz/godot/levels/solutions.json") as f:
        sols = json.load(f)
    sol_str = sols[str(lvl_num)]
    opt_moves = len(sol_str)

    stats_text = f"MOVES: 0 (≤{opt_moves})  •  PUSHES: 0  •  BEST: --"
    draw.text((120, 78), stats_text, font=f_reg_13, fill=(200, 220, 245))

    # Bottom action bar
    draw.rectangle([0, H - 76, W, H], fill=(18, 24, 36, 245))
    draw.line([(0, H - 76), (W, H - 76)], fill=(45, 60, 85), width=2)
    # Buttons: Undo, Hint, Restart
    draw.rounded_rectangle([14, H - 62, 160, H - 18], radius=8, fill=(28, 38, 56), outline=(65, 85, 120), width=1)
    draw.text((55, H - 48), "Undo ↶", font=f_bold_14, fill=(180, 205, 235))

    draw.rounded_rectangle([175, H - 62, 365, H - 18], radius=8, fill=(215, 175, 45), outline=(255, 230, 100), width=1)
    draw.text((230, H - 48), "Hint 💡 (4)", font=f_bold_14, fill=(30, 24, 10))

    draw.rounded_rectangle([380, H - 62, W - 14, H - 18], radius=8, fill=(140, 45, 45), outline=(195, 75, 75), width=1)
    draw.text((410, H - 48), "Restart ↺", font=f_bold_14, fill=(255, 240, 240))

    # Textures loading
    tex_wall = Image.open(os.path.join(ASSETS_DIR, wall_tex_file)).convert("RGBA")
    tex_floor1 = Image.open(os.path.join(ASSETS_DIR, "floor_tile_1.png")).convert("RGBA")
    tex_floor2 = Image.open(os.path.join(ASSETS_DIR, "floor_tile_2.png")).convert("RGBA")
    tex_crate = Image.open(os.path.join(ASSETS_DIR, "crate_normal.png")).convert("RGBA")
    tex_crate_goal = Image.open(os.path.join(ASSETS_DIR, "crate_goal.png")).convert("RGBA")
    tex_goal = Image.open(os.path.join(ASSETS_DIR, "goal_pad.png")).convert("RGBA")
    tex_player = Image.open(os.path.join(ASSETS_DIR, "player_down.png")).convert("RGBA")

    # Grid calculation
    play_w = W - 32
    play_h = H - 102 - 76 - 40
    tile_size = int(min(play_w / grid_w, play_h / grid_h, 54))

    board_px_w = grid_w * tile_size
    board_px_h = grid_h * tile_size
    origin_x = (W - board_px_w) // 2
    origin_y = 102 + (play_h - board_px_h) // 2

    # Draw board drop shadow
    draw.rectangle([origin_x + 6, origin_y + 8, origin_x + board_px_w + 6, origin_y + board_px_h + 8], fill=(0, 0, 0, 140))

    # Draw Tiles
    for r in range(grid_h):
        for c in range(grid_w):
            ch = grid[r][c]
            rx = origin_x + c * tile_size
            ry = origin_y + r * tile_size

            if ch == ' ':
                continue # exterior void

            # Draw floor for any interior tile
            f_img = tex_floor1 if (r + c) % 2 == 0 else tex_floor2
            f_scaled = f_img.resize((tile_size, tile_size), Image.Resampling.NEAREST)
            screen.alpha_composite(f_scaled, (rx, ry))

            # Wall
            if ch == '#':
                w_scaled = tex_wall.resize((tile_size, tile_size), Image.Resampling.NEAREST)
                screen.alpha_composite(w_scaled, (rx, ry))

            # Goal
            if ch in ['.', '+', '*']:
                g_scaled = tex_goal.resize((tile_size, tile_size), Image.Resampling.NEAREST)
                screen.alpha_composite(g_scaled, (rx, ry))

            # Crate
            if ch == '$':
                c_scaled = tex_crate.resize((tile_size, tile_size), Image.Resampling.NEAREST)
                screen.alpha_composite(c_scaled, (rx, ry))
            elif ch == '*':
                cg_scaled = tex_crate_goal.resize((tile_size, tile_size), Image.Resampling.NEAREST)
                screen.alpha_composite(cg_scaled, (rx, ry))

            # Player
            if ch in ['@', '+']:
                p_scaled = tex_player.resize((tile_size, tile_size), Image.Resampling.NEAREST)
                screen.alpha_composite(p_scaled, (rx, ry))

    out_path = os.path.join(OUTPUT_DIR, out_filename)
    screen.save(out_path)
    print(f"Saved: {out_path}")

if __name__ == '__main__':
    render_level_image(22, "level_22_new_rendered.png")
    render_level_image(36, "level_36_ref15_rendered.png")

