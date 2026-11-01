import sys
import time
from tools.test_ref_architectures import solve_grid

VARIANTS = {
    # Variant A1: 2x2 Bay with top loop and right parking pocket (4 crates)
    "Bay2x2_Var1": [
        "  ###### ",
        "  #    # ",
        "###$$$ # ",
        "#@ ..  ##",
        "#  ..$  #",
        "#########"
    ],
    # Variant A2: 2x2 Bay with serpentine loop (4 crates)
    "Bay2x2_Var2": [
        "########",
        "#     ##",
        "# $$$$ #",
        "# ..   #",
        "# ..@###",
        "######  "
    ],
    # Variant A3: 2x2 Bay with 4 crates in L-cluster
    "Bay2x2_Var3": [
        " ###### ",
        " #    # ",
        "## $$ ##",
        "#  $$  #",
        "#@ ..  #",
        "#  ..  #",
        "########"
    ],
    # Variant B1: 2x3 Bay with 5 crates (shifted entrance)
    "Bay2x3_Var1": [
        "  #######",
        "  #     #",
        "### $$$ #",
        "#@  $...#",
        "#   $..##",
        "#####  # ",
        "    #### "
    ],
    # Variant B2: 2x3 Bay with 5 crates (vertical bar)
    "Bay2x3_Var2": [
        " ###### ",
        " #    # ",
        "##$$$ ##",
        "# $..  #",
        "#@ ...##",
        "####  # ",
        "   #### "
    ],
    # Variant C1: Chute with 2 Turnouts (4 crates, 4 goals in a row)
    "Chute_Turnout1": [
        "  ##### ",
        "###   # ",
        "# $ $ # ",
        "# # # ##",
        "#@$ $ .#",
        "### # .#",
        "  #   .#",
        "  #   .#",
        "  ######"
    ],
    # Variant D1: Twin 2x1 Bays (4 crates split between 2 bays)
    "TwinBay_4cr": [
        "########",
        "#.    .#",
        "#. $$ .#",
        "#  $$  #",
        "## @ ###",
        " #######"
    ],
    # Variant D2: Twin 2x2 Bays (4 crates, deep split)
    "TwinBay_Deep4": [
        "#########",
        "##.   .##",
        "##. $ .##",
        "#  $$$  #",
        "#   @   #",
        "#########"
    ],
    # Variant E1: Pinwheel 4-crate variant
    "Pinwheel_Var1": [
        "  ####  ",
        "  #..#  ",
        "###  ###",
        "# $ $  #",
        "#  @   #",
        "# $ $  #",
        "###  ###",
        "  #..#  ",
        "  ####  "
    ]
}

for name, grid in VARIANTS.items():
    res, msg = solve_grid(grid, max_states=80000)
    print(f"{name:16s}: {msg}")
