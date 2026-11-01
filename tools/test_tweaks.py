import sys
from tools.build_hard_ref_campaign import solve_grid

TWEAKS = {
    # TJunction Var A: Move right crate closer
    "TJunction_A": [
        "  ###### ",
        "  # .. # ",
        "  # .. # ",
        "### $$ ##",
        "#  $  $ #",
        "#   @   #",
        "#########"
    ],
    # TwinSiding Var A: Shift wall
    "TwinSiding_A": [
        "########",
        "# ..   #",
        "# ..   #",
        "###$$# #",
        "#  $   #",
        "# @$   #",
        "########"
    ],
    # TwinSiding Var B: Goals at bottom
    "TwinSiding_B": [
        "########",
        "#  @   #",
        "# $$$$ #",
        "# # #  #",
        "# ..#  #",
        "# ..#  #",
        "########"
    ],
    # Central Room with 4 Turnouts (8x7)
    "CenterTurnout_4cr": [
        "########",
        "#.    .#",
        "# $  $ #",
        "#  @@  #",
        "# $  $ #",
        "#.    .#",
        "########"
    ]
}

for name, grid in TWEAKS.items():
    res, msg = solve_grid(grid, max_states=80000)
    w = max(len(l) for l in grid)
    h = len(grid)
    print(f"{name:18s} ({w}x{h}): {msg}")

