import sys
from collections import deque
import time

def solve(grid_lines, max_states=100000):
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

    def get_player_component(p, cr_tuple):
        q = deque([p])
        visited_p = {p}
        cr_set = set(cr_tuple)
        while q:
            cur = q.popleft()
            for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nb = (cur[0] + dr, cur[1] + dc)
                if nb not in walls and nb not in cr_set and nb not in visited_p:
                    visited_p.add(nb)
                    q.append(nb)
        return min(visited_p)

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

if __name__ == '__main__':
    # Test Level 1
    l1 = [
        "  ###   ",
        "  #.#   ",
        "  # ####",
        "###$ $ .#",
        "#. $ @##",
        "####$#  ",
        "   #.#  ",
        "   ###  "
    ]
    res, msg = solve(l1)
    print("Level 1:", msg)
