#!/usr/bin/env python3
"""
tools/generate_warehouse_pallet_dock.py
Generates the definitive warehouse-themed goal pad:
'The Industrial Hydraulic Pallet Loading Dock Plate'
- 100% thematic cohesion with Pixel Sokoban: Warehouse Rush
- Zero scope/crosshairs/military radar
- Octagonal chamfered steel plate with diamond treadplate
- High-visibility safety hazard stripes
- Stenciled pallet alignment brackets, inward cargo guide arrows, and freight diamond
- Flush runway guidance LEDs
"""
import os
import math
from PIL import Image, ImageDraw

SIZE = 128
OUTPUT_PATH = "assets/goal_pad.png"

def create_pallet_dock_sprite():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = 64, 64

    # 1. Outer Dimensions: 104x104 (Leaving 12px clean floor margin on all 4 sides)
    pad = 12
    x0, y0 = pad, pad
    x1, y1 = SIZE - pad, SIZE - pad
    chamfer = 14

    # 8-point Octagonal Contour
    oct_pts = [
        (x0 + chamfer, y0), (x1 - chamfer, y0),
        (x1, y0 + chamfer), (x1, y1 - chamfer),
        (x1 - chamfer, y1), (x0 + chamfer, y1),
        (x0, y1 - chamfer), (x0, y0 + chamfer)
    ]

    # 1. Soft Ambient Drop Shadow cast into warehouse floor planks
    shadow_pts = [(p[0] + 1, p[1] + 2) for p in oct_pts]
    draw.polygon(shadow_pts, fill=(10, 14, 18, 175))

    # 2. Heavy Cast-Steel Base Frame (Milled Gunmetal Steel)
    draw.polygon(oct_pts, fill=(34, 40, 50, 255), outline=(16, 20, 26, 255))

    # Top & Left bright metallic bevel rim
    draw.line([(x0 + chamfer, y0), (x1 - chamfer, y0)], fill=(75, 88, 106, 255), width=2)
    draw.line([(x0, y0 + chamfer), (x0 + chamfer, y0)], fill=(85, 100, 120, 255), width=2)
    draw.line([(x0, y0 + chamfer), (x0, y1 - chamfer)], fill=(75, 88, 106, 255), width=2)

    # Bottom & Right dark shadow rim
    draw.line([(x0 + chamfer, y1), (x1 - chamfer, y1)], fill=(18, 22, 28, 255), width=2)
    draw.line([(x1 - chamfer, y1), (x1, y1 - chamfer)], fill=(16, 20, 26, 255), width=2)
    draw.line([(x1, y0 + chamfer), (x1, y1 - chamfer)], fill=(18, 22, 28, 255), width=2)

    # 3. Industrial Safety Hazard Stripes along the 4 Cardinal Edges
    # Matches the 'WAREHOUSE RUSH' title logo hazard branding
    h_thick = 8
    stripe_w = 7

    # Top Edge Hazard Striping
    top_y0 = y0 + 2
    top_y1 = top_y0 + h_thick
    for sx in range(x0 + chamfer + 2, x1 - chamfer - 2, stripe_w * 2):
        # Yellow stripe
        draw.polygon([
            (sx, top_y0), (min(x1 - chamfer - 2, sx + stripe_w), top_y0),
            (min(x1 - chamfer - 2, sx + stripe_w - 4), top_y1), (max(x0 + chamfer + 2, sx - 4), top_y1)
        ], fill=(245, 180, 30, 255))
        # Black/slate stripe
        draw.polygon([
            (min(x1 - chamfer - 2, sx + stripe_w), top_y0), (min(x1 - chamfer - 2, sx + stripe_w * 2), top_y0),
            (min(x1 - chamfer - 2, sx + stripe_w * 2 - 4), top_y1), (min(x1 - chamfer - 2, sx + stripe_w - 4), top_y1)
        ], fill=(22, 26, 34, 255))

    # Bottom Edge Hazard Striping
    bot_y1 = y1 - 2
    bot_y0 = bot_y1 - h_thick
    for sx in range(x0 + chamfer + 2, x1 - chamfer - 2, stripe_w * 2):
        # Yellow stripe
        draw.polygon([
            (sx, bot_y0), (min(x1 - chamfer - 2, sx + stripe_w), bot_y0),
            (min(x1 - chamfer - 2, sx + stripe_w + 4), bot_y1), (max(x0 + chamfer + 2, sx + 4), bot_y1)
        ], fill=(245, 180, 30, 255))
        # Black/slate stripe
        draw.polygon([
            (min(x1 - chamfer - 2, sx + stripe_w), bot_y0), (min(x1 - chamfer - 2, sx + stripe_w * 2), bot_y0),
            (min(x1 - chamfer - 2, sx + stripe_w * 2 + 4), bot_y1), (min(x1 - chamfer - 2, sx + stripe_w + 4), bot_y1)
        ], fill=(22, 26, 34, 255))

    # Left Edge Hazard Striping
    left_x0 = x0 + 2
    left_x1 = left_x0 + h_thick
    for sy in range(y0 + chamfer + 2, y1 - chamfer - 2, stripe_w * 2):
        # Yellow stripe
        draw.polygon([
            (left_x0, sy), (left_x1, max(y0 + chamfer + 2, sy - 4)),
            (left_x1, min(y1 - chamfer - 2, sy + stripe_w - 4)), (left_x0, min(y1 - chamfer - 2, sy + stripe_w))
        ], fill=(245, 180, 30, 255))
        # Black/slate stripe
        draw.polygon([
            (left_x0, min(y1 - chamfer - 2, sy + stripe_w)), (left_x1, min(y1 - chamfer - 2, sy + stripe_w - 4)),
            (left_x1, min(y1 - chamfer - 2, sy + stripe_w * 2 - 4)), (left_x0, min(y1 - chamfer - 2, sy + stripe_w * 2))
        ], fill=(22, 26, 34, 255))

    # Right Edge Hazard Striping
    right_x1 = x1 - 2
    right_x0 = right_x1 - h_thick
    for sy in range(y0 + chamfer + 2, y1 - chamfer - 2, stripe_w * 2):
        # Yellow stripe
        draw.polygon([
            (right_x0, max(y0 + chamfer + 2, sy - 4)), (right_x1, sy),
            (right_x1, min(y1 - chamfer - 2, sy + stripe_w)), (right_x0, min(y1 - chamfer - 2, sy + stripe_w - 4))
        ], fill=(245, 180, 30, 255))
        # Black/slate stripe
        draw.polygon([
            (right_x0, min(y1 - chamfer - 2, sy + stripe_w - 4)), (right_x1, min(y1 - chamfer - 2, sy + stripe_w)),
            (right_x1, min(y1 - chamfer - 2, sy + stripe_w * 2)), (right_x0, min(y1 - chamfer - 2, sy + stripe_w * 2 - 4))
        ], fill=(22, 26, 34, 255))

    # 4. 4 Heavy Cast-Steel Corner Guide Chamfers with Industrial Hex Mounting Bolts
    # Exactly where the crate's metal reinforced corners align
    corners = [
        (x0, y0, 1, 1),
        (x1, y0, -1, 1),
        (x0, y1, 1, -1),
        (x1, y1, -1, -1)
    ]
    for bx, by, sx, sy in corners:
        # Cast-iron corner chamfer plate
        p1 = (bx + sx * chamfer, by)
        p2 = (bx, by + sy * chamfer)
        p_in = (bx + sx * (chamfer - 3), by + sy * (chamfer - 3))
        draw.polygon([p1, p2, p_in], fill=(48, 56, 70, 255), outline=(22, 26, 34, 255))

        # Heavy steel hex bolt head anchored on the corner plate
        bolt_x = bx + sx * 9
        bolt_y = by + sy * 9
        draw.ellipse([bolt_x - 3, bolt_y - 3, bolt_x + 3, bolt_y + 3], fill=(14, 18, 24, 255))
        draw.ellipse([bolt_x - 2, bolt_y - 2, bolt_x + 2, bolt_y + 2], fill=(160, 175, 195, 255))
        draw.point((int(bolt_x), int(bolt_y)), fill=(255, 255, 255, 255))

    # 5. Recessed Inner Steel Deck Plate (Diamond Treadplate / Checker Plate)
    deck_pad = pad + 11
    dx0, dy0 = deck_pad, deck_pad
    dx1, dy1 = SIZE - deck_pad, SIZE - deck_pad
    d_chamf = 8
    deck_pts = [
        (dx0 + d_chamf, dy0), (dx1 - d_chamf, dy0),
        (dx1, dy0 + d_chamf), (dx1, dy1 - d_chamf),
        (dx1 - d_chamf, dy1), (dx0 + d_chamf, dy1),
        (dx0, dy1 - d_chamf), (dx0, dy0 + d_chamf)
    ]
    # Recessed shadow and floor plate
    draw.polygon(deck_pts, fill=(24, 28, 36, 255), outline=(14, 18, 24, 255))

    # Draw Embossed Diamond-Tread Pattern across the inner steel deck
    step = 9
    for ty in range(dy0 + 4, dy1 - 4, step):
        for tx in range(dx0 + 4, dx1 - 4, step):
            tcx = tx + 4
            tcy = ty + 4
            if tcx > dx0 + 4 and tcx < dx1 - 4 and tcy > dy0 + 4 and tcy < dy1 - 4:
                # Treadplate diamond lozenge
                draw.line([(tcx - 2, tcy), (tcx + 2, tcy)], fill=(48, 58, 72, 180), width=2)
                draw.line([(tcx - 2, tcy + 1), (tcx + 2, tcy + 1)], fill=(14, 18, 24, 200), width=1)
                # Staggered vertical lozenge
                tcx2 = tx + 8
                tcy2 = ty + 8
                if tcx2 < dx1 - 4 and tcy2 < dy1 - 4:
                    draw.line([(tcx2, tcy2 - 2), (tcx2, tcy2 + 2)], fill=(48, 58, 72, 180), width=2)
                    draw.line([(tcx2 + 1, tcy2 - 2), (tcx2 + 1, tcy2 + 2)], fill=(14, 18, 24, 200), width=1)

    # 6. Center Warehouse Cargo Stencil (Industrial Yellow Floor Marking)
    # Stenciled Pallet Placement Corners: [ ┌ ┐ └ ┘ ]
    st_r = 24
    st_len = 11
    col_stencil = (255, 195, 45, 255)
    col_shadow = (30, 22, 10, 240)

    for sx, sy in [(1, 1), (-1, 1), (1, -1), (-1, -1)]:
        px = cx + sx * st_r
        py = cy + sy * st_r
        # Contact shadow under stencil paint
        draw.line([(px, py + 1), (px - sx * st_len, py + 1)], fill=col_shadow, width=2)
        draw.line([(px + 1, py), (px + 1, py - sy * st_len)], fill=col_shadow, width=2)
        # Stencil paint
        draw.line([(px, py), (px - sx * st_len, py)], fill=col_stencil, width=2)
        draw.line([(px, py), (px, py - sy * st_len)], fill=col_stencil, width=2)

    # Inward Cargo Loading Arrows: Left (▶), Right (◀)
    arr_d = 13
    # Left arrow pointing toward center
    draw.polygon([
        (cx - arr_d - 6, cy - 6),
        (cx - arr_d, cy),
        (cx - arr_d - 6, cy + 6)
    ], fill=col_stencil, outline=col_shadow)
    # Right arrow pointing toward center
    draw.polygon([
        (cx + arr_d + 6, cy - 6),
        (cx + arr_d, cy),
        (cx + arr_d + 6, cy + 6)
    ], fill=col_stencil, outline=col_shadow)

    # Top & Bottom Inward Chevrons (▼ from top, ▲ from bottom)
    # Top chevron pointing down
    draw.polygon([
        (cx - 5, cy - arr_d - 5),
        (cx + 5, cy - arr_d - 5),
        (cx, cy - arr_d)
    ], fill=col_stencil, outline=col_shadow)
    # Bottom chevron pointing up
    draw.polygon([
        (cx - 5, cy + arr_d + 5),
        (cx + 5, cy + arr_d + 5),
        (cx, cy + arr_d)
    ], fill=col_stencil, outline=col_shadow)

    # Center Stenciled Freight Diamond (◆) matching crate manifest stamp
    d_sz = 6
    draw.polygon([
        (cx, cy - d_sz), (cx + d_sz, cy),
        (cx, cy + d_sz), (cx - d_sz, cy)
    ], fill=col_stencil, outline=col_shadow)
    draw.point((cx, cy), fill=(255, 255, 220, 255))

    # 7. 4 Flush-Mounted Runway Guidance LEDs at Corner Docks
    for sx, sy in [(1, 1), (-1, 1), (1, -1), (-1, -1)]:
        lx = cx + sx * 38
        ly = cy + sy * 38
        draw.ellipse([lx - 3.5, ly - 3.5, lx + 3.5, ly + 3.5], fill=(14, 18, 24, 255))
        draw.ellipse([lx - 2, ly - 2, lx + 2, ly + 2], fill=(255, 180, 35, 255))
        draw.point((int(lx), int(ly)), fill=(255, 245, 215, 255))

    return img


if __name__ == "__main__":
    pad = create_pallet_dock_sprite()
    pad.save(OUTPUT_PATH)
    print(f"Saved definitive warehouse pallet dock to {OUTPUT_PATH}")

