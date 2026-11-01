import sys
import time
from collections import deque
import heapq

def solve_push_bfs(grid_lines, max_states=500000):
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

    # Push-based search:
    # State is (canonical_player_tile, sorted_crates)
    # A transition is a legal crate push reachable by the player
    def get_reachable(p, cr_set):
        reach = set([p])
        q = deque([p])
        while q:
            curr = q.popleft()
            for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
                nr, nc = curr[0]+dr, curr[1]+dc
                if (nr, nc) not in walls and (nr, nc) not in cr_set and (nr, nc) not in reach:
                    reach.add((nr, nc))
                    q.append((nr, nc))
        return reach

    def is_deadlock(pos):
        if pos in goals: return False
        r, c = pos
        up = (r-1, c) in walls
        dn = (r+1, c) in walls
        lt = (r, c-1) in walls
        rt = (r, c+1) in walls
        return (up and lt) or (up and rt) or (dn and lt) or (dn and rt)

    reach0 = get_reachable(player, set(crates))
    can0 = min(reach0)
    visited = { (can0, crates): 0 }
    # Queue stores: (pushes, canonical_player, crates, player_pos)
    q = deque([(0, can0, crates, player)])
    states = 0
    t0 = time.time()

    while q:
        states += 1
        if states > max_states:
            return None, f"State limit ({states})"

        pushes, can_p, cr, p_pos = q.popleft()
        if set(cr) == goals:
            return pushes, f"SOLVED in {pushes} pushes ({states} states in {time.time()-t0:.2f}s)"

        reach = get_reachable(p_pos, set(cr))
        cr_set = set(cr)

        for box in cr:
            br, bc = box
            for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
                push_from = (br - dr, bc - dc)
                push_to = (br + dr, bc + dc)
                if push_from in reach:
                    if push_to not in walls and push_to not in cr_set:
                        if is_deadlock(push_to):
                            continue
                        new_cr = list(cr)
                        new_cr.remove(box)
                        new_cr.append(push_to)
                        new_cr = tuple(sorted(new_cr))
                        new_reach = get_reachable(box, set(new_cr))
                        new_can = min(new_reach)
                        if (new_can, new_cr) not in visited:
                            visited[(new_can, new_cr)] = pushes + 1
                            q.append((pushes + 1, new_can, new_cr, box))

    return None, f"Unsolvable ({states} states in {time.time()-t0:.2f}s)"

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

res, msg = solve_push_bfs(ref14)
print("ref14 push BFS:", msg)

ref8_1 = [
    "  ######  ",
    "###    ###",
    "# @$..$  #",
    "#  $..$  #",
    "#  $..$  #",
    "###    ###",
    "  ######  "
]
print("ref8_1:", solve_push_bfs(ref8_1))
