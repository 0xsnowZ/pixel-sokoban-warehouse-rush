import sys
import time
from collections import deque

def solve_grid(grid_lines, max_states=300000):
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

# Let's test Ref 7
# Looking at 7.jpeg:
# Top has a 2-wide niche with 2 goals at (1,3), (1,4)
# Below that, at (2,4) is 1 goal.
# To the right at (3,5) is 1 goal.
# Crates are at (3,4), (4,3), (5,4), (5,5)
# Player is at (6,3)
ref7_cand1 = [
    "  ####  ",
    "  #..#  ",
    "### .#  ",
    "#  $.#  ",
    "# $  ###",
    "#  $$  #",
    "#  @   #",
    "########"
]

print("Testing Ref 7 cand 1:")
res, msg = solve_grid(ref7_cand1)
print(msg)

# Ref 14:
# In 14.jpeg:
# Left side has 2x3 bay: 5 goals!
# Crates are at (3,3), (4,4), (5,4), (3,6), (4,6)
# Goals at (4,2), (5,2), (6,2), (4,3), (6,3) with player at (5,3)
# But wait! Player cannot start on goal! In 14.jpeg, is player at (5,3)?
# If (5,3) is player, and (4,2), (5,2), (6,2), (4,3), (6,3) are goals:
# That's 5 goals and 5 crates! Player is NOT on goal!
ref14_cand1 = [
    "  ##### ",
    "###   # ",
    "#  ## # ",
    "#  $  # ",
    "##..$ $#",
    "# .@$ $#",
    "##..   #",
    " #######"
]
print("\nTesting Ref 14 cand 1:")
res, msg = solve_grid(ref14_cand1)
print(msg)
