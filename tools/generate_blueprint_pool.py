import sys
from collections import deque
from tools.build_hard_ref_campaign import solve_grid

def flip_h(lines):
    return [l[::-1] for l in lines]

def flip_v(lines):
    return lines[::-1]

def transpose(lines):
    max_len = max(len(l) for l in lines)
    padded = [l.ljust(max_len) for l in lines]
    return ["".join(padded[r][c] for r in range(len(padded))) for c in range(max_len)]

def rotate_90(lines):
    return flip_h(transpose(lines))

def rotate_180(lines):
    return flip_h(flip_v(lines))

def rotate_270(lines):
    return flip_v(transpose(lines))

# Core blueprints (proven solvable, non-square, >=4 crates, 0 dummy crates)
CORE_BLUEPRINTS = [
    # 1. Twin Chute (56m, 19p)
    ("TwinChute", [
        "###### ",
        "# .  ##",
        "# $ $ #",
        "# # # #",
        "# $ $ #",
        "##  . #",
        " #@.. #",
        " ######"
    ]),
    # 2. Fortress Castle (40m, 10p)
    ("Fortress", [
        "#######",
        "#  .  #",
        "# $#$ #",
        "#.@   #",
        "# $#$ #",
        "#  .  #",
        "#  .  #",
        "#######"
    ]),
    # 3. Ref 5 2x3 Bay (38m, 14p, 5 crates)
    ("Ref05_Bay2x3", [
        "  ######",
        "  #    #",
        "###$$$ #",
        "#@ $...#",
        "#  $..##",
        "####  # ",
        "   #### "
    ]),
    # 4. Bay2x2 Var 2 (30m, 10p)
    ("Bay2x2_V2", [
        "########",
        "#     ##",
        "# $$$$ #",
        "# ..   #",
        "# ..@###",
        "######  "
    ]),
    # 5. Ref 9 2x2 Bay (29m, 9p)
    ("Ref09_Bay2x2", [
        " ###### ",
        " #    # ",
        "##$$$ ##",
        "#  ..$ #",
        "#@ ..  #",
        "########"
    ]),
    # 6. Ref 7 Irregular (28m, 13p)
    ("Ref07_Irregular", [
        "  ####  ",
        "  #..#  ",
        "### .#  ",
        "#  $.#  ",
        "# $  ###",
        "#  $$  #",
        "#  @   #",
        "########"
    ]),
    # 7. Bay2x3 with 4 crates (28m, 8p)
    ("Bay2x3_4cr", [
        "  ######",
        "  #    #",
        "###$$$ #",
        "#@  ...#",
        "#   $ .#",
        "####  # ",
        "   #### "
    ]),
    # 8. Bay2x2 Var 1 (27m, 7p)
    ("Bay2x2_V1", [
        "  ###### ",
        "  #    # ",
        "###$$$ # ",
        "#@ ..  ##",
        "#  ..$  #",
        "#########"
    ]),
    # 9. Pinwheel V1 (25m, 10p)
    ("Pinwheel_V1", [
        "  ####  ",
        "  #..#  ",
        "###  ###",
        "# $ $  #",
        "#  @   #",
        "# $ $  #",
        "###  ###",
        "  #..#  ",
        "  ####  "
    ]),
    # 10. TwinBay Deep 4 (22m, 11p)
    ("TwinBay_Deep4", [
        "#########",
        "##.   .##",
        "##. $ .##",
        "#  $$$  #",
        "#   @   #",
        "#########"
    ]),
    # 11. Ref 1 Pinwheel (12m, 7p)
    ("Ref01_Pinwheel", [
        "  ###   ",
        "  #.#   ",
        "  # ####",
        "###$ $ .#",
        "#. $ @##",
        "####$#  ",
        "   #.#  ",
        "   ###  "
    ]),
    # 12. Staggered S-Bay 4-crate
    ("Staggered_SBay", [
        "########",
        "##    ##",
        "#  $$$ #",
        "# ..@$ #",
        "# .. ###",
        "######  "
    ]),
    # 13. Double Loop 4-crate
    ("DoubleLoop", [
        "#########",
        "#   #   #",
        "# $ # $ #",
        "# # # # #",
        "# $ # $ #",
        "# ..@.. #",
        "#########"
    ]),
    # 14. Turnout Corridor 4-crate
    ("TurnoutCorridor", [
        " ###### ",
        " # .  # ",
        "## $# ##",
        "#  $   #",
        "#@$$ . #",
        "##.#..##",
        " #######"
    ]),
    # 15. The Courtyard (4 crates)
    ("TheCourtyard", [
        "########",
        "#  ..  #",
        "#  ..  #",
        "##$$$$##",
        "#  @   #",
        "#      #",
        "########"
    ])
]

pool = []
for name, grid in CORE_BLUEPRINTS:
    res, msg = solve_grid(grid, max_states=80000)
    w = max(len(l) for l in grid)
    h = len(grid)
    is_nonsquare = (w != h)
    print(f"{name:16s} ({w}x{h}, nonsquare={is_nonsquare}): {msg}")
    if res and is_nonsquare:
        pool.append((name, res, grid))

print(f"\nTotal verified non-square blueprints: {len(pool)}")
