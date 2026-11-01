import sys
import time
from collections import deque

def solve_grid(grid_lines, max_states=100000):
    walls = set()
    goals = set()
    crates = []
    player = None
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
    if len(crates) != len(goals) or len(crates) == 0:
        return None, f"Mismatch: {len(crates)} crates vs {len(goals)} goals"

    visited = set([(player, crates)])
    q = deque([(player, crates, 0, 0, '')])
    states = 0
    t0 = time.time()

    while q:
        states += 1
        if states > max_states:
            return None, f"State limit ({states})"

        p, cr, moves, pushes, path = q.popleft()
        if set(cr) == goals:
            return {
                'moves': moves,
                'pushes': pushes,
                'states': states,
                'time_s': time.time() - t0,
                'path': path
            }, f"SOLVED in {moves}m, {pushes}p ({states} states in {time.time()-t0:.2f}s)"

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

    return None, f"Unsolvable ({states} states)"

REF_LEVELS = {}

# 1. Pinwheel Cross (from 1.jpeg)
REF_LEVELS[1] = [
    "  ###   ",
    "  #.#   ",
    "  # ####",
    "###$ $ .#",
    "#. $ @##",
    "####$#  ",
    "   #.#  ",
    "   ###  "
]

# 5. Compact 2x3 Bay with 5 Crates (from 5.jpeg)
REF_LEVELS[5] = [
    "  ######",
    "  #    #",
    "###$$$ #",
    "#@ $...#",
    "#  $..##",
    "####  # ",
    "   #### "
]

# 6. Interlocking Diamond Cross (from 6.jpeg)
# 4 crates, 4 goals in plus-shaped chamber
REF_LEVELS[6] = [
    "  #####  ",
    "  #   #  ",
    "###$#$###",
    "# .@. . #",
    "#  $.$  #",
    "### # ###",
    "  #   #  ",
    "  #####  "
]

# 8. Central Goal Bay with Twin Crate Columns (from 8.jpeg)
# 6 crates, 6 goals (2x3 central bay, 3 crates left, 3 right)
REF_LEVELS[8] = [
    "  ######  ",
    "###    ###",
    "# @$..$  #",
    "#  $..$  #",
    "#  $..$  #",
    "###    ###",
    "  ######  "
]

# 9. 2x2 Bay with Horizontal Crate Bar (from 9.jpeg)
# 4 crates, 4 goals
REF_LEVELS[9] = [
    " ###### ",
    " #    # ",
    "##$$$ ##",
    "#  ..$ #",
    "#@ ..  #",
    "########"
]

# 10. Twin 2x2 Bays (8 crates, 8 goals) (from 10.jpeg)
REF_LEVELS[10] = [
    "#########",
    "#..# #..#",
    "#..$ $..#",
    "# $$$$  #",
    "#  $@$  #",
    "#########"
]

if __name__ == '__main__':
    for num, lines in REF_LEVELS.items():
        res, msg = solve_grid(lines)
        print(f"Ref Level {num:2d}: {msg}")

