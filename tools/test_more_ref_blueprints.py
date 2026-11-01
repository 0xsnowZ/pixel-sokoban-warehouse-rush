import sys
from tools.build_hard_ref_campaign import solve_grid

NEW_BLUEPRINTS = {
    # 1. 5-crate Twin Bay (3 goals left, 2 goals right)
    "TwinBay_5cr": [
        "#########",
        "##.. ..##",
        "##. $  ##",
        "#  $$$  #",
        "# @ $   #",
        "#########"
    ],
    # 2. 6-crate Twin Bay (3 goals left, 3 goals right, like Ref 8)
    "TwinBay_6cr": [
        "  ######  ",
        "###    ###",
        "# @$..$  #",
        "#  $..$  #",
        "#  $..$  #",
        "###    ###",
        "  ######  "
    ],
    # 3. Chute Turnout 4-crate (Variant of Ref 4 with 4 crates)
    "Chute4_Ref04": [
        "  ##### ",
        "  #   # ",
        "### $ ##",
        "#  $  # ",
        "#@$$..# ",
        "### ..# ",
        "  ##### "
    ],
    # 4. Extended Bay2x2 with 5 crates (2x2 bay + 1 isolated goal)
    "Bay2x2_Plus1_5cr": [
        " ###### ",
        " #    # ",
        "##$$$ ##",
        "#. ..$$#",
        "#@ ..  #",
        "########"
    ],
    # 5. The Staggered Maze (4 crates, 4 goals in corners)
    "StaggeredMaze_4cr": [
        "########",
        "#. $  .#",
        "#  #$  #",
        "# $#   #",
        "#@ $  .#",
        "#   # .#",
        "########"
    ],
    # 6. S-Bend with 4 crates in a line
    "SBend_4cr": [
        "#########",
        "#@    # #",
        "# $$$$# #",
        "# ..#   #",
        "# ..#   #",
        "#########"
    ],
    # 7. Asymmetric Pinwheel 4-crate
    "AsymPinwheel_4cr": [
        "   ###  ",
        "   #.#  ",
        "#### ###",
        "#  $ $ #",
        "#..@$  #",
        "####$###",
        "   #.#  ",
        "   ###  "
    ],
    # 8. Twin Corridor Shuffler (4 crates)
    "CorridorShuffler": [
        "#######",
        "# .#  #",
        "# $ $ #",
        "# $#$ #",
        "# .#  #",
        "# .#  #",
        "#@.#  #",
        "#######"
    ],
    # 9. Center Block 4-crate
    "CenterBlock_4cr": [
        "########",
        "#  ..  #",
        "#  ..  #",
        "# $$$$ #",
        "#  @   #",
        "#  ##  #",
        "########"
    ]
}

for name, grid in NEW_BLUEPRINTS.items():
    res, msg = solve_grid(grid, max_states=80000)
    w = max(len(l) for l in grid)
    h = len(grid)
    print(f"{name:18s} ({w}x{h}): {msg}")

