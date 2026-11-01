import sys
from tools.build_hard_ref_campaign import solve_grid

ADDITIONAL_BLUEPRINTS = {
    # 1. Central Pillar (4 crates, 4 goals in corners)
    "CentralPillar_4cr": [
        "########",
        "#.    .#",
        "#  $$  #",
        "#  ##  #",
        "#  $$  #",
        "#. @  .#",
        "########"
    ],
    # 2. Central Pillar Var 2 (corridor ring around 2x2 pillar)
    "CentralPillar_V2": [
        "#########",
        "#.  #  .#",
        "# $ # $ #",
        "#   #   #",
        "## ### ##",
        "# $ # $ #",
        "#.  @  .#",
        "#########"
    ],
    # 3. T-Junction (4 crates)
    "TJunction_4cr": [
        "  ###### ",
        "  # .. # ",
        "  # .. # ",
        "### $$ ##",
        "# $    $#",
        "#   @   #",
        "#########"
    ],
    # 4. Asymmetric Bay 4-crate (5x8)
    "AsymBay_4cr": [
        "#####   ",
        "#   ### ",
        "# $   # ",
        "# #$$ # ",
        "# # . ##",
        "# @... #",
        "########"
    ],
    # 5. Twin Siding (4 crates in 2 sidings, 4 goals in bay)
    "TwinSiding_4cr": [
        "########",
        "# ..   #",
        "# .. # #",
        "###$$# #",
        "#  $   #",
        "# @$   #",
        "########"
    ],
    # 6. The ZigZag (4 crates)
    "ZigZag_4cr": [
        "####### ",
        "# .  .##",
        "# $ $  #",
        "###  # #",
        "#  $ $ #",
        "##.  . #",
        " #@ ####",
        " ####   "
    ],
    # 7. Snail Spiral (4 crates, non-square 8x7)
    "Snail_4cr": [
        "########",
        "#@    .#",
        "# ###$##",
        "# #.$  #",
        "# #.$  #",
        "#   $ .#",
        "########"
    ],
    # 8. Ref 14 Inspired 2x3 Bay (5 crates, 5 goals)
    "Ref14_Inspired": [
        "  ###### ",
        "  #    # ",
        "###$$$ # ",
        "#  $.. ##",
        "#@ $... #",
        "#####   #",
        "    #####"
    ],
    # 9. Narrow Chute Sorter (4 crates)
    "NarrowChute_4cr": [
        "######  ",
        "#    ###",
        "# $$   #",
        "# #$$# #",
        "# #..# #",
        "# @..# #",
        "########"
    ],
    # 10. Quad Turnout (4 crates)
    "QuadTurnout_4cr": [
        "#########",
        "##  .  ##",
        "#  $#$  #",
        "# .#@#. #",
        "#  $#$  #",
        "##  .  ##",
        "#########"
    ],
    # 11. 3x1 Bay with side loop (4 crates)
    "Bay3x1_Loop": [
        "########",
        "#     .#",
        "# $$$$ #",
        "# ...  #",
        "#   @###",
        "#####   "
    ],
    # 12. Twin Turnout Hub (4 crates)
    "TwinTurnoutHub": [
        "####### ",
        "# . . ##",
        "# $ $  #",
        "## @#$ #",
        "#  $ . #",
        "##.  ###",
        " #####  "
    ]
}

print(f"Testing {len(ADDITIONAL_BLUEPRINTS)} candidate designs...")
for name, grid in ADDITIONAL_BLUEPRINTS.items():
    res, msg = solve_grid(grid, max_states=80000)
    w = max(len(l) for l in grid)
    h = len(grid)
    is_ns = (w != h)
    print(f"{name:18s} ({w}x{h}, ns={is_ns}): {msg}")

