import sys
import time
from collections import deque

def solve_grid(grid_lines, max_states=80000):
    walls = set()
    goals = set()
    crates = []
    player = None
    h = len(grid_lines)
    w = max(len(l) for l in grid_lines)
    
    for r, line in enumerate(grid_lines):
        for c, ch in enumerate(line):
            if ch == '#': walls.add((r, c))
            elif ch == '.': goals.add((r, c))
            elif ch == '$': crates.append((r, c))
            elif ch == '@': player = (r, c)
            elif ch == '*': crates.append((r, c)); goals.add((r, c))
            elif ch == '+': player = (r, c); goals.add((r, c))

    crates = tuple(sorted(crates))
    goals = frozenset(goals)
    if not player:
        return None, "No player"
    if len(crates) != len(goals) or len(crates) < 4:
        return None, f"Mismatch/Too few: {len(crates)} crates vs {len(goals)} goals"

    visited = set([(player, crates)])
    q = deque([(player, crates, 0, 0, '')])
    states = 0
    t0 = time.time()

    while q:
        states += 1
        if states > max_states:
            return None, f"TIMEOUT (> {max_states} states)"

        p, cr, moves, pushes, path = q.popleft()
        if set(cr) == goals:
            return {
                'moves': moves,
                'pushes': pushes,
                'states': states,
                'time_s': time.time() - t0,
                'path': path,
                'w': w,
                'h': h,
                'crates': len(crates)
            }, f"SOLVED: {moves}m, {pushes}p ({states} states in {time.time()-t0:.2f}s)"

        pr, pc = p
        cr_set = set(cr)
        for dr, dc, name in [(-1, 0, 'U'), (1, 0, 'D'), (0, -1, 'L'), (0, 1, 'R')]:
            nr, nc = pr + dr, pc + dc
            if (nr, nc) in walls: continue
            if (nr, nc) in cr_set:
                nnr, nnc = nr + dr, nc + dc
                if (nnr, nnc) in walls or (nnr, nnc) in cr_set: continue
                # Corner deadlock check
                if (nnr, nnc) not in goals:
                    up = (nnr - 1, nnc) in walls
                    dn = (nnr + 1, nnc) in walls
                    lt = (nnr, nnc - 1) in walls
                    rt = (nnr, nnc + 1) in walls
                    if (up and lt) or (up and rt) or (dn and lt) or (dn and rt):
                        continue
                # 2x2 deadlock check
                is_dead_2x2 = False
                for r0, c0 in [(nnr-1, nnc-1), (nnr-1, nnc), (nnr, nnc-1), (nnr, nnc)]:
                    cells = [(r0, c0), (r0+1, c0), (r0, c0+1), (r0+1, c0+1)]
                    all_blocked = True
                    has_nongoal = False
                    for cr_pos in cells:
                        if cr_pos in walls:
                            continue
                        is_cr = (cr_pos == (nnr, nnc)) or (cr_pos in cr_set and cr_pos != (nr, nc))
                        if is_cr:
                            if cr_pos not in goals:
                                has_nongoal = True
                        else:
                            all_blocked = False
                            break
                    if all_blocked and has_nongoal:
                        is_dead_2x2 = True
                        break
                if is_dead_2x2:
                    continue

                new_cr = list(cr)
                new_cr.remove((nr, nc))
                new_cr.append((nnr, nnc))
                new_cr = tuple(sorted(new_cr))
                if ((nr, nc), new_cr) not in visited:
                    visited.add(((nr, nc), new_cr))
                    q.append(((nr, nc), new_cr, moves + 1, pushes + 1, path + name))
            else:
                if ((nr, nc), cr) not in visited:
                    visited.add(((nr, nc), cr))
                    q.append(((nr, nc), cr, moves + 1, pushes, path + name.lower()))

    return None, f"UNSOLVABLE ({states} states in {time.time()-t0:.2f}s)"

LIBRARY = {
    # 1. Preserved Level 1
    "Lvl01_Pinwheel": [
        " ##### ",
        "##. .##",
        "# $ $ #",
        "# @   #",
        "# $ $ #",
        "##. .##",
        " ##### "
    ],
    # 2. Ref Level 7 Authentic
    "Ref07_Irregular": [
        "  ####  ",
        "  #..#  ",
        "### .#  ",
        "#  $.#  ",
        "# $  ###",
        "#  $$  #",
        "#  @   #",
        "########"
    ],
    # 3. Ref Level 9 Authentic
    "Ref09_Bay2x2": [
        " ###### ",
        " #    # ",
        "##$$$ ##",
        "#  ..$ #",
        "#@ ..  #",
        "########"
    ],
    # 4. Ref Level 5 Authentic
    "Ref05_Bay2x3": [
        "  ######",
        "  #    #",
        "###$$$ #",
        "#@ $...#",
        "#  $..##",
        "####  # ",
        "   #### "
    ],
    # 5. Bay2x2 Variant 1
    "Bay2x2_V1": [
        "  ###### ",
        "  #    # ",
        "###$$$ # ",
        "#@ ..  ##",
        "#  ..$  #",
        "#########"
    ],
    # 6. Bay2x2 Variant 2
    "Bay2x2_V2": [
        "########",
        "#     ##",
        "# $$$$ #",
        "# ..   #",
        "# ..@###",
        "######  "
    ],
    # 7. TwinBay Deep 4
    "TwinBay_Deep4": [
        "#########",
        "##.   .##",
        "##. $ .##",
        "#  $$$  #",
        "#   @   #",
        "#########"
    ],
    # 8. Pinwheel Variant 1
    "Pinwheel_V1": [
        "  ####  ",
        "  #..#  ",
        "###  ###",
        "# $ $  #",
        "#  @   #",
        "# $ $  #",
        "###  ###",
        "  #..#  ",
        "  ####  "
    ],
    # 9. Fortress / Castle 4-crate
    "Fortress_4cr": [
        "#######",
        "#  .  #",
        "# $#$ #",
        "#.@ @.#",
        "# $#$ #",
        "#  .  #",
        "#######"
    ],
    # 10. Twin Chutes with Crossover (4 crates)
    "TwinChute_4cr": [
        "###### ",
        "# .  ##",
        "# $ $ #",
        "# # # #",
        "# $ $ #",
        "##  . #",
        " #@.. #",
        " ######"
    ],
    # 11. Spiral 4-crate
    "Spiral_4cr": [
        "#######",
        "#@    #",
        "# ### #",
        "# #.$ #",
        "# #.$ #",
        "# #.$ #",
        "# #.$ #",
        "#     #",
        "#######"
    ],
    # 12. Bay2x3 Variant with 4 crates
    "Bay2x3_4cr": [
        "  ######",
        "  #    #",
        "###$$$ #",
        "#@  ...#",
        "#   $ .#",
        "####  # ",
        "   #### "
    ],
    # 13. S-Corridor 4-crate
    "SCorridor_4cr": [
        "########",
        "#@$ .  #",
        "# # ## #",
        "# $ .# #",
        "# #$ . #",
        "#  $ . #",
        "########"
    ],
    # 14. Diamond Hub (4 crates)
    "Diamond_Hub": [
        "   ###   ",
        " ###.### ",
        "## $ $ ##",
        "#.  @  .#",
        "## $ $ ##",
        " ###.### ",
        "   ###   "
    ],
    # 15. The Vault 5-crate (5 crates, 5 goals)
    "TheVault_5cr": [
        "  ######",
        "###    #",
        "# . $$$#",
        "#@. $..#",
        "# . $..#",
        "###    #",
        "  ######"
    ],
    # 16. Double Siding (4 crates)
    "DoubleSiding_4cr": [
        "########",
        "#@  #  #",
        "# $ #$ #",
        "# $ #$ #",
        "# ..#..#",
        "#      #",
        "########"
    ]
}

print(f"Testing {len(LIBRARY)} candidate archetype designs...")
passed = []
for name, grid in LIBRARY.items():
    res, msg = solve_grid(grid, max_states=80000)
    print(f"{name:18s}: {msg}")
    if res:
        passed.append((name, res, grid))

print(f"\n{len(passed)} / {len(LIBRARY)} designs verified solvable!")
