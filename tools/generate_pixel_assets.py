#!/usr/bin/env python3
"""
Pixel Porter - Asset Generator
Generates high-definition, pixel-perfect 128x128 retro sprite assets for the game:
- crate_normal.png: Detailed wooden shipping crate with corner brackets & rivets
- crate_goal.png: Golden/emerald radiant crate with gold star & glowing rivets
- goal_pad.png: Industrial brass pressure plate target with glowing star runes
- wall_brick.png: 3D perspective warehouse brick wall with top stone ledge
- floor_tile_1.png & floor_tile_2.png: Warehouse floor tiles with rich texture
- player_down.png, player_up.png, player_left.png, player_right.png: The Pixel Porter character
"""

import os
import math
from PIL import Image, ImageDraw

OUTPUT_DIR = "/home/snowz/godot/assets"
os.makedirs(OUTPUT_DIR, exist_ok=True)
SIZE = 128

def create_crate_normal():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Base wooden background (warm oak planks)
    margin = 4
    x0, y0 = margin, margin
    x1, y1 = SIZE - margin, SIZE - margin

    # Draw outer frame base
    draw.rectangle([x0, y0, x1, y1], fill=(138, 86, 42, 255))

    # Inner recessed panel
    inner_margin = 14
    ix0, iy0 = x0 + inner_margin, y0 + inner_margin
    ix1, iy1 = x1 - inner_margin, y1 - inner_margin
    draw.rectangle([ix0, iy0, ix1, iy1], fill=(112, 68, 32, 255))

    # Draw 4 horizontal wooden planks in the recessed panel
    plank_h = (iy1 - iy0) / 4.0
    for i in range(4):
        py0 = int(iy0 + i * plank_h)
        py1 = int(iy0 + (i + 1) * plank_h)
        # plank color variation
        shade = 105 + (i % 2) * 12 - (i == 3) * 6
        draw.rectangle([ix0, py0, ix1, py1], fill=(shade + 8, shade - 30, shade - 65, 255))
        # wood grain subtle lines
        for gx in range(int(ix0 + 6), int(ix1 - 6), 14):
            draw.line([(gx, py0 + 4), (gx + 12, py0 + 4)], fill=(shade - 10, shade - 45, shade - 78, 180), width=1)
        # plank groove line
        if i > 0:
            draw.line([(ix0, py0), (ix1, py0)], fill=(65, 36, 16, 255), width=2)
            draw.line([(ix0, py0 + 1), (ix1, py0 + 1)], fill=(155, 98, 48, 120), width=1)

    # Diagonal wooden cross brace beam
    brace_w = 12
    draw.line([(ix0 + 4, iy0 + 4), (ix1 - 4, iy1 - 4)], fill=(145, 92, 45, 255), width=brace_w)
    draw.line([(ix0 + 4, iy0 + 4), (ix1 - 4, iy1 - 4)], fill=(175, 115, 60, 255), width=brace_w - 4)
    # Cross brace shadow
    draw.line([(ix0 + 4 + 7, iy0 + 4 + 7), (ix1 - 4 + 7, iy1 - 4 + 7)], fill=(55, 30, 12, 90), width=3)

    # Outer wooden border bevel
    # Top and left bright bevel
    draw.line([(x0, y0), (x1, y0)], fill=(185, 125, 68, 255), width=4)
    draw.line([(x0, y0), (x0, y1)], fill=(185, 125, 68, 255), width=4)
    # Bottom and right dark bevel
    draw.line([(x0, y1), (x1, y1)], fill=(75, 42, 18, 255), width=4)
    draw.line([(x1, y0), (x1, y1)], fill=(75, 42, 18, 255), width=4)

    # Inner groove shadow around recessed panel
    draw.line([(ix0, iy0), (ix1, iy0)], fill=(55, 32, 14, 255), width=3)
    draw.line([(ix0, iy0), (ix0, iy1)], fill=(55, 32, 14, 255), width=3)
    draw.line([(ix0, iy1), (ix1, iy1)], fill=(170, 110, 56, 255), width=2)
    draw.line([(ix1, iy0), (ix1, iy1)], fill=(170, 110, 56, 255), width=2)

    # 4 Heavy Reinforced Metal Corner Brackets (L-shaped)
    bracket_len = 28
    bracket_thick = 10
    corner_coords = [
        ((x0, y0), 1, 1),
        ((x1, y0), -1, 1),
        ((x0, y1), 1, -1),
        ((x1, y1), -1, -1),
    ]

    for (cx, cy), dx, dy in corner_coords:
        # L-bracket horizontal leg
        hx0, hx1 = min(cx, cx + dx * bracket_len), max(cx, cx + dx * bracket_len)
        hy0, hy1 = min(cy, cy + dy * bracket_thick), max(cy, cy + dy * bracket_thick)
        draw.rectangle([hx0, hy0, hx1, hy1], fill=(70, 75, 85, 255), outline=(35, 38, 45, 255))

        # L-bracket vertical leg
        vx0, vx1 = min(cx, cx + dx * bracket_thick), max(cx, cx + dx * bracket_thick)
        vy0, vy1 = min(cy, cy + dy * bracket_len), max(cy, cy + dy * bracket_len)
        draw.rectangle([vx0, vy0, vx1, vy1], fill=(70, 75, 85, 255), outline=(35, 38, 45, 255))

        # Highlight edge
        if dy > 0:
            draw.line([(hx0, cy), (hx1, cy)], fill=(140, 150, 165, 255), width=2)
        if dx > 0:
            draw.line([(cx, vy0), (cx, vy1)], fill=(140, 150, 165, 255), width=2)

        # 3D Brass Rivets on each bracket
        rivets = [
            (cx + dx * 5, cy + dy * 5),
            (cx + dx * 19, cy + dy * 5),
            (cx + dx * 5, cy + dy * 19),
        ]
        for rx, ry in rivets:
            # Rivet shadow
            draw.ellipse([rx - 3, ry - 3, rx + 3, ry + 3], fill=(30, 25, 15, 255))
            # Rivet brass base
            draw.ellipse([rx - 2, ry - 2, rx + 2, ry + 2], fill=(215, 165, 55, 255))
            # Rivet specular shine
            draw.point((rx - 1, ry - 1), fill=(255, 240, 175, 255))

    # Center Stencil / Cargo Mark (Diamond with 'P')
    center_x, center_y = SIZE // 2, SIZE // 2
    draw.polygon([
        (center_x, center_y - 12),
        (center_x + 12, center_y),
        (center_x, center_y + 12),
        (center_x - 12, center_y)
    ], fill=(60, 35, 15, 140), outline=(170, 110, 55, 180))

    img.save(os.path.join(OUTPUT_DIR, "crate_normal.png"))
    print("Saved crate_normal.png")


def create_crate_goal():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Radiant golden outer halo
    margin = 4
    x0, y0 = margin, margin
    x1, y1 = SIZE - margin, SIZE - margin

    # Golden base wood with honey amber varnish
    draw.rectangle([x0, y0, x1, y1], fill=(210, 135, 30, 255))

    # Inner recessed panel in deep honey amber
    inner_margin = 14
    ix0, iy0 = x0 + inner_margin, y0 + inner_margin
    ix1, iy1 = x1 - inner_margin, y1 - inner_margin
    draw.rectangle([ix0, iy0, ix1, iy1], fill=(175, 105, 20, 255))

    # Planks with golden sheen
    plank_h = (iy1 - iy0) / 4.0
    for i in range(4):
        py0 = int(iy0 + i * plank_h)
        py1 = int(iy0 + (i + 1) * plank_h)
        shade_r = 205 + (i % 2) * 15
        shade_g = 135 + (i % 2) * 12
        draw.rectangle([ix0, py0, ix1, py1], fill=(shade_r, shade_g, 35, 255))
        if i > 0:
            draw.line([(ix0, py0), (ix1, py0)], fill=(120, 65, 10, 255), width=2)
            draw.line([(ix0, py0 + 1), (ix1, py0 + 1)], fill=(255, 215, 95, 180), width=1)

    # Diagonal beam with emerald/gold aura
    brace_w = 12
    draw.line([(ix0 + 4, iy0 + 4), (ix1 - 4, iy1 - 4)], fill=(235, 165, 45, 255), width=brace_w)
    draw.line([(ix0 + 4, iy0 + 4), (ix1 - 4, iy1 - 4)], fill=(255, 220, 110, 255), width=brace_w - 4)

    # Brilliant Gold Bevel Edges
    draw.line([(x0, y0), (x1, y0)], fill=(255, 235, 140, 255), width=4)
    draw.line([(x0, y0), (x0, y1)], fill=(255, 235, 140, 255), width=4)
    draw.line([(x0, y1), (x1, y1)], fill=(145, 80, 15, 255), width=4)
    draw.line([(x1, y0), (x1, y1)], fill=(145, 80, 15, 255), width=4)

    # Polished Gold Corner Brackets (L-shaped)
    bracket_len = 28
    bracket_thick = 10
    corner_coords = [
        ((x0, y0), 1, 1),
        ((x1, y0), -1, 1),
        ((x0, y1), 1, -1),
        ((x1, y1), -1, -1),
    ]

    for (cx, cy), dx, dy in corner_coords:
        hx0, hx1 = min(cx, cx + dx * bracket_len), max(cx, cx + dx * bracket_len)
        hy0, hy1 = min(cy, cy + dy * bracket_thick), max(cy, cy + dy * bracket_thick)
        draw.rectangle([hx0, hy0, hx1, hy1], fill=(230, 180, 50, 255), outline=(130, 85, 15, 255))

        vx0, vx1 = min(cx, cx + dx * bracket_thick), max(cx, cx + dx * bracket_thick)
        vy0, vy1 = min(cy, cy + dy * bracket_len), max(cy, cy + dy * bracket_len)
        draw.rectangle([vx0, vy0, vx1, vy1], fill=(230, 180, 50, 255), outline=(130, 85, 15, 255))

        # Specular highlight
        if dy > 0:
            draw.line([(hx0, cy), (hx1, cy)], fill=(255, 245, 180, 255), width=2)
        if dx > 0:
            draw.line([(cx, vy0), (cx, vy1)], fill=(255, 245, 180, 255), width=2)

        # Radiant Diamond/Emerald Rivets
        rivets = [
            (cx + dx * 5, cy + dy * 5),
            (cx + dx * 19, cy + dy * 5),
            (cx + dx * 5, cy + dy * 19),
        ]
        for rx, ry in rivets:
            draw.ellipse([rx - 3, ry - 3, rx + 3, ry + 3], fill=(80, 45, 5, 255))
            draw.ellipse([rx - 2, ry - 2, rx + 2, ry + 2], fill=(255, 235, 100, 255))
            draw.point((rx - 1, ry - 1), fill=(255, 255, 255, 255))

    # Gleaming Golden Victory Star Medallion in center!
    center_x, center_y = SIZE // 2, SIZE // 2
    # Outer star glow
    draw.ellipse([center_x - 26, center_y - 26, center_x + 26, center_y + 26], fill=(255, 200, 40, 100))
    draw.ellipse([center_x - 20, center_y - 20, center_x + 20, center_y + 20], fill=(220, 140, 25, 255), outline=(255, 235, 130, 255), width=2)

    # 5-pointed Star
    points = []
    outer_r = 16
    inner_r = 7
    for step in range(10):
        angle = -math.pi / 2 + step * (math.pi / 5)
        r = outer_r if step % 2 == 0 else inner_r
        points.append((center_x + math.cos(angle) * r, center_y + math.sin(angle) * r))
    draw.polygon(points, fill=(255, 235, 80, 255), outline=(180, 110, 15, 255))

    # Star center specular sparkle
    draw.ellipse([center_x - 3, center_y - 3, center_x + 3, center_y + 3], fill=(255, 255, 240, 255))

    img.save(os.path.join(OUTPUT_DIR, "crate_goal.png"))
    print("Saved crate_goal.png")


def create_goal_pad():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center = SIZE // 2

    # Outer brass mechanical ring
    r_outer = 56
    draw.ellipse([center - r_outer, center - r_outer, center + r_outer, center + r_outer],
                 fill=(80, 60, 28, 255), outline=(40, 28, 12, 255), width=2)
    draw.ellipse([center - (r_outer - 3), center - (r_outer - 3), center + (r_outer - 3), center + (r_outer - 3)],
                 fill=(195, 150, 50, 255))
    draw.ellipse([center - (r_outer - 7), center - (r_outer - 7), center + (r_outer - 7), center + (r_outer - 7)],
                 fill=(145, 105, 30, 255))

    # 8 Industrial perimeter bolts
    for i in range(8):
        angle = i * (math.pi / 4)
        bx = center + math.cos(angle) * (r_outer - 5)
        by = center + math.sin(angle) * (r_outer - 5)
        draw.ellipse([bx - 3, by - 3, bx + 3, by + 3], fill=(45, 32, 14, 255))
        draw.ellipse([bx - 2, by - 2, bx + 2, by + 2], fill=(245, 215, 95, 255))
        draw.point((bx - 1, by - 1), fill=(255, 255, 220, 255))

    # Recessed dark circular well
    r_well = 42
    draw.ellipse([center - r_well, center - r_well, center + r_well, center + r_well],
                 fill=(32, 38, 48, 255), outline=(20, 24, 30, 255), width=2)

    # Radial crosshairs & target rings
    r_ring1 = 30
    draw.ellipse([center - r_ring1, center - r_ring1, center + r_ring1, center + r_ring1],
                 outline=(225, 175, 45, 220), width=3)
    r_ring2 = 18
    draw.ellipse([center - r_ring2, center - r_ring2, center + r_ring2, center + r_ring2],
                 outline=(255, 215, 75, 255), width=2)

    # 4 Cardinal crosshair ticks
    tick_len = 10
    draw.line([(center, center - r_ring1 - tick_len), (center, center - r_ring1 + 4)], fill=(255, 215, 75, 255), width=3)
    draw.line([(center, center + r_ring1 - 4), (center, center + r_ring1 + tick_len)], fill=(255, 215, 75, 255), width=3)
    draw.line([(center - r_ring1 - tick_len, center), (center - r_ring1 + 4, center)], fill=(255, 215, 75, 255), width=3)
    draw.line([(center + r_ring1 - 4, center), (center + r_ring1 + tick_len, center)], fill=(255, 215, 75, 255), width=3)

    # Center glowing star pad
    r_core = 9
    draw.ellipse([center - r_core, center - r_core, center + r_core, center + r_core], fill=(255, 235, 120, 255))
    draw.ellipse([center - 4, center - 4, center + 4, center + 4], fill=(255, 255, 235, 255))

    img.save(os.path.join(OUTPUT_DIR, "goal_pad.png"))
    print("Saved goal_pad.png")


def create_wall_brick():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 3D perspective warehouse wall:
    # Top 24 pixels: top stone ledge / coping slab (seen from overhead)
    ledge_h = 24
    draw.rectangle([0, 0, SIZE, ledge_h], fill=(130, 115, 105, 255))
    # Top bevel highlight
    draw.line([(0, 1), (SIZE, 1)], fill=(185, 175, 165, 255), width=2)
    # Ledge stone texture
    for x in range(4, SIZE, 8):
        draw.line([(x, 3), (x + 2, ledge_h - 2)], fill=(115, 100, 92, 160), width=1)
    # Ledge overhang shadow line
    draw.line([(0, ledge_h), (SIZE, ledge_h)], fill=(40, 25, 20, 255), width=3)

    # Face of the wall: 4 courses of warm red/brown warehouse bricks
    wall_y = ledge_h + 3
    wall_h = SIZE - wall_y
    courses = 4
    course_h = wall_h / courses
    mortar_col = (50, 30, 26, 255)

    brick_colors = [
        (165, 68, 55),
        (148, 56, 45),
        (178, 76, 62),
        (135, 50, 40),
        (158, 62, 50)
    ]

    for c in range(courses):
        cy0 = int(wall_y + c * course_h)
        cy1 = int(wall_y + (c + 1) * course_h) - 2 # 2px mortar gap

        # Mortar bed under course
        draw.rectangle([0, cy1, SIZE, cy1 + 2], fill=mortar_col)

        # Staggered bricks
        brick_w = 42
        offset = 0 if c % 2 == 0 else int(brick_w / 2)

        x = -offset
        idx = c * 3
        while x < SIZE:
            bx0 = max(0, x)
            bx1 = min(SIZE, x + brick_w)
            if bx1 > bx0:
                col = brick_colors[idx % len(brick_colors)]
                draw.rectangle([bx0, cy0, bx1, cy1], fill=col + (255,))
                # Brick top highlight
                draw.line([(bx0, cy0), (bx1, cy0)], fill=(min(255, col[0] + 35), min(255, col[1] + 30), min(255, col[2] + 25), 255), width=1)
                # Brick bottom shadow
                draw.line([(bx0, cy1), (bx1, cy1)], fill=(max(0, col[0] - 40), max(0, col[1] - 30), max(0, col[2] - 25), 255), width=1)
                # Vertical mortar joint
                if bx1 < SIZE:
                    draw.rectangle([bx1 - 2, cy0, bx1, cy1], fill=mortar_col)
            x += brick_w + 2
            idx += 1

    # Outer wall border
    draw.rectangle([0, 0, SIZE - 1, SIZE - 1], outline=(35, 20, 16, 255), width=2)

    img.save(os.path.join(OUTPUT_DIR, "wall_brick.png"))
    print("Saved wall_brick.png")


def create_wall_cold_storage():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 3D perspective cold storage brick wall:
    # Top 24 pixels: frosted ice-capped stone coping
    ledge_h = 24
    draw.rectangle([0, 0, SIZE, ledge_h], fill=(100, 135, 165, 255))
    draw.line([(0, 1), (SIZE, 1)], fill=(195, 235, 255, 255), width=2)
    for x in range(4, SIZE, 8):
        draw.line([(x, 3), (x + 2, ledge_h - 2)], fill=(55, 80, 105, 160), width=1)
    draw.line([(0, ledge_h), (SIZE, ledge_h)], fill=(18, 28, 42, 255), width=3)

    # 4 courses of frosted steel-blue warehouse bricks
    wall_y = ledge_h + 3
    wall_h = SIZE - wall_y
    courses = 4
    course_h = wall_h / courses
    mortar_col = (28, 44, 62, 255)

    brick_colors = [
        (78, 112, 148),
        (68, 98, 132),
        (88, 125, 162),
        (60, 90, 122),
        (72, 104, 140)
    ]

    for c in range(courses):
        cy0 = int(wall_y + c * course_h)
        cy1 = int(wall_y + (c + 1) * course_h) - 2

        draw.rectangle([0, cy1, SIZE, cy1 + 2], fill=mortar_col)

        brick_w = 42
        offset = 0 if c % 2 == 0 else int(brick_w / 2)

        x = -offset
        idx = c * 3
        while x < SIZE:
            bx0 = max(0, x)
            bx1 = min(SIZE, x + brick_w)
            if bx1 > bx0:
                col = brick_colors[idx % len(brick_colors)]
                draw.rectangle([bx0, cy0, bx1, cy1], fill=col + (255,))
                draw.line([(bx0, cy0), (bx1, cy0)], fill=(min(255, col[0] + 35), min(255, col[1] + 35), min(255, col[2] + 40), 255), width=1)
                draw.line([(bx0, cy1), (bx1, cy1)], fill=(max(0, col[0] - 35), max(0, col[1] - 35), max(0, col[2] - 35), 255), width=1)
                if bx1 < SIZE:
                    draw.rectangle([bx1 - 2, cy0, bx1, cy1], fill=mortar_col)
            x += brick_w + 2
            idx += 1

    draw.rectangle([0, 0, SIZE - 1, SIZE - 1], outline=(18, 28, 40, 255), width=2)
    img.save(os.path.join(OUTPUT_DIR, "wall_cold_storage.png"))
    print("Saved wall_cold_storage.png")


def create_wall_cyber_depot():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 3D perspective cyber depot slate wall:
    # Top 24 pixels: dark graphite coping with industrial hazard amber highlight
    ledge_h = 24
    draw.rectangle([0, 0, SIZE, ledge_h], fill=(72, 78, 92, 255))
    draw.line([(0, 1), (SIZE, 1)], fill=(255, 185, 45, 255), width=2)
    for x in range(4, SIZE, 8):
        draw.line([(x, 3), (x + 2, ledge_h - 2)], fill=(36, 40, 48, 160), width=1)
    draw.line([(0, ledge_h), (SIZE, ledge_h)], fill=(14, 16, 22, 255), width=3)

    # 4 courses of dark charcoal slate bricks
    wall_y = ledge_h + 3
    wall_h = SIZE - wall_y
    courses = 4
    course_h = wall_h / courses
    mortar_col = (20, 24, 30, 255)

    brick_colors = [
        (56, 64, 76),
        (48, 54, 66),
        (64, 72, 86),
        (42, 48, 58),
        (52, 58, 70)
    ]

    for c in range(courses):
        cy0 = int(wall_y + c * course_h)
        cy1 = int(wall_y + (c + 1) * course_h) - 2

        draw.rectangle([0, cy1, SIZE, cy1 + 2], fill=mortar_col)

        brick_w = 42
        offset = 0 if c % 2 == 0 else int(brick_w / 2)

        x = -offset
        idx = c * 3
        while x < SIZE:
            bx0 = max(0, x)
            bx1 = min(SIZE, x + brick_w)
            if bx1 > bx0:
                col = brick_colors[idx % len(brick_colors)]
                draw.rectangle([bx0, cy0, bx1, cy1], fill=col + (255,))
                draw.line([(bx0, cy0), (bx1, cy0)], fill=(min(255, col[0] + 30), min(255, col[1] + 32), min(255, col[2] + 36), 255), width=1)
                draw.line([(bx0, cy1), (bx1, cy1)], fill=(max(0, col[0] - 28), max(0, col[1] - 30), max(0, col[2] - 32), 255), width=1)
                if bx1 < SIZE:
                    draw.rectangle([bx1 - 2, cy0, bx1, cy1], fill=mortar_col)
            x += brick_w + 2
            idx += 1

    draw.rectangle([0, 0, SIZE - 1, SIZE - 1], outline=(14, 16, 22, 255), width=2)
    img.save(os.path.join(OUTPUT_DIR, "wall_cyber_depot.png"))
    print("Saved wall_cyber_depot.png")


def create_wall_quantum_vault():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 3D perspective quantum vault obsidian wall:
    # Top 24 pixels: prismatic obsidian coping with luminous amethyst highlight
    ledge_h = 24
    draw.rectangle([0, 0, SIZE, ledge_h], fill=(88, 58, 116, 255))
    draw.line([(0, 1), (SIZE, 1)], fill=(235, 175, 255, 255), width=2)
    for x in range(4, SIZE, 8):
        draw.line([(x, 3), (x + 2, ledge_h - 2)], fill=(38, 22, 52, 160), width=1)
    draw.line([(0, ledge_h), (SIZE, ledge_h)], fill=(16, 8, 24, 255), width=3)

    # 4 courses of deep royal violet / obsidian bricks
    wall_y = ledge_h + 3
    wall_h = SIZE - wall_y
    courses = 4
    course_h = wall_h / courses
    mortar_col = (24, 14, 34, 255)

    brick_colors = [
        (76, 48, 102),
        (64, 38, 88),
        (86, 56, 116),
        (54, 32, 76),
        (70, 44, 94)
    ]

    for c in range(courses):
        cy0 = int(wall_y + c * course_h)
        cy1 = int(wall_y + (c + 1) * course_h) - 2

        draw.rectangle([0, cy1, SIZE, cy1 + 2], fill=mortar_col)

        brick_w = 42
        offset = 0 if c % 2 == 0 else int(brick_w / 2)

        x = -offset
        idx = c * 3
        while x < SIZE:
            bx0 = max(0, x)
            bx1 = min(SIZE, x + brick_w)
            if bx1 > bx0:
                col = brick_colors[idx % len(brick_colors)]
                draw.rectangle([bx0, cy0, bx1, cy1], fill=col + (255,))
                draw.line([(bx0, cy0), (bx1, cy0)], fill=(min(255, col[0] + 35), min(255, col[1] + 30), min(255, col[2] + 45), 255), width=1)
                draw.line([(bx0, cy1), (bx1, cy1)], fill=(max(0, col[0] - 32), max(0, col[1] - 25), max(0, col[2] - 38), 255), width=1)
                if bx1 < SIZE:
                    draw.rectangle([bx1 - 2, cy0, bx1, cy1], fill=mortar_col)
            x += brick_w + 2
            idx += 1

    draw.rectangle([0, 0, SIZE - 1, SIZE - 1], outline=(16, 10, 24, 255), width=2)
    img.save(os.path.join(OUTPUT_DIR, "wall_quantum_vault.png"))
    print("Saved wall_quantum_vault.png")


def create_floor_tiles():
    # Tile 1: Industrial warehouse hardwood/concrete panel
    img1 = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw1 = ImageDraw.Draw(img1)
    base_col = (42, 52, 62, 255) # Deep stylish slate
    draw1.rectangle([0, 0, SIZE, SIZE], fill=base_col)

    # 4 Horizontal warehouse floor planks
    plank_h = SIZE / 4.0
    for i in range(4):
        py0 = int(i * plank_h)
        py1 = int((i + 1) * plank_h)
        shade_offset = (i % 2) * 5
        draw1.rectangle([2, py0 + 1, SIZE - 2, py1 - 1], fill=(42 + shade_offset, 52 + shade_offset, 62 + shade_offset, 255))
        # Subtle plank highlight
        draw1.line([(2, py0 + 1), (SIZE - 2, py0 + 1)], fill=(58, 70, 82, 180), width=1)
        # Groove
        draw1.line([(0, py1), (SIZE, py1)], fill=(28, 35, 42, 255), width=1)

    # Fine floor tile perimeter seam
    draw1.rectangle([0, 0, SIZE - 1, SIZE - 1], outline=(28, 35, 42, 255), width=1)
    img1.save(os.path.join(OUTPUT_DIR, "floor_tile_1.png"))
    print("Saved floor_tile_1.png")

    # Tile 2: Alternating variant with vertical seam
    img2 = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw2 = ImageDraw.Draw(img2)
    draw2.rectangle([0, 0, SIZE, SIZE], fill=(38, 48, 58, 255))
    for i in range(4):
        py0 = int(i * plank_h)
        py1 = int((i + 1) * plank_h)
        shade_offset = ((i + 1) % 2) * 6
        draw2.rectangle([2, py0 + 1, SIZE - 2, py1 - 1], fill=(38 + shade_offset, 48 + shade_offset, 58 + shade_offset, 255))
        draw2.line([(2, py0 + 1), (SIZE - 2, py0 + 1)], fill=(52, 64, 76, 180), width=1)
        draw2.line([(0, py1), (SIZE, py1)], fill=(25, 32, 38, 255), width=1)

    # Staggered vertical plank end
    draw2.line([(SIZE // 2, 0), (SIZE // 2, int(plank_h * 2))], fill=(25, 32, 38, 255), width=1)
    draw2.rectangle([0, 0, SIZE - 1, SIZE - 1], outline=(25, 32, 38, 255), width=1)
    img2.save(os.path.join(OUTPUT_DIR, "floor_tile_2.png"))
    print("Saved floor_tile_2.png")


def create_player_sprites():
    # Helper to draw the Porter character in all 4 directions
    # 1. player_down (Facing player / camera)
    img_d = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img_d)
    cx = SIZE // 2

    # Drop shadow
    d.ellipse([cx - 32, 98, cx + 32, 118], fill=(0, 0, 0, 95))

    # Sturdy Work Boots (Brown leather)
    # Left boot
    d.rectangle([cx - 24, 94, cx - 8, 108], fill=(70, 42, 22, 255), outline=(35, 18, 8, 255))
    d.rectangle([cx - 24, 106, cx - 8, 110], fill=(45, 25, 12, 255)) # boot sole
    # Right boot
    d.rectangle([cx + 8, 94, cx + 24, 108], fill=(70, 42, 22, 255), outline=(35, 18, 8, 255))
    d.rectangle([cx + 8, 106, cx + 24, 110], fill=(45, 25, 12, 255))

    # Overalls legs (Denim Blue)
    d.rectangle([cx - 22, 72, cx - 6, 96], fill=(38, 75, 142, 255), outline=(20, 42, 85, 255))
    d.rectangle([cx + 6, 72, cx + 22, 96], fill=(38, 75, 142, 255), outline=(20, 42, 85, 255))

    # Overalls Torso / Body
    d.rectangle([cx - 22, 48, cx + 22, 76], fill=(46, 88, 165, 255), outline=(20, 42, 85, 255))
    # Red worker shirt underneath (peeking at shoulders & sides)
    d.rectangle([cx - 28, 48, cx - 22, 68], fill=(215, 42, 38, 255), outline=(130, 20, 18, 255))
    d.rectangle([cx + 22, 48, cx + 28, 68], fill=(215, 42, 38, 255), outline=(130, 20, 18, 255))

    # Overalls suspender straps & brass buckles
    d.line([(cx - 14, 48), (cx - 14, 62)], fill=(28, 58, 115, 255), width=6)
    d.line([(cx + 14, 48), (cx + 14, 62)], fill=(28, 58, 115, 255), width=6)
    # Brass buckles
    d.rectangle([cx - 17, 60, cx - 11, 65], fill=(235, 185, 55, 255))
    d.rectangle([cx + 11, 60, cx + 17, 65], fill=(235, 185, 55, 255))
    # Center bib pocket
    d.rectangle([cx - 8, 62, cx + 8, 72], fill=(38, 75, 142, 255), outline=(25, 50, 98, 255))

    # White Work Gloves (Hands at sides)
    d.ellipse([cx - 32, 64, cx - 20, 78], fill=(240, 240, 245, 255), outline=(150, 155, 165, 255))
    d.ellipse([cx + 20, 64, cx + 32, 78], fill=(240, 240, 245, 255), outline=(150, 155, 165, 255))

    # Head / Face
    head_y = 36
    head_r = 18
    d.ellipse([cx - head_r, head_y - head_r, cx + head_r, head_y + head_r],
              fill=(252, 205, 168, 255), outline=(195, 135, 95, 255), width=2)
    # Rosy cheeks
    d.ellipse([cx - 15, head_y + 2, cx - 9, head_y + 8], fill=(245, 165, 145, 160))
    d.ellipse([cx + 9, head_y + 2, cx + 15, head_y + 8], fill=(245, 165, 145, 160))
    # Big expressive eyes
    d.ellipse([cx - 10, head_y - 4, cx - 3, head_y + 4], fill=(25, 25, 30, 255))
    d.ellipse([cx + 3, head_y - 4, cx + 10, head_y + 4], fill=(25, 25, 30, 255))
    # Eye sparkles
    d.point((cx - 7, head_y - 2), fill=(255, 255, 255, 255))
    d.point((cx + 6, head_y - 2), fill=(255, 255, 255, 255))
    # Friendly smile
    d.arc([cx - 6, head_y + 4, cx + 6, head_y + 11], 0, 180, fill=(160, 80, 50, 255), width=2)

    # Red Porter Cap
    cap_y = head_y - 10
    # Cap dome
    d.pieslice([cx - 20, cap_y - 16, cx + 20, cap_y + 16], 180, 360, fill=(225, 36, 32, 255), outline=(140, 18, 15, 255), width=2)
    # Cap button on top
    d.ellipse([cx - 3, cap_y - 18, cx + 3, cap_y - 12], fill=(160, 20, 16, 255))
    # Cap Visor (pointing forward/curved)
    d.rectangle([cx - 22, cap_y - 2, cx + 22, cap_y + 6], fill=(175, 24, 20, 255), outline=(120, 15, 12, 255))
    d.line([(cx - 20, cap_y - 1), (cx + 20, cap_y - 1)], fill=(245, 80, 75, 255), width=1)

    img_d.save(os.path.join(OUTPUT_DIR, "player_down.png"))
    print("Saved player_down.png")

    # 2. player_up (Back to camera)
    img_u = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    u = ImageDraw.Draw(img_u)

    # Drop shadow
    u.ellipse([cx - 32, 98, cx + 32, 118], fill=(0, 0, 0, 95))

    # Boots (back view)
    u.rectangle([cx - 24, 94, cx - 8, 108], fill=(60, 36, 18, 255), outline=(35, 18, 8, 255))
    u.rectangle([cx - 24, 106, cx - 8, 110], fill=(45, 25, 12, 255))
    u.rectangle([cx + 8, 94, cx + 24, 108], fill=(60, 36, 18, 255), outline=(35, 18, 8, 255))
    u.rectangle([cx + 8, 106, cx + 24, 110], fill=(45, 25, 12, 255))

    # Overalls legs
    u.rectangle([cx - 22, 72, cx - 6, 96], fill=(32, 65, 125, 255), outline=(20, 42, 85, 255))
    u.rectangle([cx + 6, 72, cx + 22, 96], fill=(32, 65, 125, 255), outline=(20, 42, 85, 255))

    # Overalls back & Red shirt
    u.rectangle([cx - 22, 48, cx + 22, 76], fill=(40, 80, 150, 255), outline=(20, 42, 85, 255))
    u.rectangle([cx - 28, 48, cx - 22, 68], fill=(195, 36, 32, 255), outline=(130, 20, 18, 255))
    u.rectangle([cx + 22, 48, cx + 28, 68], fill=(195, 36, 32, 255), outline=(130, 20, 18, 255))

    # "X" Back straps of overalls
    u.line([(cx - 14, 48), (cx + 14, 76)], fill=(25, 52, 105, 255), width=6)
    u.line([(cx + 14, 48), (cx - 14, 76)], fill=(25, 52, 105, 255), width=6)

    # Head (back view / dark hair)
    u.ellipse([cx - head_r, head_y - head_r, cx + head_r, head_y + head_r], fill=(55, 35, 25, 255))

    # Red cap back
    u.pieslice([cx - 20, cap_y - 18, cx + 20, cap_y + 14], 180, 360, fill=(225, 36, 32, 255), outline=(140, 18, 15, 255), width=2)
    # Cap opening & adjustment strap
    u.arc([cx - 8, cap_y - 2, cx + 8, cap_y + 8], 0, 180, fill=(252, 205, 168, 255), width=4)
    u.line([(cx - 8, cap_y + 4), (cx + 8, cap_y + 4)], fill=(150, 20, 16, 255), width=2)

    img_u.save(os.path.join(OUTPUT_DIR, "player_up.png"))
    print("Saved player_up.png")

    # 3. player_left (Profile view pushing/walking left)
    img_l = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    l = ImageDraw.Draw(img_l)

    # Drop shadow
    l.ellipse([cx - 30, 98, cx + 24, 118], fill=(0, 0, 0, 95))

    # Boots (stepping left)
    l.rectangle([cx - 24, 94, cx - 6, 108], fill=(70, 42, 22, 255), outline=(35, 18, 8, 255))
    l.rectangle([cx - 26, 106, cx - 6, 110], fill=(45, 25, 12, 255)) # front boot
    l.rectangle([cx + 4, 92, cx + 18, 106], fill=(55, 32, 16, 255), outline=(35, 18, 8, 255)) # back boot

    # Legs & Overalls
    l.rectangle([cx - 18, 70, cx + 4, 96], fill=(38, 75, 142, 255), outline=(20, 42, 85, 255))
    l.rectangle([cx - 14, 48, cx + 16, 76], fill=(46, 88, 165, 255), outline=(20, 42, 85, 255))
    # Red shirt
    d_shirt_x = cx + 8
    l.rectangle([d_shirt_x, 48, d_shirt_x + 8, 68], fill=(215, 42, 38, 255), outline=(130, 20, 18, 255))

    # Pushing arm extended left!
    l.line([(cx + 4, 56), (cx - 22, 60)], fill=(215, 42, 38, 255), width=10)
    # White glove pushing forward
    l.ellipse([cx - 32, 52, cx - 18, 68], fill=(240, 240, 245, 255), outline=(150, 155, 165, 255))

    # Head (profile left)
    l.ellipse([cx - 16, head_y - 16, cx + 16, head_y + 16], fill=(252, 205, 168, 255), outline=(195, 135, 95, 255), width=2)
    # Nose pointing left
    l.polygon([(cx - 14, head_y), (cx - 20, head_y + 3), (cx - 14, head_y + 6)], fill=(252, 205, 168, 255))
    # Eye looking left
    l.ellipse([cx - 12, head_y - 4, cx - 6, head_y + 4], fill=(25, 25, 30, 255))
    l.point((cx - 10, head_y - 2), fill=(255, 255, 255, 255))

    # Red Cap with visor pointing LEFT
    l.pieslice([cx - 18, cap_y - 16, cx + 18, cap_y + 16], 180, 360, fill=(225, 36, 32, 255), outline=(140, 18, 15, 255), width=2)
    # Visor sticking out left!
    l.polygon([(cx - 16, cap_y + 2), (cx - 32, cap_y + 6), (cx - 14, cap_y + 10)], fill=(175, 24, 20, 255), outline=(120, 15, 12, 255))

    img_l.save(os.path.join(OUTPUT_DIR, "player_left.png"))
    print("Saved player_left.png")

    # 4. player_right (Mirrored profile view)
    img_r = img_l.transpose(Image.FLIP_LEFT_RIGHT)
    img_r.save(os.path.join(OUTPUT_DIR, "player_right.png"))
    print("Saved player_right.png")


if __name__ == "__main__":
    create_crate_normal()
    create_crate_goal()
    create_goal_pad()
    create_wall_brick()
    create_wall_cold_storage()
    create_wall_cyber_depot()
    create_wall_quantum_vault()
    create_floor_tiles()
    # Note: Player character sprites are maintained by tools/generate_premium_sprites.py
    print("ALL SPRITES GENERATED SUCCESSFULLY!")
