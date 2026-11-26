#!/usr/bin/env python3
"""
Pixel Porter - Premium 16-Bit Pixel Art Character & Locomotion Generator
Generates all 12 high-fidelity character sprites:
- player_down.png, player_down_walk1.png, player_down_walk2.png
- player_up.png, player_up_walk1.png, player_up_walk2.png
- player_left.png, player_left_walk1.png, player_left_walk2.png
- player_right.png, player_right_walk1.png, player_right_walk2.png
"""

import os
import numpy as np
from PIL import Image

OUTPUT_DIR = "/home/snowz/godot/assets"
ARTIFACT_DIR = "/home/snowz/.gemini/antigravity/brain/db19d3e6-5897-4bec-b12d-4a1222e63add"
W, H = 64, 64

# Rich, curated 32-bit modern indie palette (RGBA)
CLR = {
    'trans': (0, 0, 0, 0),
    'out': (20, 22, 30, 255),
    
    # Cap
    'cap_out': (80, 12, 16, 255),
    'cap_dark': (125, 18, 24, 255),
    'cap_base': (195, 34, 40, 255),
    'cap_mid': (225, 48, 55, 255),
    'cap_hi': (250, 90, 96, 255),
    'cap_visor_bot': (75, 10, 15, 255),
    'cap_badge': (250, 205, 55, 255),
    'cap_badge_sh': (180, 135, 25, 255),
    'cap_strap': (55, 32, 20, 255),
    
    # Hair
    'hair_dark': (42, 24, 16, 255),
    'hair_base': (85, 48, 30, 255),
    'hair_hi': (135, 78, 48, 255),
    
    # Skin
    'skin_out': (160, 95, 68, 255),
    'skin_sh': (210, 140, 108, 255),
    'skin_base': (248, 192, 160, 255),
    'skin_hi': (255, 218, 195, 255),
    'blush': (245, 145, 135, 255),
    
    # Eyes
    'eye_white': (245, 248, 252, 255),
    'eye_iris': (38, 52, 78, 255),
    'eye_pupil': (16, 18, 28, 255),
    'eye_hi': (255, 255, 255, 255),
    
    # Shirt
    'shirt_sh': (125, 20, 25, 255),
    'shirt_base': (185, 34, 40, 255),
    'shirt_hi': (225, 58, 65, 255),
    
    # Denim Overalls
    'denim_out': (18, 28, 55, 255),
    'denim_sh': (28, 48, 95, 255),
    'denim_base': (42, 72, 142, 255),
    'denim_mid': (55, 95, 178, 255),
    'denim_hi': (80, 130, 215, 255),
    'denim_far': (25, 42, 85, 255),     # Shaded far leg in side view
    'denim_far_sh': (18, 28, 60, 255),
    'denim_seam': (235, 185, 45, 255),
    'brass': (245, 195, 55, 255),
    'brass_sh': (175, 125, 25, 255),
    
    # Belt & Pouch
    'belt_base': (75, 45, 26, 255),
    'belt_sh': (48, 26, 14, 255),
    
    # Gloves
    'glove_out': (120, 75, 25, 255),
    'glove_sh': (170, 110, 35, 255),
    'glove_base': (225, 155, 50, 255),
    'glove_hi': (250, 195, 80, 255),
    'glove_cuff': (140, 85, 30, 255),
    'glove_far': (155, 100, 32, 255),
    
    # Boots
    'boot_out': (35, 20, 12, 255),
    'boot_sole': (22, 22, 26, 255),
    'boot_sh': (60, 35, 20, 255),
    'boot_base': (95, 52, 30, 255),
    'boot_hi': (140, 80, 45, 255),
    'boot_toe': (165, 100, 60, 255),
    'boot_far': (65, 36, 20, 255),
    'boot_far_sh': (42, 22, 14, 255),
}

class CanvasBuilder:
    def __init__(self):
        self.canvas = np.zeros((H, W, 4), dtype=np.uint8)
        
    def fill_rect(self, x0, y0, x1, y1, col_name):
        c = CLR[col_name]
        self.canvas[y0:y1+1, x0:x1+1] = c
        
    def set_px(self, x, y, col_name):
        if 0 <= x < W and 0 <= y < H:
            self.canvas[y, x] = CLR[col_name]
            
    def get_image(self):
        img_64 = Image.fromarray(self.canvas, 'RGBA')
        return img_64.resize((128, 128), Image.NEAREST)


def build_down_frame(walk_frame=0):
    # walk_frame: 0=idle, 1=left forward, 2=right forward
    c = CanvasBuilder()
    
    bob = 1 if walk_frame > 0 else 0
    l_stride = 3 if walk_frame == 1 else (-3 if walk_frame == 2 else 0)
    r_stride = -3 if walk_frame == 1 else (3 if walk_frame == 2 else 0)
    l_arm_swing = -2 if walk_frame == 1 else (2 if walk_frame == 2 else 0)
    r_arm_swing = 2 if walk_frame == 1 else (-2 if walk_frame == 2 else 0)
    
    # Cap Crown (Y: 6+bob to 13+bob)
    c.fill_rect(27, 6+bob, 36, 6+bob, 'cap_hi')
    c.fill_rect(24, 7+bob, 39, 7+bob, 'cap_mid')
    c.fill_rect(22, 8+bob, 41, 10+bob, 'cap_base')
    c.fill_rect(21, 11+bob, 42, 13+bob, 'cap_base')
    c.fill_rect(21, 10+bob, 22, 13+bob, 'cap_dark')
    c.fill_rect(41, 10+bob, 42, 13+bob, 'cap_dark')
    c.fill_rect(31, 7+bob, 32, 12+bob, 'cap_dark') # Center seam
    c.set_px(31, 6+bob, 'cap_mid')
    
    # Cap top button
    c.fill_rect(30, 5+bob, 33, 5+bob, 'cap_dark')
    c.set_px(31, 5+bob, 'cap_badge')
    c.set_px(32, 5+bob, 'cap_badge')

    # Cap Visor (Y: 14+bob to 16+bob)
    c.fill_rect(20, 14+bob, 43, 14+bob, 'cap_hi')
    c.fill_rect(19, 15+bob, 44, 15+bob, 'cap_base')
    c.fill_rect(20, 16+bob, 43, 16+bob, 'cap_visor_bot')
    
    # Cap brass badge
    c.fill_rect(29, 11+bob, 34, 13+bob, 'cap_badge')
    c.set_px(29, 11+bob, 'cap_badge_sh')
    c.set_px(34, 13+bob, 'cap_badge_sh')
    c.set_px(31, 12+bob, 'cap_out')
    c.set_px(32, 12+bob, 'cap_out')
    
    # Hair
    c.fill_rect(19, 17+bob, 21, 20+bob, 'hair_base')
    c.fill_rect(42, 17+bob, 44, 20+bob, 'hair_base')
    c.set_px(19, 21+bob, 'hair_dark')
    c.set_px(44, 21+bob, 'hair_dark')
    c.set_px(21, 18+bob, 'hair_hi')
    c.set_px(42, 18+bob, 'hair_hi')
    
    # Face
    c.fill_rect(22, 17+bob, 41, 24+bob, 'skin_base')
    c.fill_rect(24, 25+bob, 39, 25+bob, 'skin_base')
    c.fill_rect(26, 26+bob, 37, 26+bob, 'skin_sh')
    c.fill_rect(22, 17+bob, 41, 17+bob, 'skin_sh')
    
    # Cheek blush
    c.fill_rect(23, 22+bob, 25, 23+bob, 'blush')
    c.fill_rect(38, 22+bob, 40, 23+bob, 'blush')
    
    # Eyes
    c.fill_rect(25, 18+bob, 28, 18+bob, 'hair_dark')
    c.fill_rect(35, 18+bob, 38, 18+bob, 'hair_dark')
    c.fill_rect(25, 19+bob, 28, 21+bob, 'eye_white')
    c.fill_rect(26, 19+bob, 28, 21+bob, 'eye_iris')
    c.fill_rect(26, 20+bob, 27, 21+bob, 'eye_pupil')
    c.set_px(26, 19+bob, 'eye_hi')
    
    c.fill_rect(35, 19+bob, 38, 21+bob, 'eye_white')
    c.fill_rect(35, 19+bob, 37, 21+bob, 'eye_iris')
    c.fill_rect(36, 20+bob, 37, 21+bob, 'eye_pupil')
    c.set_px(37, 19+bob, 'eye_hi')
    
    # Nose
    c.set_px(31, 22+bob, 'skin_hi')
    c.set_px(32, 22+bob, 'skin_sh')
    
    # Cheerful Smile
    c.set_px(29, 24+bob, 'skin_out')
    c.fill_rect(30, 25+bob, 33, 25+bob, 'skin_out')
    c.set_px(34, 24+bob, 'skin_out')
    
    # Neck & Collar
    c.fill_rect(28, 27+bob, 35, 27+bob, 'skin_sh')
    c.fill_rect(25, 28+bob, 27, 29+bob, 'shirt_hi')
    c.fill_rect(36, 28+bob, 38, 29+bob, 'shirt_hi')
    c.fill_rect(28, 28+bob, 35, 28+bob, 'shirt_base')

    # Torso & Shoulders
    c.fill_rect(18, 29+bob, 22, 34+bob, 'shirt_base')
    c.fill_rect(41, 29+bob, 45, 34+bob, 'shirt_base')
    c.fill_rect(19, 29+bob, 21, 30+bob, 'shirt_hi')
    c.fill_rect(42, 29+bob, 44, 30+bob, 'shirt_hi')
    
    # Denim Bib & Body
    c.fill_rect(23, 29+bob, 40, 42+bob, 'denim_base')
    c.fill_rect(24, 30+bob, 39, 41+bob, 'denim_mid')
    c.fill_rect(24, 29+bob, 26, 35+bob, 'denim_sh')
    c.fill_rect(37, 29+bob, 39, 35+bob, 'denim_sh')
    # Brass buckles
    c.fill_rect(23, 34+bob, 26, 35+bob, 'brass')
    c.fill_rect(37, 34+bob, 40, 35+bob, 'brass')
    c.set_px(23, 35+bob, 'brass_sh')
    c.set_px(40, 35+bob, 'brass_sh')
    
    # Pocket & pencil
    c.fill_rect(28, 33+bob, 35, 38+bob, 'denim_sh')
    c.fill_rect(29, 34+bob, 34, 37+bob, 'denim_base')
    c.set_px(33, 32+bob, 'brass')
    c.set_px(33, 31+bob, 'brass')
    c.set_px(33, 30+bob, 'cap_base')
    c.set_px(28, 33+bob, 'brass')
    c.set_px(35, 33+bob, 'brass')
    
    # Utility Belt
    c.fill_rect(22, 42+bob, 41, 43+bob, 'belt_base')
    c.fill_rect(22, 44+bob, 41, 44+bob, 'belt_sh')
    c.fill_rect(30, 42+bob, 33, 44+bob, 'brass')
    c.set_px(31, 43+bob, 'belt_sh')
    c.set_px(32, 43+bob, 'belt_sh')
    c.fill_rect(40, 41+bob, 43, 46+bob, 'belt_base')
    c.fill_rect(41, 42+bob, 42, 45+bob, 'belt_sh')
    c.set_px(42, 41+bob, 'brass')

    # Arms & Work Gloves
    # Left Arm (Screen Left)
    lay = 33 + bob + l_arm_swing
    c.fill_rect(16, lay, 20, lay+5, 'shirt_base')
    c.fill_rect(15, lay+1, 16, lay+5, 'shirt_sh')
    c.fill_rect(15, lay+6, 21, lay+7, 'glove_cuff')
    c.fill_rect(14, lay+8, 21, lay+13, 'glove_base')
    c.fill_rect(15, lay+8, 20, lay+10, 'glove_hi')
    c.fill_rect(14, lay+12, 21, lay+13, 'glove_sh')
    c.fill_rect(20, lay+9, 22, lay+11, 'glove_base')

    # Right Arm (Screen Right)
    ray = 33 + bob + r_arm_swing
    c.fill_rect(43, ray, 47, ray+5, 'shirt_base')
    c.fill_rect(47, ray+1, 48, ray+5, 'shirt_sh')
    c.fill_rect(42, ray+6, 48, ray+7, 'glove_cuff')
    c.fill_rect(42, ray+8, 49, ray+13, 'glove_base')
    c.fill_rect(43, ray+8, 48, ray+10, 'glove_hi')
    c.fill_rect(42, ray+12, 49, ray+13, 'glove_sh')
    c.fill_rect(41, ray+9, 43, ray+11, 'glove_base')

    # Legs & Boots
    # Left Leg & Boot (Screen Left)
    ly_top = 45 + bob
    ly_bot = 53 + l_stride
    c.fill_rect(23, ly_top, 30, ly_bot-1, 'denim_base')
    c.fill_rect(24, ly_top+1, 29, ly_bot-3, 'denim_mid')
    c.fill_rect(23, ly_top, 24, ly_bot-1, 'denim_sh')
    c.fill_rect(23, ly_bot-1, 30, ly_bot, 'denim_hi') # Pant cuff
    c.fill_rect(23, ly_bot+1, 30, ly_bot+1, 'denim_out')
    
    # Left Boot
    by_l = ly_bot + 2
    c.fill_rect(22, by_l, 30, by_l+4, 'boot_base')
    c.fill_rect(21, by_l+2, 23, by_l+4, 'boot_toe')
    c.fill_rect(24, by_l, 29, by_l+1, 'boot_hi')
    c.fill_rect(21, by_l+5, 31, by_l+6, 'boot_sole')
    c.set_px(21, by_l+4, 'boot_sole')
    c.set_px(31, by_l+4, 'boot_sole')
    c.set_px(26, by_l+6, 'out')

    # Right Leg & Boot (Screen Right)
    ry_top = 45 + bob
    ry_bot = 53 + r_stride
    c.fill_rect(33, ry_top, 40, ry_bot-1, 'denim_base')
    c.fill_rect(34, ry_top+1, 39, ry_bot-3, 'denim_mid')
    c.fill_rect(39, ry_top, 40, ry_bot-1, 'denim_sh')
    c.fill_rect(33, ry_bot-1, 40, ry_bot, 'denim_hi') # Pant cuff
    c.fill_rect(33, ry_bot+1, 40, ry_bot+1, 'denim_out')
    
    # Right Boot
    by_r = ry_bot + 2
    c.fill_rect(33, by_r, 41, by_r+4, 'boot_base')
    c.fill_rect(40, by_r+2, 42, by_r+4, 'boot_toe')
    c.fill_rect(34, by_r, 39, by_r+1, 'boot_hi')
    c.fill_rect(32, by_r+5, 42, by_r+6, 'boot_sole')
    c.set_px(32, by_r+4, 'boot_sole')
    c.set_px(42, by_r+4, 'boot_sole')
    c.set_px(37, by_r+6, 'out')

    # Crotch seam
    c.fill_rect(31, 44+bob, 32, 48+bob, 'denim_out')

    return c.get_image()


def build_up_frame(walk_frame=0):
    c = CanvasBuilder()
    bob = 1 if walk_frame > 0 else 0
    l_stride = 3 if walk_frame == 1 else (-3 if walk_frame == 2 else 0)
    r_stride = -3 if walk_frame == 1 else (3 if walk_frame == 2 else 0)
    l_arm_swing = 2 if walk_frame == 1 else (-2 if walk_frame == 2 else 0)
    r_arm_swing = -2 if walk_frame == 1 else (2 if walk_frame == 2 else 0)

    # Back of Cap Crown (Y: 6+bob to 15+bob)
    c.fill_rect(27, 6+bob, 36, 6+bob, 'cap_hi')
    c.fill_rect(24, 7+bob, 39, 7+bob, 'cap_mid')
    c.fill_rect(22, 8+bob, 41, 13+bob, 'cap_base')
    c.fill_rect(21, 10+bob, 42, 14+bob, 'cap_base')
    c.fill_rect(21, 10+bob, 22, 14+bob, 'cap_dark')
    c.fill_rect(41, 10+bob, 42, 14+bob, 'cap_dark')
    c.fill_rect(31, 7+bob, 32, 13+bob, 'cap_dark')
    c.set_px(31, 6+bob, 'cap_mid')

    # Back cap button & arch adjustment cutout
    c.fill_rect(30, 5+bob, 33, 5+bob, 'cap_dark')
    c.set_px(31, 5+bob, 'cap_mid')
    c.set_px(32, 5+bob, 'cap_mid')
    # Arch cutout & leather strap
    c.fill_rect(29, 13+bob, 34, 14+bob, 'skin_sh')
    c.fill_rect(28, 15+bob, 35, 15+bob, 'cap_strap')
    c.set_px(31, 15+bob, 'brass')

    # Hair at Nape of Neck (Y: 16+bob to 23+bob)
    c.fill_rect(20, 16+bob, 43, 20+bob, 'hair_base')
    c.fill_rect(22, 21+bob, 41, 23+bob, 'hair_dark')
    c.fill_rect(24, 17+bob, 39, 19+bob, 'hair_hi')
    # Sideburn fringes
    c.fill_rect(19, 18+bob, 21, 22+bob, 'hair_base')
    c.fill_rect(42, 18+bob, 44, 22+bob, 'hair_base')
    c.set_px(19, 23+bob, 'hair_dark')
    c.set_px(44, 23+bob, 'hair_dark')

    # Neck
    c.fill_rect(27, 24+bob, 36, 26+bob, 'skin_sh')
    
    # Red Shirt Collar & Shoulders (Y: 27+bob to 35+bob)
    c.fill_rect(24, 27+bob, 39, 28+bob, 'shirt_base')
    c.fill_rect(18, 29+bob, 45, 34+bob, 'shirt_base')
    c.fill_rect(19, 29+bob, 22, 30+bob, 'shirt_hi')
    c.fill_rect(41, 29+bob, 44, 30+bob, 'shirt_hi')
    c.fill_rect(25, 27+bob, 38, 27+bob, 'shirt_hi')

    # Back Overalls with X-Susenders (Y: 29+bob to 43+bob)
    c.fill_rect(23, 29+bob, 40, 42+bob, 'denim_base')
    c.fill_rect(24, 30+bob, 39, 41+bob, 'denim_mid')
    # Crossed suspender straps
    c.fill_rect(24, 29+bob, 26, 31+bob, 'denim_sh')
    c.fill_rect(26, 32+bob, 28, 34+bob, 'denim_sh')
    c.fill_rect(29, 35+bob, 34, 37+bob, 'denim_sh') # Intersection X
    c.fill_rect(35, 38+bob, 37, 40+bob, 'denim_sh')
    c.fill_rect(37, 41+bob, 39, 42+bob, 'denim_sh')
    c.fill_rect(37, 29+bob, 39, 31+bob, 'denim_sh')
    c.fill_rect(35, 32+bob, 37, 34+bob, 'denim_sh')
    c.fill_rect(26, 38+bob, 28, 40+bob, 'denim_sh')
    c.fill_rect(24, 41+bob, 26, 42+bob, 'denim_sh')
    # Brass center rivet at X crossing
    c.fill_rect(31, 35+bob, 32, 36+bob, 'brass')

    # Utility Belt & Hip Tool Pouch
    c.fill_rect(22, 42+bob, 41, 43+bob, 'belt_base')
    c.fill_rect(22, 44+bob, 41, 44+bob, 'belt_sh')
    c.fill_rect(40, 41+bob, 43, 46+bob, 'belt_base')
    c.fill_rect(41, 42+bob, 42, 45+bob, 'belt_sh')
    c.set_px(42, 41+bob, 'brass')

    # Arms (Back view)
    lay = 33 + bob + l_arm_swing
    c.fill_rect(16, lay, 20, lay+5, 'shirt_base')
    c.fill_rect(15, lay+1, 16, lay+5, 'shirt_sh')
    c.fill_rect(15, lay+6, 21, lay+7, 'glove_cuff')
    c.fill_rect(14, lay+8, 21, lay+13, 'glove_base')
    c.fill_rect(15, lay+8, 20, lay+10, 'glove_sh')

    ray = 33 + bob + r_arm_swing
    c.fill_rect(43, ray, 47, ray+5, 'shirt_base')
    c.fill_rect(47, ray+1, 48, ray+5, 'shirt_sh')
    c.fill_rect(42, ray+6, 48, ray+7, 'glove_cuff')
    c.fill_rect(42, ray+8, 49, ray+13, 'glove_base')
    c.fill_rect(43, ray+8, 48, ray+10, 'glove_sh')

    # Legs & Back of Boots
    ly_top = 45 + bob
    ly_bot = 53 + l_stride
    c.fill_rect(23, ly_top, 30, ly_bot-1, 'denim_base')
    c.fill_rect(24, ly_top+1, 29, ly_bot-3, 'denim_mid')
    c.fill_rect(23, ly_bot-1, 30, ly_bot, 'denim_hi')
    c.fill_rect(23, ly_bot+1, 30, ly_bot+1, 'denim_out')
    
    by_l = ly_bot + 2
    c.fill_rect(22, by_l, 30, by_l+4, 'boot_base')
    c.fill_rect(24, by_l, 28, by_l+4, 'boot_sh')
    c.fill_rect(21, by_l+5, 31, by_l+6, 'boot_sole')
    c.set_px(21, by_l+4, 'boot_sole')
    c.set_px(31, by_l+4, 'boot_sole')

    ry_top = 45 + bob
    ry_bot = 53 + r_stride
    c.fill_rect(33, ry_top, 40, ry_bot-1, 'denim_base')
    c.fill_rect(34, ry_top+1, 39, ry_bot-3, 'denim_mid')
    c.fill_rect(33, ry_bot-1, 40, ry_bot, 'denim_hi')
    c.fill_rect(33, ry_bot+1, 40, ry_bot+1, 'denim_out')
    
    by_r = ry_bot + 2
    c.fill_rect(33, by_r, 41, by_r+4, 'boot_base')
    c.fill_rect(35, by_r, 39, by_r+4, 'boot_sh')
    c.fill_rect(32, by_r+5, 42, by_r+6, 'boot_sole')
    c.set_px(32, by_r+4, 'boot_sole')
    c.set_px(42, by_r+4, 'boot_sole')

    # Back denim pockets
    c.fill_rect(25, 43+bob, 29, 46+bob, 'denim_sh')
    c.fill_rect(34, 43+bob, 38, 46+bob, 'denim_sh')

    return c.get_image()


def _draw_side_boot(c, x_toe, y_top, is_near=True, plant_flat=True):
    """Draws a grounded or striding left-facing 16-bit work boot with rounded toe, tongue, and rubber tread."""
    body_c = 'boot_base' if is_near else 'boot_far'
    sh_c = 'boot_sh' if is_near else 'boot_far_sh'
    hi_c = 'boot_hi' if is_near else 'boot_base'
    toe_c = 'boot_toe' if is_near else 'boot_base'
    sole_c = 'boot_sole' if is_near else 'boot_far_sh'

    # Main boot shaft & ankle
    c.fill_rect(x_toe + 2, y_top, x_toe + 10, y_top + 4, body_c)
    c.fill_rect(x_toe + 8, y_top, x_toe + 10, y_top + 4, sh_c)
    c.fill_rect(x_toe + 3, y_top, x_toe + 8, y_top + 1, hi_c)

    # Rounded reinforced front toe box
    c.fill_rect(x_toe, y_top + 2, x_toe + 3, y_top + 4, body_c)
    c.fill_rect(x_toe, y_top + 2, x_toe + 2, y_top + 3, toe_c)

    if plant_flat:
        c.fill_rect(x_toe, y_top + 5, x_toe + 11, y_top + 6, sole_c)
        c.set_px(x_toe, y_top + 4, sole_c)
        c.set_px(x_toe + 11, y_top + 4, sole_c)
    else:
        # Push-off boot slightly raised at heel
        c.fill_rect(x_toe, y_top + 5, x_toe + 9, y_top + 6, sole_c)
        c.fill_rect(x_toe + 7, y_top + 4, x_toe + 11, y_top + 5, sole_c)


def build_side_frame(facing_left=True, walk_frame=0):
    c = CanvasBuilder()
    bob = 1 if walk_frame > 0 else 0

    # =========================================================================
    # 1. SOLID 3/4-PROFILE CHIBI HEAD, HAIR & EARS (Zero hollow/transparent gaps)
    # =========================================================================
    # Solid inner head & cranium base strictly within face/jaw bounds (zero leak behind nape)
    c.fill_rect(23, 16+bob, 37, 22+bob, 'skin_base')
    c.fill_rect(23, 23+bob, 34, 24+bob, 'skin_base')
    c.fill_rect(24, 25+bob, 33, 25+bob, 'skin_base')
    c.fill_rect(26, 26+bob, 32, 26+bob, 'skin_sh')
    # Under-visor forehead cast shadow
    c.fill_rect(22, 17+bob, 35, 17+bob, 'skin_sh')

    # Soft, friendly chibi face contour
    c.fill_rect(22, 18+bob, 23, 24+bob, 'skin_base')
    c.set_px(21, 20+bob, 'skin_hi')
    c.set_px(21, 21+bob, 'skin_base')
    c.set_px(21, 22+bob, 'skin_sh')  # Soft curved button nose
    # Warm friendly smile (subtle upward turn) & clean jaw curve
    c.fill_rect(23, 24+bob, 24, 24+bob, 'skin_out')
    c.set_px(25, 23+bob, 'skin_out')
    c.set_px(22, 24+bob, 'skin_base')
    c.fill_rect(23, 25+bob, 26, 25+bob, 'skin_sh')

    # Rounded Hair Crown & Nape (cleanly meets cap at y=13..16 & neck at y=23)
    c.fill_rect(34, 14+bob, 40, 20+bob, 'hair_base')
    c.fill_rect(35, 16+bob, 41, 19+bob, 'hair_base')
    c.fill_rect(37, 17+bob, 39, 18+bob, 'hair_hi')
    c.fill_rect(34, 20+bob, 40, 21+bob, 'hair_dark')
    c.fill_rect(34, 22+bob, 38, 23+bob, 'hair_dark')
    # Neat sideburn lock ahead of ear
    c.fill_rect(30, 17+bob, 32, 20+bob, 'hair_base')
    c.set_px(31, 21+bob, 'hair_dark')

    # Sculpted Ear (cleanly embedded over solid skin/hair)
    c.fill_rect(31, 19+bob, 34, 22+bob, 'skin_sh')
    c.fill_rect(32, 20+bob, 33, 21+bob, 'skin_base')

    # Expressive 3/4 Eye (matches player_down style: brow, iris, sclera, highlight)
    c.fill_rect(24, 18+bob, 27, 18+bob, 'hair_dark')  # Eyebrow
    c.fill_rect(25, 19+bob, 27, 21+bob, 'eye_white')
    c.fill_rect(25, 19+bob, 26, 21+bob, 'eye_iris')
    c.fill_rect(25, 20+bob, 26, 21+bob, 'eye_pupil')
    c.set_px(25, 19+bob, 'eye_hi')

    # Rosy Cheek Blush
    c.fill_rect(27, 22+bob, 29, 23+bob, 'blush')

    # =========================================================================
    # 2. RED PORTER CAP (Sleek dome, rounded back contour, 3/4 front emblem)
    # =========================================================================
    c.fill_rect(27, 6+bob, 36, 6+bob, 'cap_hi')
    c.fill_rect(24, 7+bob, 38, 8+bob, 'cap_mid')
    c.fill_rect(22, 9+bob, 40, 13+bob, 'cap_base')
    # Flush rounded back shadow & subtle rear panel contour (no harsh stripe bar)
    c.fill_rect(39, 9+bob, 41, 13+bob, 'cap_dark')
    c.fill_rect(40, 11+bob, 41, 13+bob, 'cap_dark')
    c.set_px(39, 8+bob, 'cap_dark')
    c.fill_rect(35, 8+bob, 35, 12+bob, 'shirt_base')
    c.fill_rect(30, 5+bob, 33, 5+bob, 'cap_dark')
    c.set_px(31, 5+bob, 'cap_badge')
    c.set_px(32, 5+bob, 'cap_badge')

    # Brass Cap Badge (3/4 front placement matching player_down.png)
    c.fill_rect(23, 11+bob, 26, 13+bob, 'cap_badge')
    c.set_px(23, 11+bob, 'cap_badge_sh')
    c.set_px(26, 13+bob, 'cap_badge_sh')
    c.set_px(24, 12+bob, 'cap_out')

    # Cap Visor extending naturally forward over brow
    c.fill_rect(17, 14+bob, 35, 14+bob, 'cap_hi')
    c.fill_rect(16, 15+bob, 36, 15+bob, 'cap_base')
    c.fill_rect(17, 16+bob, 34, 16+bob, 'cap_visor_bot')

    # =========================================================================
    # 3. STURDY NECK, TORSO, OVERALLS & SOLID PELVIS BRIDGE (No detached waist!)
    # =========================================================================
    # Neck & Collar
    c.fill_rect(27, 27+bob, 34, 27+bob, 'skin_sh')
    c.fill_rect(24, 28+bob, 36, 29+bob, 'shirt_base')
    c.fill_rect(24, 28+bob, 27, 29+bob, 'shirt_hi')

    # Chunky 3/4 Worker Torso (23..37 wide, flush back silhouette)
    c.fill_rect(23, 29+bob, 37, 33+bob, 'shirt_base')
    c.fill_rect(35, 29+bob, 37, 35+bob, 'shirt_sh')
    c.fill_rect(23, 29+bob, 25, 31+bob, 'shirt_hi')

    # Far Arm Swinging Forward (ONLY behind torso in walk_frame == 1 when near leg strides forward!)
    if walk_frame == 1:
        c.fill_rect(21, 31+bob, 24, 36+bob, 'shirt_sh')
        c.fill_rect(19, 34+bob, 23, 38+bob, 'shirt_sh')
        c.fill_rect(18, 38+bob, 22, 39+bob, 'glove_cuff')
        c.fill_rect(17, 39+bob, 22, 44+bob, 'glove_far')
        c.fill_rect(18, 40+bob, 21, 41+bob, 'glove_base')

    # Denim Bib & Overalls (Rich midtone shading + front brass buckle)
    c.fill_rect(23, 30+bob, 37, 41+bob, 'denim_base')
    c.fill_rect(25, 31+bob, 35, 41+bob, 'denim_mid')
    c.fill_rect(35, 32+bob, 37, 41+bob, 'denim_sh')
    # Suspender straps + brass buckle
    c.fill_rect(25, 29+bob, 28, 34+bob, 'denim_sh')
    c.fill_rect(33, 29+bob, 35, 34+bob, 'denim_sh')
    c.fill_rect(25, 34+bob, 28, 35+bob, 'brass')
    c.set_px(25, 35+bob, 'brass_sh')
    # Front-side pocket detail
    c.fill_rect(24, 37+bob, 28, 40+bob, 'denim_sh')
    c.fill_rect(25, 37+bob, 27, 39+bob, 'denim_base')
    c.set_px(24, 37+bob, 'brass')

    # Utility Belt & Flush Hip Bridge
    c.fill_rect(22, 42+bob, 37, 43+bob, 'belt_base')
    c.fill_rect(22, 44+bob, 37, 44+bob, 'belt_sh')
    c.fill_rect(23, 42+bob, 25, 44+bob, 'brass')
    c.set_px(24, 43+bob, 'belt_sh')
    # Compact side tool pouch tucked cleanly at hip
    c.fill_rect(35, 42+bob, 38, 46+bob, 'belt_sh')
    c.fill_rect(36, 43+bob, 37, 45+bob, 'belt_base')
    c.set_px(36, 42+bob, 'brass')

    # Solid pelvis bridge across y = 45..47 so legs NEVER detach from belt during stride!
    c.fill_rect(23, 45+bob, 36, 47+bob, 'denim_sh')
    c.fill_rect(25, 45+bob, 34, 46+bob, 'denim_base')

    # =========================================================================
    # 4. LEGS & BOOTS (Balanced contralateral gait, consistent chunky boots)
    # =========================================================================
    if walk_frame == 0:
        # Far leg slightly stepped back
        c.fill_rect(30, 46, 36, 54, 'denim_far')
        c.fill_rect(31, 47, 35, 52, 'denim_far_sh')
        c.fill_rect(30, 53, 36, 54, 'denim_sh')
        _draw_side_boot(c, 29, 55, is_near=False, plant_flat=True)

        # Near leg grounded cleanly under center
        c.fill_rect(23, 46, 31, 54, 'denim_base')
        c.fill_rect(24, 47, 30, 52, 'denim_mid')
        c.fill_rect(30, 46, 31, 53, 'denim_sh')
        c.fill_rect(23, 53, 31, 54, 'denim_hi')
        _draw_side_boot(c, 21, 55, is_near=True, plant_flat=True)

    elif walk_frame == 1:
        # Far leg pushing back-right
        c.fill_rect(31, 46+bob, 37, 50+bob, 'denim_far')
        c.fill_rect(33, 49+bob, 39, 53+bob, 'denim_far')
        c.fill_rect(33, 52+bob, 39, 53+bob, 'denim_sh')
        _draw_side_boot(c, 32, 54+bob, is_near=False, plant_flat=False)

        # Near leg striding crisply forward-left
        c.fill_rect(23, 46+bob, 31, 49+bob, 'denim_base')
        c.fill_rect(21, 48+bob, 29, 54+bob, 'denim_base')
        c.fill_rect(22, 48+bob, 28, 52+bob, 'denim_mid')
        c.fill_rect(21, 53+bob, 29, 54+bob, 'denim_hi')
        _draw_side_boot(c, 19, 55+bob, is_near=True, plant_flat=True)

    elif walk_frame == 2:
        # Far leg swinging forward-left
        c.fill_rect(23, 46+bob, 30, 49+bob, 'denim_far')
        c.fill_rect(20, 48+bob, 28, 54+bob, 'denim_far')
        c.fill_rect(21, 49+bob, 27, 52+bob, 'denim_sh')
        c.fill_rect(20, 53+bob, 28, 54+bob, 'denim_base')
        _draw_side_boot(c, 18, 55+bob, is_near=False, plant_flat=True)

        # Near leg pushing back-right
        c.fill_rect(29, 46+bob, 35, 50+bob, 'denim_base')
        c.fill_rect(30, 48+bob, 37, 53+bob, 'denim_base')
        c.fill_rect(31, 49+bob, 36, 51+bob, 'denim_mid')
        c.fill_rect(30, 52+bob, 37, 53+bob, 'denim_hi')
        _draw_side_boot(c, 30, 54+bob, is_near=True, plant_flat=False)

    # =========================================================================
    # 5. NEAR ARM & WORK GLOVE (Rounded shoulder socket + natural arm swing)
    # =========================================================================
    if walk_frame == 0:
        # Relaxed vertical side arm (flush back contour + clean front edge)
        c.fill_rect(29, 29, 36, 38, 'shirt_base')
        c.fill_rect(29, 30, 31, 37, 'shirt_hi')
        c.fill_rect(34, 31, 36, 38, 'shirt_sh')
        c.fill_rect(28, 39, 35, 40, 'glove_cuff')
        c.fill_rect(27, 41, 36, 46, 'glove_base')
        c.fill_rect(27, 41, 34, 43, 'glove_hi')
        c.fill_rect(27, 45, 36, 46, 'glove_sh')
        c.fill_rect(25, 42, 27, 44, 'glove_base')  # Forward thumb

    elif walk_frame == 1:
        # Near leg is FORWARD -> Near arm swings naturally BACK (contralateral balance!)
        c.fill_rect(29, 29+bob, 35, 34+bob, 'shirt_base')
        c.fill_rect(29, 30+bob, 31, 33+bob, 'shirt_hi')
        c.fill_rect(31, 33+bob, 36, 38+bob, 'shirt_base')
        c.fill_rect(35, 34+bob, 37, 38+bob, 'shirt_sh')
        c.fill_rect(32, 39+bob, 38, 40+bob, 'glove_cuff')
        c.fill_rect(32, 41+bob, 39, 45+bob, 'glove_base')
        c.fill_rect(33, 41+bob, 38, 43+bob, 'glove_hi')
        c.fill_rect(32, 44+bob, 39, 45+bob, 'glove_sh')
        c.fill_rect(30, 42+bob, 32, 44+bob, 'glove_base')  # Thumb

    elif walk_frame == 2:
        # Far leg is FORWARD -> Near arm swings naturally FORWARD across torso!
        c.fill_rect(28, 29+bob, 34, 34+bob, 'shirt_base')
        c.fill_rect(28, 30+bob, 30, 33+bob, 'shirt_hi')
        c.fill_rect(33, 30+bob, 34, 34+bob, 'shirt_sh')
        c.fill_rect(25, 34+bob, 32, 38+bob, 'shirt_base')
        c.fill_rect(24, 34+bob, 26, 36+bob, 'shirt_hi')
        c.fill_rect(25, 37+bob, 32, 38+bob, 'shirt_sh')  # Underside crease defines bent forearm!
        c.fill_rect(22, 38+bob, 28, 39+bob, 'glove_cuff')
        c.fill_rect(20, 40+bob, 27, 45+bob, 'glove_base')
        c.fill_rect(21, 40+bob, 26, 42+bob, 'glove_hi')
        c.fill_rect(20, 44+bob, 27, 45+bob, 'glove_sh')
        c.fill_rect(18, 41+bob, 20, 43+bob, 'glove_base')  # Thumb pointing forward

    img = c.get_image()
    if not facing_left:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)

    return img


def generate_all_sprites():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(ARTIFACT_DIR, exist_ok=True)
    sprites = {}
    
    # DOWN
    sprites['player_down.png'] = build_down_frame(0)
    sprites['player_down_walk1.png'] = build_down_frame(1)
    sprites['player_down_walk2.png'] = build_down_frame(2)
    
    # UP
    sprites['player_up.png'] = build_up_frame(0)
    sprites['player_up_walk1.png'] = build_up_frame(1)
    sprites['player_up_walk2.png'] = build_up_frame(2)
    
    # LEFT
    sprites['player_left.png'] = build_side_frame(True, 0)
    sprites['player_left_walk1.png'] = build_side_frame(True, 1)
    sprites['player_left_walk2.png'] = build_side_frame(True, 2)
    
    # RIGHT
    sprites['player_right.png'] = build_side_frame(False, 0)
    sprites['player_right_walk1.png'] = build_side_frame(False, 1)
    sprites['player_right_walk2.png'] = build_side_frame(False, 2)
    
    # Save to assets/
    for filename, img in sprites.items():
        out_path = os.path.join(OUTPUT_DIR, filename)
        img.save(out_path)
        print(f"Exported {out_path}")
        
    # Generate combined 4x3 comparison preview sheet
    cell_w, cell_h = 128, 128
    pad = 24
    header_h = 60
    row_label_w = 100
    total_w = row_label_w + 3 * cell_w + 4 * pad
    total_h = header_h + 4 * cell_h + 5 * pad

    sheet = Image.new('RGBA', (total_w, total_h), (24, 28, 38, 255))
    from PIL import ImageDraw, ImageFont
    draw = ImageDraw.Draw(sheet)
    
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)
    except:
        font = ImageFont.load_default()

    col_labels = ['Idle', 'Walk Frame 1', 'Walk Frame 2']
    for col_idx, col_name in enumerate(col_labels):
        x = row_label_w + pad + col_idx * (cell_w + pad)
        draw.text((x + 20, 20), col_name, font=font, fill=(240, 240, 245, 255))

    row_labels = ['DOWN', 'UP', 'LEFT', 'RIGHT']
    row_keys = ['player_down', 'player_up', 'player_left', 'player_right']

    for row_idx, r_name in enumerate(row_labels):
        y = header_h + pad + row_idx * (cell_h + pad)
        draw.text((20, y + 50), r_name, font=font, fill=(200, 210, 230, 255))
        
        rk = row_keys[row_idx]
        files = [f"{rk}.png", f"{rk}_walk1.png", f"{rk}_walk2.png"]
        for col_idx, fname in enumerate(files):
            x = row_label_w + pad + col_idx * (cell_w + pad)
            draw.rectangle([x - 4, y - 4, x + cell_w + 4, y + cell_h + 4], fill=(36, 42, 58, 255), outline=(55, 65, 88, 255))
            sprite = sprites[fname]
            sheet.paste(sprite, (x, y), sprite)

    preview_path = os.path.join(ARTIFACT_DIR, "preview_walk_cycle.png")
    sheet.save(preview_path)
    print(f"Generated comparison sheet: {preview_path}")


if __name__ == "__main__":
    generate_all_sprites()
