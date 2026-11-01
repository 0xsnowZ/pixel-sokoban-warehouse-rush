import sys
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
                'path': path
            }, f"SOLVED in {moves}m, {pushes}p ({states} states)"

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

# Let's test candidate variants of Ref 14
# Notice 4 goals on left: (4,1), (4,2), (6,1), (6,2), player @ at (5,2), and (5,1) is goal! That's 5 goals!
# But wait, does (5,1) have a goal? In 14.jpeg, col 1 has 3 goals: (4,1), (5,1), (6,1)!
# And col 2 has 2 goals: (4,2), (6,2)!
# That is 5 goals! And player is at (5,2) between (4,2) and (6,2)!
# Crates:
# Crate 1: (3,3)
# Crate 2: (4,4)
# Crate 3: (5,3)
# Crate 4: (3,6)
# Crate 5: (4,6)
# Let's test this:
ref14 = [
    "#####    ",
    "#   #####",
    "# # #   #",
    "#  $  $ #",
    "##.. $ $#",
    "#. @$   #",
    "##..  ###",
    " ######  "
]
res, msg = solve_grid(ref14)
print("ref14:", msg)
