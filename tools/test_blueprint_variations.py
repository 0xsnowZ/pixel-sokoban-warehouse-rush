import sys
from tools.build_hard_ref_campaign import solve_grid

def flip_h(lines):
    return [l[::-1] for l in lines]

def flip_v(lines):
    return lines[::-1]

def make_nonsquare(lines):
    w = max(len(l) for l in lines)
    h = len(lines)
    if w == h:
        # Add a wall border on top or side to make non-square
        # If we add a wall row on top:
        return ["#" * w] + lines
    return lines

# Let's test generating variants of Ref05, Ref07, Ref09, Bay2x2_V2, TwinChute, TwinBay_Deep4
tests = []

# Base 1: Ref09 (8x6)
ref09 = [
    " ###### ",
    " #    # ",
    "##$$$ ##",
    "#  ..$ #",
    "#@ ..  #",
    "########"
]
tests.append(("Ref09_orig", ref09))
tests.append(("Ref09_flip_h", flip_h(ref09)))
tests.append(("Ref09_flip_v", flip_v(ref09)))

# Base 2: Ref05 (8x7)
ref05 = [
    "  ######",
    "  #    #",
    "###$$$ #",
    "#@ $...#",
    "#  $..##",
    "####  # ",
    "   #### "
]
tests.append(("Ref05_orig", ref05))
tests.append(("Ref05_flip_h", flip_h(ref05)))

# Base 3: Bay2x2_V2 (8x6)
bay2 = [
    "########",
    "#     ##",
    "# $$$$ #",
    "# ..   #",
    "# ..@###",
    "######  "
]
tests.append(("Bay2x2_V2_orig", bay2))
tests.append(("Bay2x2_V2_flip_h", flip_h(bay2)))

# Base 4: TwinChute (7x8)
chute = [
    "###### ",
    "# .  ##",
    "# $ $ #",
    "# # # #",
    "# $ $ #",
    "##  . #",
    " #@.. #",
    " ######"
]
tests.append(("TwinChute_orig", chute))
tests.append(("TwinChute_flip_h", flip_h(chute)))

# Base 5: Ref07 (8x8 -> 8x9 by adding wall row)
ref07_8x9 = [
    "  ####  ",
    "  #..#  ",
    "### .#  ",
    "#  $.#  ",
    "# $  ###",
    "#  $$  #",
    "#  @   #",
    "########",
    " #######"
]
tests.append(("Ref07_8x9", ref07_8x9))

for name, grid in tests:
    res, msg = solve_grid(grid)
    w = max(len(l) for l in grid)
    h = len(grid)
    print(f"{name:16s} ({w}x{h}): {msg}")

