import sys
from collections import deque
from tools.build_hard_ref_campaign import solve_grid

def get_player_start_variants(grid_lines):
    # Find all empty floor spaces reachable by player without moving crates
    walls = set()
    crates = set()
    player = None
    for r, l in enumerate(grid_lines):
        for c, ch in enumerate(l):
            if ch == '#': walls.add((r, c))
            elif ch in '$*': crates.add((r, c))
            elif ch in '@+': player = (r, c)
            
    # BFS reachability
    reach = set([player])
    q = deque([player])
    while q:
        curr = q.popleft()
        for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
            nr, nc = curr[0]+dr, curr[1]+dc
            if (nr, nc) not in walls and (nr, nc) not in crates and (nr, nc) not in reach:
                reach.add((nr, nc))
                q.append((nr, nc))
                
    # Return variants
    variants = []
    for pr, pc in sorted(reach):
        if (pr, pc) == player: continue
        # Don't place on goal if possible
        if grid_lines[pr][pc] == '.': continue
        
        new_grid = []
        for r, line in enumerate(grid_lines):
            row_chars = list(line)
            if r == player[0] and player[1] < len(row_chars):
                row_chars[player[1]] = ' '
            if r == pr and pc < len(row_chars):
                row_chars[pc] = '@'
            new_grid.append("".join(row_chars))
        variants.append(new_grid)
    return variants

# Let's test on Bay2x2_V2
bay2 = [
    "########",
    "#     ##",
    "# $$$$ #",
    "# ..   #",
    "# ..@###",
    "######  "
]
vars_bay2 = get_player_start_variants(bay2)
print(f"Bay2x2_V2 has {len(vars_bay2)} player start variants.")
for i, v in enumerate(vars_bay2):
    res, msg = solve_grid(v)
    print(f"  Var {i+1}: {msg}")

# Test on TwinChute
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
vars_chute = get_player_start_variants(chute)
print(f"TwinChute has {len(vars_chute)} player start variants.")
for i, v in enumerate(vars_chute):
    res, msg = solve_grid(v)
    print(f"  Var {i+1}: {msg}")

